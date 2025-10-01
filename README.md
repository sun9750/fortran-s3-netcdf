# fortran-s3-netcdf

[![GitHub release](https://img.shields.io/github/v/release/pgierz/fortran-s3-netcdf?include_prereleases)](https://github.com/pgierz/fortran-s3-netcdf/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Fortran](https://img.shields.io/badge/Fortran-2008-734f96.svg)](https://fortran-lang.org/)
[![FPM](https://img.shields.io/badge/FPM-package-blueviolet)](https://fpm.fortran-lang.org/)

NetCDF integration for `fortran-s3-accessor` - provides transparent S3 URIs with automatic cleanup and optimal temp file management.

## Features

- **Transparent S3 URIs**: Use `s3://bucket/path/to/file.nc` directly with NetCDF
- **Automatic cleanup**: Temp files removed automatically on close
- **RAM disk optimization**: Prefers `/dev/shm` on Linux (zero disk I/O!)
- **Drop-in replacement**: Use `s3_nf90_open()` instead of `nf90_open()`
- **Full NetCDF compatibility**: Works with all NetCDF-Fortran operations

## Quick Start

```fortran
program example
    use s3_http
    use s3_netcdf
    use netcdf
    implicit none

    type(s3_config) :: config
    integer :: ncid, status

    ! Configure S3
    config%endpoint = 's3.amazonaws.com'
    config%region = 'us-east-1'
    config%use_https = .true.
    call s3_init(config)

    ! Open NetCDF file from S3 (transparent!)
    status = s3_nf90_open('s3://esgf-world/CMIP6/.../data.nc', NF90_NOWRITE, ncid)

    ! Use NetCDF normally
    ! ... read variables, dimensions, attributes ...

    ! Close and auto-cleanup
    status = s3_nf90_close(ncid)
end program
```

## Installation

### From FPM (when published)

```toml
[dependencies]
fortran-s3-netcdf = "0.1.0"
```

### From Source

```bash
git clone https://github.com/pgierz/fortran-s3-netcdf.git
cd fortran-s3-netcdf
fpm build
fpm run s3_netcdf_example
```

## How It Works

1. **Download**: Streams S3 object to memory using `fortran-s3-accessor`
2. **Cache**: Writes to temp file (prefers `/dev/shm` RAM disk)
3. **Open**: Returns NetCDF file handle via `nf90_open()`
4. **Track**: Registers handle for automatic cleanup
5. **Cleanup**: `s3_nf90_close()` removes temp file automatically

## Performance

- **Network → Memory**: Direct streaming via POSIX popen (no temp files during download)
- **Memory → NetCDF**: Writes to `/dev/shm` on Linux (RAM disk, zero disk I/O!)
- **Fallback**: Uses `/tmp` on non-Linux systems
- **Overhead**: ~10ms for small files, ~10-30% for large files (vs direct S3 access)

## API Reference

### Functions

#### `s3_nf90_open(uri, mode, ncid) result(status)`
Open NetCDF file from S3 URI.

**Parameters:**
- `uri` (character) - S3 URI (`s3://bucket/path/to/file.nc`)
- `mode` (integer) - NetCDF open mode (`NF90_NOWRITE`, etc.)
- `ncid` (integer, out) - NetCDF file ID

**Returns:** NetCDF status code

#### `s3_nf90_close(ncid) result(status)`
Close NetCDF file and cleanup temp file.

**Parameters:**
- `ncid` (integer) - NetCDF file ID from `s3_nf90_open()`

**Returns:** NetCDF status code

#### `get_optimal_temp_dir() result(dir)`
Get optimal temp directory for current platform.

**Returns:** `/dev/shm` on Linux, `/tmp` elsewhere

## Examples

See `app/s3_netcdf_example.f90` for a complete working example with:
- S3 configuration
- Opening ESGF climate data
- Reading dimensions and variables
- Querying global attributes
- Proper error handling

## Requirements

- **fortran-s3-accessor** >= 1.0.1
- **NetCDF-Fortran** library
- POSIX-compliant system (Linux, macOS, Unix)

## Future Development

This package is intended to be moved to a separate repository:
- `https://github.com/pgierz/fortran-s3-netcdf` (future)

Currently nested in `fortran-s3-accessor` as proof-of-concept.

### Planned Features

- [ ] Asynchronous prefetch for sequential access patterns
- [ ] Caching layer for repeated access
- [ ] Parallel downloads for chunked NetCDF files
- [ ] Integration with Zarr format
- [ ] Support for write operations (PUT)

## License

MIT License - See LICENSE file in parent repository.

## Contributing

This is currently a nested project. Once moved to separate repository:
- Issues: https://github.com/pgierz/fortran-s3-netcdf/issues
- Pull requests welcome!

## Acknowledgments

Built on top of:
- [fortran-s3-accessor](https://github.com/pgierz/fortran-s3-accessor) - Generic S3 library
- [NetCDF-Fortran](https://github.com/Unidata/netcdf-fortran) - NetCDF interface
