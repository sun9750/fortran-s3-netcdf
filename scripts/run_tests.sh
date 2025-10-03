#!/bin/bash
#
# Run FPM tests with proper NetCDF configuration
#
# This script automatically detects NetCDF paths and runs tests with
# the correct compiler and linker flags.
#
# Usage:
#   ./scripts/run_tests.sh [fpm-test-args]
#
# Examples:
#   ./scripts/run_tests.sh                    # Run all tests
#   ./scripts/run_tests.sh --verbose          # Verbose output
#   ./scripts/run_tests.sh cache              # Run only cache tests

set -e

# Detect NetCDF configuration
if ! command -v nf-config &> /dev/null; then
    echo "Error: nf-config not found. Please install netcdf-fortran."
    exit 1
fi

# Get NetCDF paths
NETCDF_INCLUDE=$(nf-config --includedir)
NETCDF_FFLAGS=$(nf-config --fflags)

# Platform-specific library path
case "$(uname -s)" in
    Darwin*)
        # macOS - typically homebrew installation
        NETCDF_LIBDIR="/opt/homebrew/lib"
        ;;
    Linux*)
        # Linux - check common locations
        if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
            NETCDF_LIBDIR="/usr/lib/x86_64-linux-gnu"
        elif [ -d "/usr/lib64" ]; then
            NETCDF_LIBDIR="/usr/lib64"
        else
            NETCDF_LIBDIR="/usr/lib"
        fi
        ;;
    *)
        echo "Warning: Unknown platform $(uname -s). Using /usr/lib"
        NETCDF_LIBDIR="/usr/lib"
        ;;
esac

# Build flags
FPM_FLAGS="-I${NETCDF_INCLUDE} -L${NETCDF_LIBDIR}"

# Run tests
echo "Running FPM tests with NetCDF configuration:"
echo "  Include: ${NETCDF_INCLUDE}"
echo "  Library: ${NETCDF_LIBDIR}"
echo ""

exec fpm test --flag "${FPM_FLAGS}" "$@"
