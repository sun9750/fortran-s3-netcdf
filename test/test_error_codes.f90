module test_error_codes
    use testdrive, only : new_unittest, unittest_type, error_type, check
    use netcdf, only : NF90_EINVAL, NF90_EPERM, NF90_EMAXNAME, NF90_NOERR
    implicit none
    private

    public :: collect_error_code_tests

contains

    !> Collect all error code tests
    subroutine collect_error_code_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)

        testsuite = [ &
            new_unittest("error_codes_defined", test_error_codes_defined) &
        ]

    end subroutine collect_error_code_tests

    !> Test that all NetCDF error codes we use are actually defined
    subroutine test_error_codes_defined(error)
        type(error_type), allocatable, intent(out) :: error

        ! Just verify the constants exist and have expected values
        call check(error, NF90_NOERR == 0, "NF90_NOERR should be 0")
        if (allocated(error)) return

        call check(error, NF90_EINVAL == -36, "NF90_EINVAL should be -36")
        if (allocated(error)) return

        call check(error, NF90_EPERM == -37, "NF90_EPERM should be -37")
        if (allocated(error)) return

        call check(error, NF90_EMAXNAME == -53, "NF90_EMAXNAME should be -53")
        if (allocated(error)) return

    end subroutine test_error_codes_defined

end module test_error_codes
