#!/usr/bin/env python3
"""NetCDF Test Fixture Generator for S3 Caching Integration Tests.

This module creates professional-quality synthetic oceanographic datasets for
testing the fortran-s3-netcdf library's S3 caching functionality. All generated
NetCDF files follow CF-1.8 and ACDD-1.3 metadata conventions.

The fixtures include:
    - 2D sea surface temperature and salinity fields on lat/lon grids
    - 1D ocean vertical profiles with temperature and salinity
    - Comprehensive metadata including authorship, provenance, and licensing
    - Realistic (but synthetic) oceanographic value ranges and patterns

Fixtures are designed to be small enough for CI testing while demonstrating
best practices in scientific data management.

Examples
--------
Create all fixtures::

    $ python test/scripts/create_fixtures.py

This creates NetCDF files in test/fixtures/:
    - ocean_surface_small.nc (10x10 grid)
    - ocean_surface_medium.nc (50x50 grid)
    - ocean_profile.nc (50 depth levels)

Notes
-----
All data is synthetically generated and NOT suitable for scientific research.
These files are exclusively for software testing purposes.

Author: Paul Gierz <paul.gierz@awi.de> (ORCID: 0000-0002-4512-087X)
License: MIT
"""

import netCDF4 as nc
import numpy as np
from pathlib import Path
from datetime import datetime, timezone


