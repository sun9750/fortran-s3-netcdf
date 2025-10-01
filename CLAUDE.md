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

- **fortran-s3-accessor**: Uses git dependency `{ git = "https://github.com/pgierz/fortran-s3-accessor.git", tag = "v1.1.0" }`
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
- `NF90_EINVAL` - S3 download failed or invalid URI
- `NF90_EMAXNAME` - Too many open handles (>100)
- `NF90_EPERM` - Cannot create or write temp file (permission denied)
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

**Current state**: Standalone git repository at `https://github.com/pgierz/fortran-s3-netcdf`

**Completed migration**:
- ✅ Moved to standalone repository
- ✅ Git dependency on fortran-s3-accessor v1.1.0
- ✅ Issue templates and PR template
- ✅ Project milestones (v0.1.0, v0.2.0, v1.0.0)
- ✅ Comprehensive issue tracking for all planned features
- Parent library keeps minimal example (`examples/netcdf_minimal.f90`) for CI demonstration

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

## Git Workflow

This project uses milestone-based development branches with release candidate testing before production releases.

### Branch Structure
- **`master`**: Production releases only. Protected branch. Only contains tagged final releases.
- **`develop/v0.1.0`**, **`develop/v0.2.0`**, **`develop/v1.0.0`**: Milestone development branches
- **`rc/v0.1.0`**, **`rc/v0.2.0`**: Release candidate branches for final testing
- **`feature/<name>`**: Feature branches for individual issues
- **`hotfix/<name>`**: Emergency fixes for production issues

### Workflow for New Features

1. **Identify target milestone** from issue labels
2. **Create feature branch** from appropriate milestone branch:
   ```bash
   git checkout develop/v0.1.0
   git pull
   git checkout -b feature/my-feature
   ```
3. **Develop with TDD approach**:
   - Write test (or update CI)
   - Run locally if possible
   - Commit changes
   - Push and create PR targeting milestone branch
   - CI runs automatically - review results
   - Iterate until green
4. **Create PR** targeting the milestone develop branch (NOT master)
5. **CI validates** - must pass before merge
6. **Review and merge** to milestone branch
7. **Delete feature branch** after merge

### Release Candidate Process

When all issues in a milestone are complete and ready for release:

1. **Create RC branch** from develop branch:
   ```bash
   git checkout develop/v0.1.0
   git checkout -b rc/v0.1.0
   git push -u origin rc/v0.1.0
   ```

2. **Tag first release candidate**:
   ```bash
   git tag -a v0.1.0-rc.1 -m "Release candidate 1 for v0.1.0"
   git push origin v0.1.0-rc.1
   ```

3. **Create GitHub pre-release**:
   - Mark as pre-release
   - Announce for testing
   - Document known issues/testing needed

4. **If issues found during RC testing**:
   - Create fix branches from `rc/v0.1.0`
   - PR fixes back to `rc/v0.1.0`
   - Tag new RC: `v0.1.0-rc.2`, `v0.1.0-rc.3`, etc.
   - Also backport critical fixes to `develop/v0.1.0` if needed

5. **When RC is stable** (no critical issues found):
   - Proceed to final release

### Final Release Process

1. **Ensure RC branch CI is green** and no known critical issues
2. **Create PR**: `rc/v0.1.0` → `master`
3. **Final review and approval**
4. **Merge to master**
5. **Tag final release**:
   ```bash
   git checkout master
   git pull
   git tag -a v0.1.0 -m "Release v0.1.0"
   git push origin v0.1.0
   ```
6. **Create GitHub release** (not pre-release):
   - Comprehensive changelog
   - Link to milestone
   - Migration notes if applicable
7. **Merge master back to develop branch** to capture any RC fixes:
   ```bash
   git checkout develop/v0.1.0
   git merge master
   git push
   ```
8. **Close milestone** in GitHub

### Example Release Timeline

```
develop/v0.1.0 (ongoing work)
    ↓
rc/v0.1.0 created
    ↓
v0.1.0-rc.1 tagged ← testing phase
    ↓
[bug found] → fix → v0.1.0-rc.2 tagged
    ↓
[bug found] → fix → v0.1.0-rc.3 tagged
    ↓
[stable, tested] → PR to master → v0.1.0 tagged
    ↓
master ← final release
    ↓
merge back to develop/v0.1.0 (capture any RC fixes)
```

### Branch Protection Rules
- **master**: Requires PR, requires CI pass, requires review, no direct pushes
- **develop/***: Requires PR, requires CI pass, no direct pushes
- **rc/***: Requires PR for fixes, requires CI pass

### Tagging Conventions
- **Development**: No tags on develop branches
- **Release Candidates**: `v0.1.0-rc.1`, `v0.1.0-rc.2`, etc. (semantic versioning with RC suffix)
- **Final Releases**: `v0.1.0`, `v0.2.0`, `v1.0.0` (semantic versioning)
- **Hotfixes**: `v0.1.1`, `v0.1.2` (patch version bump)

### Important Notes
- ALWAYS target milestone develop branch in PRs, never master directly
- CI must pass before merging
- Use TDD: let CI validate your changes
- Release candidates are MANDATORY before any production release
- Minimum 1 RC per release, but create more as needed
- Only promote RC to production when thoroughly tested
- Feature branches should be short-lived (< 1 week)
- RC testing should include real-world usage scenarios
