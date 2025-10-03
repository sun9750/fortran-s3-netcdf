#!/bin/bash
#
# Claude Code slash command: /test-fortran
#
# Run FPM tests with proper NetCDF configuration
#
# Usage in Claude Code:
#   /test-fortran             # Run all tests
#   /test-fortran --verbose   # Verbose output
#   /test-fortran cache       # Run specific test

# Run the main test script
exec "$(dirname "$0")/../../scripts/run_tests.sh" "$@"
