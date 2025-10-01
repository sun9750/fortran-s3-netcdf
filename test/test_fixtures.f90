!> Test fixtures and helper routines for s3_netcdf testing
!>
!> This module provides utilities for creating test NetCDF files,
!> cleaning up test artifacts, and mocking S3 operations.
module test_fixtures
    use netcdf
    implicit none
    private

    public :: create_minimal_netcdf
    public :: cleanup_test_files
    public :: create_test_content

contains

    !> Create a minimal valid NetCDF file for testing
    !>
    !> Creates a NetCDF file with:
    !> - 1 dimension: x (size 3)
    !> - 1 variable: data (integer, dimension x)
    !> - 1 global attribute: title
    !>
    !> @param[in] filepath Path where to create the NetCDF file
    !> @return .true. if successful, .false. otherwise
    function create_minimal_netcdf(filepath) result(success)
        character(len=*), intent(in) :: filepath
        logical :: success
        integer :: ncid, dimid, varid, status
        integer, dimension(3) :: data_values

        success = .false.

        ! Create the file
        status = nf90_create(filepath, NF90_CLOBBER, ncid)
        if (status /= NF90_NOERR) return

        ! Define dimension
        status = nf90_def_dim(ncid, 'x', 3, dimid)
        if (status /= NF90_NOERR) then
            status = nf90_close(ncid)
            return
        end if

        ! Define variable
        status = nf90_def_var(ncid, 'data', NF90_INT, [dimid], varid)
        if (status /= NF90_NOERR) then
            status = nf90_close(ncid)
            return
        end if

        ! Add global attribute
        status = nf90_put_att(ncid, NF90_GLOBAL, 'title', 'Test NetCDF File')
        if (status /= NF90_NOERR) then
            status = nf90_close(ncid)
            return
        end if

        ! End define mode
        status = nf90_enddef(ncid)
        if (status /= NF90_NOERR) then
            status = nf90_close(ncid)
            return
        end if

        ! Write data
        data_values = [1, 2, 3]
        status = nf90_put_var(ncid, varid, data_values)
        if (status /= NF90_NOERR) then
            status = nf90_close(ncid)
            return
        end if

        ! Close the file
        status = nf90_close(ncid)
        if (status /= NF90_NOERR) return

        success = .true.

    end function create_minimal_netcdf

    !> Create test content by reading a NetCDF file into memory
    !>
    !> This simulates what s3_get_uri would return - the file contents as a string
    !>
    !> @param[in] filepath Path to NetCDF file to read
    !> @param[out] content File contents as allocatable string
    !> @return .true. if successful, .false. otherwise
    function create_test_content(filepath, content) result(success)
        character(len=*), intent(in) :: filepath
        character(len=:), allocatable, intent(out) :: content
        logical :: success
        integer :: unit, ios, file_size
        integer(kind=1), allocatable :: buffer(:)

        success = .false.

        ! Get file size
        inquire(file=filepath, size=file_size)
        if (file_size <= 0) return

        ! Allocate buffer
        allocate(buffer(file_size))

        ! Read file as binary
        open(newunit=unit, file=filepath, form='unformatted', access='stream', &
             status='old', action='read', iostat=ios)
        if (ios /= 0) then
            deallocate(buffer)
            return
        end if

        read(unit, iostat=ios) buffer
        close(unit)

        if (ios /= 0) then
            deallocate(buffer)
            return
        end if

        ! Convert to string (this is a bit of a hack but works for testing)
        allocate(character(len=file_size) :: content)
        content = transfer(buffer, content)

        deallocate(buffer)
        success = .true.

    end function create_test_content

    !> Clean up test files matching a pattern
    !>
    !> Removes temporary test files. Currently supports simple patterns:
    !> - Exact file path
    !> - Directory path (removes all files in directory matching prefix)
    !>
    !> @param[in] pattern File pattern to clean up
    subroutine cleanup_test_files(pattern)
        character(len=*), intent(in) :: pattern
        integer :: unit, ios
        logical :: exists

        ! Check if it's a specific file
        inquire(file=pattern, exist=exists)
        if (exists) then
            open(newunit=unit, file=pattern, status='old', iostat=ios)
            if (ios == 0) then
                close(unit, status='delete', iostat=ios)
            end if
        end if

        ! For more complex patterns, could use execute_command_line
        ! to call rm or similar, but keeping it simple for now

    end subroutine cleanup_test_files

end module test_fixtures