def create_ocean_2d_netcdf(filepath: Path, nx: int = 10, ny: int = 10) -> None:
    """Create a 2D NetCDF file with sea surface temperature and salinity.

    Generates a CF-1.8 compliant NetCDF file containing synthetic ocean surface
    data on a regular lat/lon grid. The data includes realistic spatial patterns:
    - SST: Warmer at equator (30°C), colder at poles (-2°C)
    - SSS: Higher in subtropics (36 psu), lower at equator/poles (33 psu)

    Parameters
    ----------
    filepath : Path
        Path where the NetCDF file will be created. Parent directory must exist.
    nx : int, default=10
        Number of grid points in longitude dimension.
    ny : int, default=10
        Number of grid points in latitude dimension.

    Returns
    -------
    None
        File is created on disk at specified path.

    Notes
    -----
    File includes comprehensive metadata following CF-1.8 and ACDD-1.3 conventions:
    - Creator information with ORCID
    - Institution and project details
    - Geospatial coverage
    - License and usage constraints
    - Full provenance and history

    Examples
    --------
    >>> from pathlib import Path
    >>> create_ocean_2d_netcdf(Path('test.nc'), nx=20, ny=20)
    Created: test.nc (12345 bytes)
    """
    # Create file
    ds = nc.Dataset(filepath, 'w', format='NETCDF4')

    # Define dimensions
    ds.createDimension('lon', nx)
    ds.createDimension('lat', ny)
    ds.createDimension('time', None)  # unlimited

    # Create coordinate variables
    lon = ds.createVariable('lon', 'f4', ('lon',))
    lon.units = 'degrees_east'
    lon.long_name = 'longitude'
    lon.standard_name = 'longitude'
    lon[:] = np.linspace(-180, 180, nx)

    lat = ds.createVariable('lat', 'f4', ('lat',))
    lat.units = 'degrees_north'
    lat.long_name = 'latitude'
    lat.standard_name = 'latitude'
    lat[:] = np.linspace(-90, 90, ny)

    time = ds.createVariable('time', 'f8', ('time',))
    time.units = 'days since 2000-01-01'
    time.calendar = 'gregorian'
    time.long_name = 'time'
    time[:] = [0]

    # Create sea surface temperature variable
    sst = ds.createVariable('sst', 'f4', ('time', 'lat', 'lon'),
                           fill_value=-999.0)
    sst.units = 'degree_Celsius'
    sst.long_name = 'Sea Surface Temperature'
    sst.standard_name = 'sea_surface_temperature'

    # Fill with synthetic SST (warmer near equator)
    sst_data = np.zeros((1, ny, nx), dtype=np.float32)
    for i in range(ny):
        for j in range(nx):
            lat_val = lat[i]
            # Warmer at equator (30°C), colder at poles (-2°C)
            sst_data[0, i, j] = 30.0 - 32.0 * (abs(lat_val) / 90.0)
    sst[:] = sst_data

    # Create sea surface salinity variable
    sss = ds.createVariable('sss', 'f4', ('time', 'lat', 'lon'),
                           fill_value=-999.0)
    sss.units = 'psu'
    sss.long_name = 'Sea Surface Salinity'
    sss.standard_name = 'sea_surface_salinity'

    # Fill with synthetic SSS (higher in subtropics)
    sss_data = np.zeros((1, ny, nx), dtype=np.float32)
    for i in range(ny):
        for j in range(nx):
            lat_val = lat[i]
            # Higher salinity in subtropics (~35-37 psu), lower at equator and poles (~33-34 psu)
            sss_data[0, i, j] = 34.0 + 2.0 * np.cos(2 * np.pi * lat_val / 180.0)
    sss[:] = sss_data

    # Global attributes (CF-1.8 and ACDD-1.3 compliant)
    # Core identification
    ds.title = 'Synthetic Ocean Surface Data for S3 Caching Integration Tests'
    ds.summary = ('High-quality synthetic sea surface temperature and salinity fields '
                  'designed for testing S3-backed NetCDF file access with local caching. '
                  'Data follows CF-1.8 conventions and represents idealized oceanographic '
                  'conditions with realistic value ranges and spatial patterns.')
    ds.keywords = 'oceanography, sea surface temperature, sea surface salinity, test data, S3, caching'
    ds.id = f'fortran-s3-netcdf-test-ocean2d-{nx}x{ny}'
    ds.naming_authority = 'io.github.pgierz'

    # Conventions and standards
    ds.Conventions = 'CF-1.8, ACDD-1.3'
    ds.standard_name_vocabulary = 'CF Standard Name Table v79'

    # Creator and contributor information
    ds.creator_name = 'Paul Gierz'
    ds.creator_email = 'paul.gierz@awi.de'
    ds.creator_url = 'https://orcid.org/0000-0002-4512-087X'
    ds.creator_institution = 'Alfred Wegener Institute for Polar and Marine Research'
    ds.creator_type = 'person'

    # Institution and project
    ds.institution = 'Alfred Wegener Institute for Polar and Marine Research'
    ds.project = 'fortran-s3-netcdf Test Suite Development'
    ds.program = 'Open Source Scientific Software Development'
    ds.acknowledgment = ('This synthetic dataset was created specifically for software testing. '
                        'It is not based on observations or model output.')

    # Source and processing
    ds.source = ('Algorithmically generated synthetic oceanographic data with physically '
                'plausible spatial patterns. SST based on latitude-dependent temperature '
                'gradient (warm equator, cold poles). SSS based on evaporation-precipitation '
                'patterns (high salinity in subtropics).')
    ds.processing_level = 'Synthetic test data'

    # Temporal coverage
    creation_time = datetime.now(timezone.utc).isoformat()
    ds.date_created = creation_time
    ds.date_modified = creation_time
    ds.date_issued = creation_time
    ds.date_metadata_modified = creation_time

    # Geospatial coverage
    ds.geospatial_lat_min = -90.0
    ds.geospatial_lat_max = 90.0
    ds.geospatial_lat_units = 'degrees_north'
    ds.geospatial_lon_min = -180.0
    ds.geospatial_lon_max = 180.0
    ds.geospatial_lon_units = 'degrees_east'
    ds.geospatial_vertical_min = 0.0
    ds.geospatial_vertical_max = 0.0
    ds.geospatial_vertical_units = 'm'
    ds.geospatial_vertical_positive = 'up'

    # License and usage
    ds.license = ('MIT License. This test data is freely available for any purpose. '
                 'No warranty is provided. Not suitable for scientific analysis - '
                 'for software testing only.')
    ds.usage_constraints = 'Test data only. Not for scientific research or operational use.'

    # References and documentation
    ds.references = 'https://github.com/pgierz/fortran-s3-netcdf'
    ds.comment = ('Synthetic ocean surface data created with care to demonstrate best '
                 'practices in scientific data management, even for test fixtures. '
                 'All values are algorithmically generated but follow realistic '
                 'oceanographic patterns.')

    # History and provenance
    ds.history = (f'{creation_time} - Created by create_fixtures.py for fortran-s3-netcdf '
                 f'integration testing with MinIO S3 backend. Grid size: {nx}x{ny}')

    # Publisher information
    ds.publisher_name = 'fortran-s3-netcdf Test Suite'
    ds.publisher_email = 'paul.gierz@awi.de'
    ds.publisher_url = 'https://github.com/pgierz/fortran-s3-netcdf'
    ds.publisher_type = 'institution'

    # Product and format version
    ds.product_version = 'v1.0'
    ds.format_version = 'NetCDF-4'
    ds.netcdf_version = nc.__netcdf4libversion__
    ds.hdf5_version = nc.__hdf5libversion__

    ds.close()
    print(f"Created: {filepath} ({filepath.stat().st_size} bytes)")


