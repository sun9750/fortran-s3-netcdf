module test_temp_dir
    use testdrive, only : new_unittest, unittest_type, error_type, check
    use s3_netcdf, only : get_optimal_temp_dir
    implicit none
    private

    public :: collect_temp_dir_tests

contains

    !> Collect all test_temp_dir tests
    subroutine collect_temp_dir_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)

        testsuite = [ &
            new_unittest("optimal_temp_dir", test_optimal_temp_dir), &
            new_unittest("temp_dir_exists", test_temp_dir_exists), &
            new_unittest("temp_dir_no_trailing_slash", test_temp_dir_no_trailing_slash), &
            new_unittest("temp_dir_consistency", test_temp_dir_consistency), &
            new_unittest("dev_shm_check", test_dev_shm_check) &
        ]

    end subroutine collect_temp_dir_tests

    !> Test that get_optimal_temp_dir returns a non-empty string
    subroutine test_optimal_temp_dir(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: temp_dir

        temp_dir = get_optimal_temp_dir()

        call check(error, len(temp_dir) > 0, "Temp dir should not be empty")
        if (allocated(error)) return

    end subroutine test_optimal_temp_dir

    !> Test that the returned temp directory exists and is writable
    subroutine test_temp_dir_exists(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: temp_dir
        logical :: dir_exists
        integer :: unit, ios

        temp_dir = get_optimal_temp_dir()

        ! Check if directory exists by trying to create a temp file
        open(newunit=unit, file=trim(temp_dir)//'/test_write.tmp', &
             status='replace', action='write', iostat=ios)

        if (ios == 0) then
            close(unit, status='delete')
            dir_exists = .true.
        else
            dir_exists = .false.
        end if

        call check(error, dir_exists, "Temp dir should exist and be writable")
        if (allocated(error)) return

    end subroutine test_temp_dir_exists

    !> Test that temp directory path has no trailing slash
    subroutine test_temp_dir_no_trailing_slash(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: temp_dir
        integer :: len_dir

        temp_dir = get_optimal_temp_dir()
        len_dir = len(temp_dir)

        ! Check that it doesn't end with '/'
        call check(error, temp_dir(len_dir:len_dir) /= '/', &
                   "Temp dir should not have trailing slash")
        if (allocated(error)) return

    end subroutine test_temp_dir_no_trailing_slash

    !> Test that get_optimal_temp_dir returns consistent results
    subroutine test_temp_dir_consistency(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: temp_dir1, temp_dir2, temp_dir3

        temp_dir1 = get_optimal_temp_dir()
        temp_dir2 = get_optimal_temp_dir()
        temp_dir3 = get_optimal_temp_dir()

        ! All three calls should return the same result
        call check(error, temp_dir1 == temp_dir2, &
                   "Temp dir should be consistent across calls")
        if (allocated(error)) return

        call check(error, temp_dir2 == temp_dir3, &
                   "Temp dir should be consistent across calls")
        if (allocated(error)) return

    end subroutine test_temp_dir_consistency

    !> Test /dev/shm preference on Linux
    subroutine test_dev_shm_check(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: temp_dir
        logical :: dev_shm_exists
        integer :: unit, ios

        ! Check if /dev/shm exists and is writable
        inquire(file='/dev/shm/.', exist=dev_shm_exists)

        if (dev_shm_exists) then
            ! Try to write to it
            open(newunit=unit, file='/dev/shm/.test_write_check', &
                 status='replace', action='write', iostat=ios)
            if (ios == 0) then
                close(unit, status='delete')

                ! If /dev/shm exists and is writable, it should be preferred
                temp_dir = get_optimal_temp_dir()
                call check(error, temp_dir == '/dev/shm', &
                           "Should prefer /dev/shm when available and writable")
                if (allocated(error)) return
            else
                ! /dev/shm exists but not writable, should fall back to /tmp
                temp_dir = get_optimal_temp_dir()
                call check(error, temp_dir == '/tmp', &
                           "Should use /tmp when /dev/shm not writable")
                if (allocated(error)) return
            end if
        else
            ! /dev/shm doesn't exist, should use /tmp
            temp_dir = get_optimal_temp_dir()
            call check(error, temp_dir == '/tmp', &
                       "Should use /tmp when /dev/shm doesn't exist")
            if (allocated(error)) return
        end if

    end subroutine test_dev_shm_check

end module test_temp_dir
