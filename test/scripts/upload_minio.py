#!/usr/bin/env python3
"""Upload NetCDF Test Fixtures to MinIO for Integration Testing.

This module uploads the test fixtures created by create_fixtures.py to a MinIO
S3-compatible object storage instance for integration testing of the
fortran-s3-netcdf library's caching functionality.

The script connects to MinIO using environment variables and uploads all NetCDF
files from test/fixtures/ to the configured bucket.

Environment Variables
---------------------
S3_ENDPOINT_URL : str
    MinIO endpoint URL (e.g., http://localhost:9000)
S3_ACCESS_KEY : str
    MinIO access key (e.g., minioadmin)
S3_SECRET_KEY : str
    MinIO secret key (e.g., minioadmin123)

Examples
--------
Upload all fixtures to MinIO::

    $ export S3_ENDPOINT_URL=http://localhost:9000
    $ export S3_ACCESS_KEY=minioadmin
    $ export S3_SECRET_KEY=minioadmin123
    $ python test/scripts/upload_minio.py

This uploads all NetCDF files to s3://test-bucket/ with public-read ACL.

Notes
-----
This script is designed to run in CI environments where MinIO is available
as a Docker container. It requires boto3 to be installed.

Author: Paul Gierz <paul.gierz@awi.de> (ORCID: 0000-0002-4512-087X)
License: MIT
"""

import os
import sys
from pathlib import Path
from typing import Optional

import boto3
from botocore.exceptions import ClientError, EndpointConnectionError


def get_s3_client() -> boto3.client:
    """Create and configure boto3 S3 client for MinIO.

    Reads connection parameters from environment variables and creates a
    configured S3 client suitable for MinIO object storage.

    Returns
    -------
    boto3.client
        Configured S3 client connected to MinIO endpoint.

    Raises
    ------
    ValueError
        If required environment variables are missing.

    Examples
    --------
    >>> client = get_s3_client()
    >>> response = client.list_buckets()
    """
    endpoint_url = os.getenv('S3_ENDPOINT_URL')
    access_key = os.getenv('S3_ACCESS_KEY')
    secret_key = os.getenv('S3_SECRET_KEY')

    if not all([endpoint_url, access_key, secret_key]):
        raise ValueError(
            "Missing required environment variables:\n"
            "  S3_ENDPOINT_URL, S3_ACCESS_KEY, S3_SECRET_KEY\n"
            "Please set these before running this script."
        )

    print(f"Connecting to MinIO at {endpoint_url}...")

    return boto3.client(
        's3',
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
    )


def upload_file(
    s3_client: boto3.client,
    file_path: Path,
    bucket: str,
    object_key: Optional[str] = None
) -> bool:
    """Upload a single file to MinIO bucket.

    Parameters
    ----------
    s3_client : boto3.client
        Configured S3 client.
    file_path : Path
        Local path to file to upload.
    bucket : str
        Target S3 bucket name.
    object_key : str, optional
        Object key (S3 path) for uploaded file. If None, uses file basename.

    Returns
    -------
    bool
        True if upload succeeded, False otherwise.

    Examples
    --------
    >>> client = get_s3_client()
    >>> success = upload_file(client, Path('test.nc'), 'test-bucket')
    Uploading test.nc to s3://test-bucket/test.nc...
    ✓ Upload successful (1234 bytes)
    """
    if object_key is None:
        object_key = file_path.name

    file_size = file_path.stat().st_size

    print(f"Uploading {file_path.name} to s3://{bucket}/{object_key}...")

    try:
        s3_client.upload_file(
            str(file_path),
            bucket,
            object_key,
            ExtraArgs={'ACL': 'public-read'}
        )
        print(f"  ✓ Upload successful ({file_size:,} bytes)")
        return True

    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        error_msg = e.response.get('Error', {}).get('Message', str(e))
        print(f"  ✗ Upload failed: [{error_code}] {error_msg}", file=sys.stderr)
        return False

    except Exception as e:
        print(f"  ✗ Upload failed: {e}", file=sys.stderr)
        return False


def upload_fixtures(
    fixtures_dir: Path = Path('test/fixtures'),
    bucket: str = 'test-bucket'
) -> int:
    """Upload all NetCDF fixtures to MinIO bucket.

    Scans the fixtures directory for all .nc files and uploads them to the
    specified MinIO bucket.

    Parameters
    ----------
    fixtures_dir : Path, default='test/fixtures'
        Directory containing NetCDF fixture files.
    bucket : str, default='test-bucket'
        Target MinIO bucket name.

    Returns
    -------
    int
        Number of files successfully uploaded.

    Raises
    ------
    FileNotFoundError
        If fixtures directory doesn't exist.
    EndpointConnectionError
        If cannot connect to MinIO endpoint.

    Examples
    --------
    >>> uploaded = upload_fixtures()
    Uploading NetCDF fixtures to MinIO...
    Fixtures directory: /path/to/test/fixtures
    Target bucket: test-bucket

    Found 3 NetCDF files to upload:
      - ocean_profile.nc (17.77 KB)
      - ocean_surface_medium.nc (50.05 KB)
      - ocean_surface_small.nc (30.52 KB)

    Uploading ocean_profile.nc to s3://test-bucket/ocean_profile.nc...
    ✓ Upload successful (18,196 bytes)
    ...

    Upload complete! 3/3 files uploaded successfully.
    """
    if not fixtures_dir.exists():
        raise FileNotFoundError(
            f"Fixtures directory not found: {fixtures_dir.absolute()}\n"
            f"Please run create_fixtures.py first."
        )

    print("\nUploading NetCDF fixtures to MinIO...")
    print(f"Fixtures directory: {fixtures_dir.absolute()}")
    print(f"Target bucket: {bucket}\n")

    # Get S3 client
    try:
        s3_client = get_s3_client()
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 0
    except EndpointConnectionError as e:
        print(f"Error: Cannot connect to MinIO endpoint: {e}", file=sys.stderr)
        return 0

    # Find all NetCDF files
    nc_files = sorted(fixtures_dir.glob('*.nc'))

    if not nc_files:
        print("No NetCDF files found in fixtures directory!", file=sys.stderr)
        return 0

    print(f"Found {len(nc_files)} NetCDF file(s) to upload:")
    for nc_file in nc_files:
        size_kb = nc_file.stat().st_size / 1024
        print(f"  - {nc_file.name} ({size_kb:.2f} KB)")

    print()

    # Upload each file
    success_count = 0
    for nc_file in nc_files:
        if upload_file(s3_client, nc_file, bucket):
            success_count += 1

    print(f"\nUpload complete! {success_count}/{len(nc_files)} file(s) uploaded successfully.")

    if success_count < len(nc_files):
        print(f"Warning: {len(nc_files) - success_count} file(s) failed to upload.", file=sys.stderr)

    return success_count


def main() -> None:
    """Main entry point for upload script.

    Uploads all NetCDF fixtures from test/fixtures/ to MinIO test-bucket.
    Exits with status code 0 on success, 1 on failure.

    Returns
    -------
    None
        Script exits with appropriate status code.
    """
    try:
        uploaded = upload_fixtures()

        if uploaded == 0:
            print("\nNo files were uploaded. Check errors above.", file=sys.stderr)
            sys.exit(1)

        sys.exit(0)

    except Exception as e:
        print(f"\nFatal error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