def create_ocean_profile_netcdf(filepath: Path, nz: int = 50) -> None:
    """Create a 1D NetCDF file with ocean temperature and salinity profiles.

    Generates a CF-1.8 compliant NetCDF file containing synthetic ocean vertical
    profiles from surface (0m) to 1000m depth. The data includes realistic
    vertical structure:
    - Temperature: Exponential decay from warm surface (25°C) to cold deep (4°C)
    - Salinity: Slight halocline with increase from 34.5 to 35.0 psu with depth

    Parameters
    ----------
    filepath : Path
        Path where the NetCDF file will be created. Parent directory must exist.
    nz : int, default=50
        Number of depth levels from surface to 1000m.

    Returns
    -------
    None
        File is created on disk at specified path.

    Notes
    -----
    File includes comprehensive metadata following CF-1.8 and ACDD-1.3 conventions:
    - Creator information with ORCID
    - Institution and project details
    - Vertical geospatial coverage
    - License and usage constraints
    - Full provenance and history

    Examples
    --------
    >>> from pathlib import Path
    >>> create_ocean_profile_netcdf(Path('profile.nc'), nz=100)
    Created: profile.nc (6789 bytes)
    """
    ds = nc.Dataset(filepath, 'w', format='NETCDF4')

    # Define dimension
    ds.createDimension('depth', nz)

    # Create coordinate variable
    depth = ds.createVariable('depth', 'f4', ('depth',))
    depth.units = 'm'
    depth.long_name = 'depth below sea surface'
    depth.standard_name = 'depth'
    depth.positive = 'down'
    depth[:] = np.linspace(0, 1000, nz)  # 0 to 1000m

    # Create ocean temperature profile
    temp = ds.createVariable('temp', 'f4', ('depth',))
    temp.units = 'degree_Celsius'
    temp.long_name = 'Sea Water Temperature'
    temp.standard_name = 'sea_water_temperature'

    # Synthetic profile (exponential decay with depth)
    # Surface: 25°C, Deep: 4°C
    temp[:] = 4.0 + 21.0 * np.exp(-depth[:] / 200.0)

    # Create salinity profile
    sal = ds.createVariable('salinity', 'f4', ('depth',))
    sal.units = 'psu'
    sal.long_name = 'Sea Water Salinity'
    sal.standard_name = 'sea_water_salinity'

    # Synthetic salinity profile (slightly increasing with depth)
    sal[:] = 34.5 + 0.5 * (depth[:] / 1000.0)

    # Global attributes (CF-1.8 and ACDD-1.3 compliant)
    # Core identification
    ds.title = 'Synthetic Ocean Vertical Profile for S3 Caching Integration Tests'
    ds.summary = ('High-quality synthetic ocean temperature and salinity vertical profile '
                  'designed for testing S3-backed NetCDF file access with local caching. '
                  'Data follows CF-1.8 conventions and represents an idealized ocean profile '
                  'from surface (0m) to deep ocean (1000m) with realistic value ranges and '
                  'exponential decay patterns.')
    ds.keywords = 'oceanography, ocean temperature profile, ocean salinity profile, test data, S3, caching, vertical structure'
    ds.id = f'fortran-s3-netcdf-test-profile-{nz}levels'
    ds.naming_authority = 'io.github.pgierz'

    # Conventions and standards
    ds.Conventions = 'CF-1.8, ACDD-1.3'
    ds.standard_name_vocabulary = 'CF Standard Name Table v79'

    # Creator and contributor information
    ds.creator_name = 'Paul Gierz'
    ds.creator_email = 'paul.gierz@awi.de'
    ds.creator_url = 'https://orcid.org/0000-0002-4512-087X'
    ds.creator_institution = 'Alfred Wegener Institute for Polar and Marine Research'
    ds.creator_type = 'person'

    # Institution and project
    ds.institution = 'Alfred Wegener Institute for Polar and Marine Research'
    ds.project = 'fortran-s3-netcdf Test Suite Development'
    ds.program = 'Open Source Scientific Software Development'
    ds.acknowledgment = ('This synthetic dataset was created specifically for software testing. '
                        'It is not based on observations or model output.')

    # Source and processing
    ds.source = ('Algorithmically generated synthetic oceanographic vertical profile with '
                'physically plausible depth structure. Temperature follows exponential decay '
                'from warm surface (25°C) to cold deep ocean (4°C). Salinity shows typical '
                'halocline structure with slight increase with depth.')
    ds.processing_level = 'Synthetic test data'

    # Temporal coverage
    creation_time = datetime.now(timezone.utc).isoformat()
    ds.date_created = creation_time
    ds.date_modified = creation_time
    ds.date_issued = creation_time
    ds.date_metadata_modified = creation_time

    # Geospatial coverage
    ds.geospatial_vertical_min = 0.0
    ds.geospatial_vertical_max = 1000.0
    ds.geospatial_vertical_units = 'm'
    ds.geospatial_vertical_positive = 'down'
    ds.geospatial_vertical_resolution = f'{1000.0 / (nz - 1):.2f} m'

    # License and usage
    ds.license = ('MIT License. This test data is freely available for any purpose. '
                 'No warranty is provided. Not suitable for scientific analysis - '
                 'for software testing only.')
    ds.usage_constraints = 'Test data only. Not for scientific research or operational use.'

    # References and documentation
    ds.references = 'https://github.com/pgierz/fortran-s3-netcdf'
    ds.comment = ('Synthetic ocean vertical profile created with care to demonstrate best '
                 'practices in scientific data management, even for test fixtures. '
                 'Profile represents idealized conditions typical of mid-latitude oceans '
                 'with exponential temperature stratification and weak halocline.')

    # History and provenance
    ds.history = (f'{creation_time} - Created by create_fixtures.py for fortran-s3-netcdf '
                 f'integration testing with MinIO S3 backend. Depth levels: {nz}')

    # Publisher information
    ds.publisher_name = 'fortran-s3-netcdf Test Suite'
    ds.publisher_email = 'paul.gierz@awi.de'
    ds.publisher_url = 'https://github.com/pgierz/fortran-s3-netcdf'
    ds.publisher_type = 'institution'

    # Product and format version
    ds.product_version = 'v1.0'
    ds.format_version = 'NetCDF-4'
    ds.netcdf_version = nc.__netcdf4libversion__
    ds.hdf5_version = nc.__hdf5libversion__

    ds.close()
    print(f"Created: {filepath} ({filepath.stat().st_size} bytes)")


