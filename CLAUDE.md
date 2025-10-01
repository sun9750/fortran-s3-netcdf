# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NetCDF integration for `fortran-s3-accessor` - provides transparent S3 URIs with automatic cleanup and optimal temp file management. This is a Fortran package built with FPM that enables direct opening of NetCDF files from S3 URIs using `s3_nf90_open()` as a drop-in replacement for `nf90_open()`.

## Build System

This project uses the Fortran Package Manager (FPM).

### Common Commands

```bash
# Build the library and example
fpm build

# Run the example application (downloads real ESGF climate data)
fpm run s3_netcdf_example

# Build in release mode with optimizations
fpm build --profile release
```

### Dependencies

- **fortran-s3-accessor**: Currently uses path dependency `{ path = "../.." }` (nested in parent repo). When moved to standalone repo, update to: `{ git = "https://github.com/pgierz/fortran-s3-accessor.git", tag = "v1.1.0" }`
- **netcdf-fortran**: Uses LKedward's interface wrapper `{ git = "https://github.com/LKedward/netcdf-interfaces.git" }`

## Architecture

### Core Module: src/s3_netcdf.f90

**Key exports:**
- `s3_nf90_open(uri, mode, ncid)` - Opens NetCDF file from S3 URI, returns NetCDF status code
- `s3_nf90_close(ncid)` - Closes NetCDF file and cleans up temp file automatically
- `get_optimal_temp_dir()` - Returns `/dev/shm` on Linux (RAM disk), `/tmp` elsewhere

**Internal design:**
- Downloads S3 object to memory via `fortran-s3-accessor`
- Writes to platform-optimized temp file (prefers `/dev/shm` RAM disk on Linux)
- Opens with standard `nf90_open()` and returns handle
- Tracks file handles in internal registry (max 100 concurrent handles)
- Auto-cleanup on `s3_nf90_close()` removes temp file

**Handle tracking system:**
- Uses `netcdf_handle` type array with 100 slots
- Each handle stores: ncid, temp file path, active status
- Unique temp file names use PID and handle index

### Example Application: app/s3_netcdf_example.f90

Working example that demonstrates:
- S3 configuration for ESGF public bucket
- Opening AWI-ESM climate data from S3
- Reading NetCDF dimensions, variables, and global attributes
- Proper error handling with NetCDF status codes

## Key Implementation Details

### Platform Optimization

The module automatically selects optimal temp directory:
- **Linux**: `/dev/shm` (RAM disk) - zero physical disk I/O
- **macOS/other**: `/tmp` (standard temp directory)

Implementation in `get_optimal_temp_dir()`:
1. Checks if `/dev/shm/` exists
2. Tests write permissions with temporary file
3. Falls back to `/tmp` if unavailable or not writable

### Process ID Generation

Uses `get_pid()` subroutine to generate unique temp filenames:
- Calls `execute_command_line('echo $$ > /tmp/s3_pid.tmp')`
- Reads PID from temp file
- Falls back to PID=0 if unable to determine
- Combines with handle index for uniqueness

### Memory Flow

1. **Download**: S3 → Memory (via `s3_get_uri()` from parent library)
2. **Cache**: Memory → Temp file (stream write with `form='unformatted', access='stream'`)
3. **Open**: Temp file → NetCDF handle (via `nf90_open()`)
4. **Cleanup**: Temp file deleted on `s3_nf90_close()` or program exit

### Performance Characteristics

With fortran-s3-accessor v1.1.0:
- **Network → Memory**: Direct streaming via POSIX popen (no disk I/O during download)
- **Memory → Temp**: Single write to RAM disk (Linux) or /tmp
- **Overhead**: ~10ms for small files, ~10-30% for large files vs direct S3 access

### Error Handling

Returns standard NetCDF error codes:
- `NF90_ENOTFOUND` - S3 download failed
- `NF90_EMAXNAME` - Too many open handles (>100)
- `NF90_EACCESS` - Cannot create temp file
- `NF90_EWRITE` - Failed to write temp file
- All other `nf90_*` errors pass through from NetCDF library

## Critical Usage Rules

**ALWAYS use `s3_nf90_close()` instead of `nf90_close()`** for files opened with `s3_nf90_open()`. Otherwise temp files will not be cleaned up automatically.

Correct pattern:
```fortran
status = s3_nf90_open('s3://bucket/path/file.nc', NF90_NOWRITE, ncid)
! ... use NetCDF operations ...
status = s3_nf90_close(ncid)  ! Cleanup happens here
```

## Current Limitations

1. **Memory constraints**: Entire file loaded to memory before writing to temp file (O(n²) implications for files >1GB)
2. **Read-only**: No support for write operations (PUT to S3)
3. **No caching**: Each open downloads fresh from S3
4. **No streaming**: Cannot stream directly from S3 to NetCDF without temp file (NetCDF requires seekable file)

## Repository Status

**Current state**: Not yet a git repository. Still nested in `fortran-s3-accessor` parent repo.

**Planned migration**:
- Will be moved to standalone repo: `https://github.com/pgierz/fortran-s3-netcdf`
- Parent library keeps minimal example (`examples/netcdf_minimal.f90`) for CI demonstration
- This full wrapper becomes independent package

## Related Work

**Parent library**: [fortran-s3-accessor](https://github.com/pgierz/fortran-s3-accessor) v1.1.0
- Provides generic S3 GET/PUT operations with direct memory streaming
- Comprehensive logging via `s3_logger` module
- Platform support: Linux/macOS (native streaming), Windows (temp file fallback)

**Upcoming v1.2.0 features** (Christmas 2025) that will benefit this package:
- Windows native streaming via libcurl
- AWS Signature v4 for private buckets
- Progress callbacks for large downloads
- Better error diagnostics
