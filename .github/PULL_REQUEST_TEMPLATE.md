## Description

<!-- Provide a clear and concise description of what this PR does -->

## Type of Change

<!-- Mark the relevant option with an 'x' -->

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring (no functional changes)
- [ ] Build/CI changes
- [ ] Other (please describe):

## Related Issues

<!-- Link to related issues -->
Fixes #
Related to #

## Changes Made

<!-- Describe the changes in detail. What was modified and why? -->

-
-
-

## Testing

<!-- Describe the tests you've added or run to verify your changes -->

### Test Environment
- **Platform**: <!-- Linux/macOS/Windows -->
- **Compiler**: <!-- e.g., gfortran 12.2.0 -->
- **fortran-s3-accessor version**: <!-- e.g., v1.1.0 -->

### Tests Performed
- [ ] Built successfully with `fpm build`
- [ ] Ran example with `fpm run s3_netcdf_example`
- [ ] Added unit tests (if applicable)
- [ ] Tested on multiple platforms (if applicable)
- [ ] Verified with real S3 data
- [ ] Performance benchmarking (if applicable)

### Test Results
<!-- Paste relevant test output or describe what you verified -->

```
# Paste test output here if relevant
```

## API Changes

<!-- If this PR changes the public API, describe the changes -->

### Breaking Changes
<!-- List any breaking changes and migration steps -->

- [ ] No breaking changes
- [ ] Breaking changes (describe below):

### New API
<!-- List any new public functions, types, or modules -->

```fortran
! Example of new API
```

## Performance Impact

<!-- Describe any performance implications -->

- [ ] No performance impact
- [ ] Performance improvement (describe below)
- [ ] Performance regression (justify below)

## Documentation

<!-- What documentation was updated? -->

- [ ] Code comments updated
- [ ] README updated
- [ ] CLAUDE.md updated (if architecture changed)
- [ ] API documentation updated
- [ ] Examples updated/added
- [ ] CHANGELOG.md updated

## Checklist

<!-- Verify you've completed these items -->

- [ ] My code follows the project's Fortran style
- [ ] I've commented my code, particularly in hard-to-understand areas
- [ ] I've updated documentation to reflect my changes
- [ ] My changes generate no new compiler warnings
- [ ] I've tested my changes on at least one platform
- [ ] I've checked that temp files are properly cleaned up (for S3 changes)
- [ ] I've considered error handling for new code paths
- [ ] I've verified this works with both `/dev/shm` and `/tmp` (if relevant)

## Additional Context

<!-- Add any other context, screenshots, benchmarks, or notes about the PR here -->

---

<!-- For Maintainers -->
## Reviewer Notes

<!-- Maintainers can add notes here during review -->
