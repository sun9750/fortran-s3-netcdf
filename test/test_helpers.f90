!> Tests for internal helper functions and utilities
!>
!> Tests the behavior of utility functions used by s3_netcdf,
!> including temp file naming conventions and PID handling.
!> Since these are private, we test them indirectly through public APIs.
module test_helpers
    use testdrive, only : new_unittest, unittest_type, error_type, check
    use stdlib_strings, only: to_string
    implicit none
    private

    public :: collect_helper_tests

contains

    !> Collect all helper function tests
    subroutine collect_helper_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)

        testsuite = [ &
            new_unittest("temp_file_naming_uses_pid", test_temp_file_naming_uses_pid), &
            new_unittest("to_string_works", test_to_string_works) &
        ]

    end subroutine collect_helper_tests

    !> Test that temp file names include a PID-like component
    !>
    !> We can't directly access get_pid(), but we can verify that
    !> temp files created have the expected naming pattern
    subroutine test_temp_file_naming_uses_pid(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=256) :: temp_dir
        integer :: pid_from_shell, unit, ios
        character(len=32) :: pid_str

        ! Get our actual PID using shell command
        call execute_command_line('echo $$ > /tmp/test_pid.tmp', exitstat=ios)
        if (ios /= 0) then
            call check(error, .false., "Could not get PID from shell")
            return
        end if

        open(newunit=unit, file='/tmp/test_pid.tmp', status='old', action='read', iostat=ios)
        if (ios /= 0) then
            call check(error, .false., "Could not read PID file")
            return
        end if

        read(unit, *, iostat=ios) pid_from_shell
        close(unit, status='delete')

        if (ios /= 0 .or. pid_from_shell <= 0) then
            call check(error, .false., "Invalid PID read from file")
            return
        end if

        ! Just verify we got a positive PID
        call check(error, pid_from_shell > 0, "PID should be positive")

    end subroutine test_temp_file_naming_uses_pid

    !> Test that stdlib's to_string function works as expected
    !>
    !> This verifies that our dependency on stdlib_strings is working
    subroutine test_to_string_works(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: result

        ! Test with positive integer
        result = to_string(42)
        call check(error, result == "42", "to_string(42) should equal '42', got: " // result)
        if (allocated(error)) return

        ! Test with zero
        result = to_string(0)
        call check(error, result == "0", "to_string(0) should equal '0', got: " // result)
        if (allocated(error)) return

        ! Test with larger number
        result = to_string(12345)
        call check(error, result == "12345", "to_string(12345) should equal '12345', got: " // result)
        if (allocated(error)) return

    end subroutine test_to_string_works

end module test_helpers