def main() -> None:
    """Create all oceanographic test fixtures for S3 caching integration tests.

    Generates a comprehensive set of NetCDF test files with varying sizes:
    - Small 2D ocean surface data (10x10 grid) - ~4 KB
    - Medium 2D ocean surface data (50x50 grid) - ~20 KB
    - Ocean vertical profile (50 depth levels) - ~8 KB

    All files are created in test/fixtures/ directory (created if needed).

    Returns
    -------
    None
        Files are created on disk in test/fixtures/ directory.

    Notes
    -----
    This function is called when the script is run directly. It provides
    a summary of created files including sizes and counts.

    Examples
    --------
    Run from command line::

        $ python test/scripts/create_fixtures.py
        Creating NetCDF ocean test fixtures...
        Output directory: /path/to/test/fixtures
        Created: test/fixtures/ocean_surface_small.nc (4321 bytes)
        Created: test/fixtures/ocean_surface_medium.nc (23456 bytes)
        Created: test/fixtures/ocean_profile.nc (7890 bytes)

        All ocean fixtures created successfully! 🌊

        Total files: 3

        Fixture summary:
          ocean_profile.nc: 7.70 KB
          ocean_surface_medium.nc: 22.91 KB
          ocean_surface_small.nc: 4.22 KB
    """
    # Create fixtures directory
    fixtures_dir = Path('test/fixtures')
    fixtures_dir.mkdir(parents=True, exist_ok=True)

    print("Creating NetCDF ocean test fixtures...")
    print(f"Output directory: {fixtures_dir.absolute()}")

    # Create different test files
    create_ocean_2d_netcdf(fixtures_dir / 'ocean_surface_small.nc', nx=10, ny=10)
    create_ocean_2d_netcdf(fixtures_dir / 'ocean_surface_medium.nc', nx=50, ny=50)
    create_ocean_profile_netcdf(fixtures_dir / 'ocean_profile.nc', nz=50)

    print("\nAll ocean fixtures created successfully! 🌊")
    print(f"\nTotal files: {len(list(fixtures_dir.glob('*.nc')))}")

    # Print summary
    print("\nFixture summary:")
    for ncfile in sorted(fixtures_dir.glob('*.nc')):
        size_kb = ncfile.stat().st_size / 1024
        print(f"  {ncfile.name}: {size_kb:.2f} KB")


if __name__ == '__main__':
    main()
