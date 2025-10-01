# Claude Context: fortran-s3-netcdf

## Project Overview

This is the NetCDF integration package for `fortran-s3-accessor`. It was extracted from the main repository to keep the core S3 library domain-agnostic while providing a full-featured NetCDF-specific implementation.

## Current Status (as of 2025-10-01)

**Repository State:** Not yet initialized as git repo
**Parent Dependency:** Uses local path `../fortran-s3-accessor/` (needs update to git tag)
**Version:** 0.1.0
**Parent Library:** fortran-s3-accessor v1.1.0 (released 2025-10-01)

## Latest Updates from Parent Library

### fortran-s3-accessor v1.1.0 Release

**Released:** October 1, 2025
**GitHub Release:** https://github.com/pgierz/fortran-s3-accessor/releases/tag/v1.1.0
**Milestone:** [v1.2.0 - Christmas Release 🎄](https://github.com/pgierz/fortran-s3-accessor/milestone/1) (target: 2025-12-25)

**Major Features:**
- ✅ **Direct memory streaming** via POSIX `popen()` eliminates disk I/O on Linux/macOS/Unix
- ✅ **Comprehensive logging system** via `s3_logger` module (configurable via `S3_LOG_LEVEL`)
- ✅ **NetCDF integration example** (`examples/netcdf_minimal.f90`) in CI
- ✅ **Performance:** ~10ms overhead vs 10-30% in v1.0.x

**Platform Support:**
- Linux/macOS/Unix: Direct streaming (zero temp files during download)
- Windows: Temp file fallback (native streaming planned for v1.2.0)

**Documentation:**
- CHANGELOG.md added with full release notes
- README updated with v1.1.0 performance characteristics
- FORD docs describe streaming architecture

## Architecture

### Module Structure

- **src/s3_netcdf.f90** - Main NetCDF wrapper module providing:
  - `s3_nf90_open()` - Opens NetCDF file from S3 URI (`s3://bucket/key`)
  - `s3_nf90_close()` - Closes and cleanup temp file
  - `get_optimal_temp_dir()` - Returns `/dev/shm` on Linux, `/tmp` elsewhere
  - Internal tracking system for temp file cleanup

### Example Application

- **app/s3_netcdf_example.f90** - Working example that:
  - Downloads ESGF climate data (AWI-ESM-1-1-LR areacella grid file)
  - Opens with NetCDF-Fortran
  - Reads dimensions, variables, and attributes
  - Demonstrates proper error handling

## Dependencies

### Current (fpm.toml) - Needs Update

```toml
[dependencies]
# OUTDATED: Currently uses path dependency
fortran-s3-accessor = { path = "../fortran-s3-accessor" }
netcdf-fortran = { git = "https://github.com/LKedward/netcdf-interfaces.git" }
```

### Recommended Update

```toml
[dependencies]
# Use v1.1.0 release tag
fortran-s3-accessor = { git = "https://github.com/pgierz/fortran-s3-accessor.git", tag = "v1.1.0" }
netcdf-fortran = { git = "https://github.com/LKedward/netcdf-interfaces.git" }
```

## Next Steps (TODO)

### 1. Update Dependency
```bash
# Edit fpm.toml to use v1.1.0 tag
fortran-s3-accessor = { git = "https://github.com/pgierz/fortran-s3-accessor.git", tag = "v1.1.0" }
```

### 2. Test Build
```bash
cd /Users/pgierz/Code/github.com/pgierz/fortran-s3-netcdf
fpm build
fpm run s3_netcdf_example
```

### 3. Initialize Git Repository
```bash
git init
git add .
git commit -m "Initial commit: NetCDF integration for fortran-s3-accessor v1.1.0

Built on top of fortran-s3-accessor v1.1.0 with direct memory streaming.

Features:
- Transparent S3 URIs for NetCDF files
- Automatic temp file cleanup
- RAM disk optimization (/dev/shm on Linux)
- Drop-in replacement for nf90_open/close

Depends on:
- fortran-s3-accessor v1.1.0+
- NetCDF-Fortran library"
```

### 4. Create GitHub Repository
```bash
gh repo create pgierz/fortran-s3-netcdf --public --source=. --description "NetCDF integration for fortran-s3-accessor - transparent S3 URIs with automatic cleanup"
git push -u origin main
```

### 5. Tag Initial Release
```bash
git tag -a v0.1.0 -m "Initial release: NetCDF integration for fortran-s3-accessor

Compatible with:
- fortran-s3-accessor v1.1.0+
- NetCDF-Fortran 4.x

Features:
- s3_nf90_open() for S3 URIs
- s3_nf90_close() with auto-cleanup
- /dev/shm RAM disk optimization
- Complete working example"

git push origin v0.1.0
```

### 6. Optional: Create Release on GitHub
```bash
gh release create v0.1.0 \
  --title "v0.1.0 - Initial Release" \
  --notes "First release of fortran-s3-netcdf

Compatible with fortran-s3-accessor v1.1.0+

See README for usage examples."
```

## Key Design Decisions

### Why Separate Repository?

- Keeps core S3 library generic and domain-agnostic
- Allows independent development and versioning
- Avoids forcing NetCDF dependency on all S3 users
- Maintains minimal example in main repo for CI demonstration

### Temp File Strategy

- **Linux**: Uses `/dev/shm` (RAM disk) for zero disk I/O
- **Other OS**: Falls back to `/tmp`
- **Cleanup**: Automatic via `s3_nf90_close()` with internal tracking

### Performance Characteristics (with v1.1.0)

- **Network → Memory**: Direct streaming via popen (no temp during download)
- **Memory → NetCDF**: Writes to temp file (RAM disk preferred)
- **Overall**: ~10ms overhead for small files (excellent!)

### Limitations

Current implementation reads entire file to memory before writing to temp file. This has O(n²) memory implications for very large files (>1GB). Future versions should implement streaming directly to temp file.

## File Structure

```
fortran-s3-netcdf/
├── fpm.toml                   # Package metadata and dependencies
├── README.md                  # User-facing documentation
├── CLAUDE_CONTEXT.md         # This file - context for Claude Code
├── src/
│   └── s3_netcdf.f90         # Main wrapper module
└── app/
    └── s3_netcdf_example.f90 # Working example
```

## Example Usage

```fortran
program example
    use s3_http
    use s3_netcdf
    use netcdf
    implicit none

    type(s3_config) :: config
    integer :: ncid, status

    ! Configure S3 for ESGF
    config%endpoint = 'esgf-world.s3.amazonaws.com'
    config%region = 'us-east-1'
    config%use_https = .true.
    call s3_init(config)

    ! Open NetCDF file from S3 (transparent!)
    status = s3_nf90_open('s3://esgf-world/CMIP6/.../data.nc', NF90_NOWRITE, ncid)

    if (status /= NF90_NOERR) then
        print *, 'Error opening file:', nf90_strerror(status)
        stop 1
    end if

    ! Use NetCDF normally
    ! ... read variables, dimensions, attributes ...

    ! Close and auto-cleanup temp file
    status = s3_nf90_close(ncid)
end program
```

## Testing

Currently no automated tests. Should add:
- Unit tests for URI parsing
- Tests for temp file creation/cleanup
- Tests with mock S3 backend
- Integration tests with real NetCDF files
- Platform-specific tests (Linux /dev/shm vs other OS /tmp)

## Documentation Needs

- API reference (consider FORD)
- Usage examples beyond basic case
- Performance benchmarking with v1.1.0 backend
- Comparison with other approaches
- Installation guide
- Troubleshooting section

## Related Repositories

### fortran-s3-accessor (Parent Library)

**URL:** https://github.com/pgierz/fortran-s3-accessor
**Current Version:** v1.1.0 (released 2025-10-01)
**Next Version:** v1.2.0 (Christmas 2025 🎄)

**Features:**
- Direct memory streaming via POSIX popen
- Comprehensive logging system
- Minimal NetCDF example in `examples/netcdf_minimal.f90`
- Platform support: Linux/macOS (native), Windows (fallback)

**v1.2.0 Roadmap (relevant to this package):**
- [#9: libcurl integration](https://github.com/pgierz/fortran-s3-accessor/issues/9) - Windows native streaming
- [#10: AWS Sig v4](https://github.com/pgierz/fortran-s3-accessor/issues/10) - Private bucket access
- [#11: Progress callbacks](https://github.com/pgierz/fortran-s3-accessor/issues/11) - Download progress
- [#12: Multipart upload](https://github.com/pgierz/fortran-s3-accessor/issues/12) - Large files >5GB
- [#13: Better errors](https://github.com/pgierz/fortran-s3-accessor/issues/13) - Diagnostics

## Context from Previous Work

### Extraction History

This package was extracted from `fortran-s3-accessor` repository on 2025-10-01:
- Original location: `examples/netcdf/`
- Moved to: `applications/fortran-s3-netcdf/`
- Then relocated to: `/Users/pgierz/Code/github.com/pgierz/fortran-s3-netcdf/`

### CI Integration in Parent Repo

The main `fortran-s3-accessor` repo has:
- Optional NetCDF integration CI job (continues on error)
- Uses minimal example: `examples/netcdf_minimal.f90`
- Tests with gfortran 12, installs libnetcdff-dev
- Runs against real ESGF data
- Demonstrates the pattern this package builds upon

### Design Discussion

From previous session with user:
- User wanted separation: "This is the tool, the climate data is the implementation"
- Agreement: Core = generic tool, separate repo = NetCDF integration
- Minimal example stays in core for CI/demonstration
- Full wrapper extracted to this separate package

## Environment Notes

- Developed on macOS Darwin 24.6.0
- Target: POSIX-compliant systems (Linux, macOS, Unix)
- Fortran 2008 compatibility
- Uses direnv with spack/fpm
- Parent library has Windows fallback (temp files)

## Version Compatibility

### Minimum Requirements
- **fortran-s3-accessor:** v1.1.0+ (for streaming performance)
- **NetCDF-Fortran:** 4.x
- **Fortran Compiler:** Fortran 2008 compliant

### Recommended
- **fortran-s3-accessor:** v1.1.0
- **OS:** Linux (for /dev/shm RAM disk optimization)
- **Compiler:** gfortran 11, 12, or 13

### Future Compatibility
When fortran-s3-accessor v1.2.0 releases (Christmas 2025):
- Will gain Windows native streaming support
- Better error messages for debugging
- Progress callbacks for large downloads
- Private bucket access with AWS Sig v4

## Contact

- Author: Paul Gierz
- Maintainer: pgierz@awi.de
- Homepage: https://github.com/pgierz/fortran-s3-netcdf (to be created)
- Parent Library: https://github.com/pgierz/fortran-s3-accessor

## Quick Start Checklist

When ready to work on this package:

- [ ] Update fpm.toml dependency to v1.1.0 tag
- [ ] Test build and example
- [ ] Initialize git repository
- [ ] Create GitHub repo
- [ ] Tag v0.1.0 release
- [ ] Add CI/CD (optional)
- [ ] Publish to FPM registry (optional, see fortran-s3-accessor#14)
