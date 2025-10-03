!> Tests for S3 cache functionality
!>
!> Tests the local caching layer for S3-backed NetCDF files,
!> including cache initialization, get/put operations, and eviction.
module test_cache
    use testdrive, only : new_unittest, unittest_type, error_type, check
    use s3_cache, only : cache_config, cache_init, cache_get, cache_put, &
                         cache_evict, cache_clear, get_cache_dir
    implicit none
    private

    public :: collect_cache_tests

contains

    !> Collect all cache tests
    subroutine collect_cache_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)

        testsuite = [ &
            new_unittest("cache_init_creates_directories", test_cache_init_creates_dirs), &
            new_unittest("cache_init_respects_env_var", test_cache_init_env_var), &
            new_unittest("get_cache_dir_priority", test_get_cache_dir_priority), &
            new_unittest("cache_init_creates_subdirs", test_cache_init_subdirs), &
            new_unittest("cache_get_miss_returns_false", test_cache_get_miss), &
            new_unittest("cache_put_stores_file", test_cache_put_stores_file), &
            new_unittest("cache_get_hit_returns_true", test_cache_get_hit), &
            new_unittest("cache_clear_removes_all_files", test_cache_clear), &
            new_unittest("cache_disabled_always_misses", test_cache_disabled) &
        ]

    end subroutine collect_cache_tests

    !> Test that cache_init creates cache directory
    subroutine test_cache_init_creates_dirs(error)
        type(error_type), allocatable, intent(out) :: error
        type(cache_config) :: config
        integer :: init_error, unit, ios
        character(len=:), allocatable :: test_cache_dir

        ! Use a test-specific cache directory
        test_cache_dir = '/tmp/fortran-s3-netcdf-test-cache-init'

        ! Clean up any existing test directory
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

        ! Configure cache to use test directory
        config%cache_dir = test_cache_dir

        ! Initialize cache
        call cache_init(config, init_error)

        ! Check that init succeeded
        call check(error, init_error == 0, &
                   "cache_init should succeed (error code: " // &
                   trim(adjustl(char(init_error + 48))) // ")")
        if (allocated(error)) return

        ! Check that directory was created
        open(newunit=unit, file=trim(test_cache_dir) // '/.', &
             status='old', action='read', iostat=ios)
        if (ios == 0) close(unit)

        call check(error, ios == 0, "Cache directory should be created")
        if (allocated(error)) return

        ! Clean up
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

    end subroutine test_cache_init_creates_dirs

    !> Test that cache_init respects environment variable
    !>
    !> Note: This test verifies get_cache_dir() returns a valid path.
    !> Testing actual environment variable priority requires setting
    !> S3_NETCDF_CACHE_DIR before running the test suite (cannot be
    !> set from within Fortran).
    subroutine test_cache_init_env_var(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: detected_dir
        character(len=512) :: env_value
        integer :: env_stat

        ! Get cache dir
        detected_dir = get_cache_dir()

        ! Check that it returns a non-empty path
        call check(error, len(detected_dir) > 0, &
                   "get_cache_dir should return non-empty path")
        if (allocated(error)) return

        ! If S3_NETCDF_CACHE_DIR is set, verify it matches
        call get_environment_variable('S3_NETCDF_CACHE_DIR', env_value, status=env_stat)
        if (env_stat == 0 .and. len_trim(env_value) > 0) then
            call check(error, detected_dir == trim(env_value), &
                       "get_cache_dir should match S3_NETCDF_CACHE_DIR when set")
            if (allocated(error)) return
        else
            ! Otherwise, should contain .cache or /tmp
            call check(error, &
                       index(detected_dir, '/.cache/') > 0 .or. &
                       index(detected_dir, '/tmp/') > 0, &
                       "get_cache_dir should use XDG or /tmp fallback")
            if (allocated(error)) return
        end if

    end subroutine test_cache_init_env_var

    !> Test get_cache_dir priority order
    subroutine test_get_cache_dir_priority(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: cache_dir
        integer :: ios

        ! Clear all cache-related env vars
        call execute_command_line('unset S3_NETCDF_CACHE_DIR XDG_CACHE_HOME', exitstat=ios)

        ! Should fall back to ~/.cache/fortran-s3-netcdf
        cache_dir = get_cache_dir()

        ! Check that it contains .cache/fortran-s3-netcdf
        call check(error, index(cache_dir, '/.cache/fortran-s3-netcdf') > 0, &
                   "Should use ~/.cache/fortran-s3-netcdf as fallback")
        if (allocated(error)) return

    end subroutine test_get_cache_dir_priority

    !> Test that cache_init creates files/ and meta/ subdirectories
    subroutine test_cache_init_subdirs(error)
        type(error_type), allocatable, intent(out) :: error
        type(cache_config) :: config
        integer :: init_error, unit, ios
        character(len=:), allocatable :: test_cache_dir

        ! Use a test-specific cache directory
        test_cache_dir = '/tmp/fortran-s3-netcdf-test-subdirs'

        ! Clean up any existing test directory
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

        ! Configure cache to use test directory
        config%cache_dir = test_cache_dir

        ! Initialize cache
        call cache_init(config, init_error)

        ! Check that init succeeded
        call check(error, init_error == 0, "cache_init should succeed")
        if (allocated(error)) return

        ! Check that files/ subdirectory exists
        open(newunit=unit, file=trim(test_cache_dir) // '/files/.', &
             status='old', action='read', iostat=ios)
        if (ios == 0) close(unit)

        call check(error, ios == 0, "files/ subdirectory should exist")
        if (allocated(error)) return

        ! Check that meta/ subdirectory exists
        open(newunit=unit, file=trim(test_cache_dir) // '/meta/.', &
             status='old', action='read', iostat=ios)
        if (ios == 0) close(unit)

        call check(error, ios == 0, "meta/ subdirectory should exist")
        if (allocated(error)) return

        ! Clean up
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

    end subroutine test_cache_init_subdirs

    !> Test that cache_get returns false for cache miss
    subroutine test_cache_get_miss(error)
        type(error_type), allocatable, intent(out) :: error
        type(cache_config) :: config
        integer :: init_error, get_error, ios
        logical :: is_cached
        character(len=:), allocatable :: local_path, test_cache_dir
        character(len=*), parameter :: test_uri = 's3://test-bucket/nonexistent-file.nc'

        ! Use a test-specific cache directory
        test_cache_dir = '/tmp/fortran-s3-netcdf-test-cache-get-miss'

        ! Clean up any existing test directory
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

        ! Configure and initialize cache
        config%cache_dir = test_cache_dir
        call cache_init(config, init_error)

        call check(error, init_error == 0, "cache_init should succeed")
        if (allocated(error)) return

        ! Try to get a non-existent URI from cache
        call cache_get(test_uri, local_path, is_cached, config, get_error)

        ! Should succeed (no error)
        call check(error, get_error == 0, &
                   "cache_get should succeed even for cache miss")
        if (allocated(error)) return

        ! Should indicate cache miss
        call check(error, .not. is_cached, &
                   "cache_get should return is_cached=false for non-existent URI")
        if (allocated(error)) return

        ! Clean up
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

    end subroutine test_cache_get_miss

    !> Test that cache_put stores file and metadata
    subroutine test_cache_put_stores_file(error)
        type(error_type), allocatable, intent(out) :: error
        type(cache_config) :: config
        integer :: init_error, put_error, ios, unit
        character(len=:), allocatable :: test_cache_dir, temp_file, cache_key
        character(len=*), parameter :: test_uri = 's3://test-bucket/test-file.nc'
        character(len=*), parameter :: test_etag = '"5d41402abc4b2a76b9719d911017c592"'
        character(len=*), parameter :: test_content = 'Test NetCDF content'
        logical :: file_exists, meta_exists

        ! Use a test-specific cache directory
        test_cache_dir = '/tmp/fortran-s3-netcdf-test-cache-put'

        ! Clean up any existing test directory
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

        ! Configure and initialize cache
        config%cache_dir = test_cache_dir
        call cache_init(config, init_error)

        call check(error, init_error == 0, "cache_init should succeed")
        if (allocated(error)) return

        ! Create a temporary test file
        temp_file = '/tmp/fortran-s3-netcdf-test-source.nc'
        open(newunit=unit, file=temp_file, status='replace', action='write', iostat=ios)
        write(unit, '(a)') test_content
        close(unit)

        ! Put the file in cache
        call cache_put(test_uri, temp_file, test_etag, config, put_error)

        ! Should succeed
        call check(error, put_error == 0, "cache_put should succeed")
        if (allocated(error)) return

        ! Compute cache key to check file location
        cache_key = compute_cache_key(test_uri)

        ! Check that cached file exists
        inquire(file=trim(test_cache_dir) // '/files/' // cache_key, exist=file_exists)
        call check(error, file_exists, "Cached file should exist in files/ subdirectory")
        if (allocated(error)) return

        ! Check that metadata file exists
        inquire(file=trim(test_cache_dir) // '/meta/' // cache_key // '.meta', exist=meta_exists)
        call check(error, meta_exists, "Metadata file should exist in meta/ subdirectory")
        if (allocated(error)) return

        ! Clean up
        call execute_command_line('rm -f ' // temp_file, exitstat=ios)
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

    end subroutine test_cache_put_stores_file

    !> Test that cache_get returns true for cache hit
    subroutine test_cache_get_hit(error)
        type(error_type), allocatable, intent(out) :: error
        type(cache_config) :: config
        integer :: init_error, put_error, get_error, ios, unit
        logical :: is_cached
        character(len=:), allocatable :: local_path, test_cache_dir, temp_file
        character(len=*), parameter :: test_uri = 's3://test-bucket/cached-file.nc'
        character(len=*), parameter :: test_content = 'Cached NetCDF data'

        ! Use a test-specific cache directory
        test_cache_dir = '/tmp/fortran-s3-netcdf-test-cache-hit'

        ! Clean up any existing test directory
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

        ! Configure and initialize cache
        config%cache_dir = test_cache_dir
        call cache_init(config, init_error)

        call check(error, init_error == 0, "cache_init should succeed")
        if (allocated(error)) return

        ! Create a temporary test file
        temp_file = '/tmp/fortran-s3-netcdf-test-source-hit.nc'
        open(newunit=unit, file=temp_file, status='replace', action='write', iostat=ios)
        write(unit, '(a)') test_content
        close(unit)

        ! Put the file in cache
        call cache_put(test_uri, temp_file, config=config, error=put_error)

        call check(error, put_error == 0, "cache_put should succeed")
        if (allocated(error)) return

        ! Now try to get it from cache - should be a hit
        call cache_get(test_uri, local_path, is_cached, config, get_error)

        ! Should succeed
        call check(error, get_error == 0, "cache_get should succeed")
        if (allocated(error)) return

        ! Should indicate cache hit
        call check(error, is_cached, &
                   "cache_get should return is_cached=true for cached URI")
        if (allocated(error)) return

        ! Should return a valid path
        call check(error, allocated(local_path), &
                   "cache_get should return allocated local_path")
        if (allocated(error)) return

        call check(error, len(local_path) > 0, &
                   "cache_get should return non-empty local_path")
        if (allocated(error)) return

        ! Clean up
        call execute_command_line('rm -f ' // temp_file, exitstat=ios)
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

    end subroutine test_cache_get_hit

    !> Test that cache_clear removes all cached files
    subroutine test_cache_clear(error)
        type(error_type), allocatable, intent(out) :: error
        type(cache_config) :: config
        integer :: init_error, put_error, clear_error, ios, unit, i
        character(len=:), allocatable :: test_cache_dir, temp_file, cache_key
        character(len=64) :: test_uri
        logical :: file_exists, meta_exists

        ! Use a test-specific cache directory
        test_cache_dir = '/tmp/fortran-s3-netcdf-test-cache-clear'

        ! Clean up any existing test directory
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

        ! Configure and initialize cache
        config%cache_dir = test_cache_dir
        call cache_init(config, init_error)

        call check(error, init_error == 0, "cache_init should succeed")
        if (allocated(error)) return

        ! Create and cache multiple files
        temp_file = '/tmp/fortran-s3-netcdf-test-clear-source.nc'
        do i = 1, 3
            ! Create temp file
            open(newunit=unit, file=temp_file, status='replace', action='write')
            write(unit, '(a,i0)') 'Test content ', i
            close(unit)

            ! Cache it
            write(test_uri, '(a,i0,a)') 's3://test-bucket/file', i, '.nc'
            call cache_put(trim(test_uri), temp_file, config=config, error=put_error)

            call check(error, put_error == 0, "cache_put should succeed for all files")
            if (allocated(error)) return
        end do

        ! Clear the cache
        call cache_clear(config, clear_error)

        call check(error, clear_error == 0, "cache_clear should succeed")
        if (allocated(error)) return

        ! Verify all cached files and metadata are gone
        do i = 1, 3
            write(test_uri, '(a,i0,a)') 's3://test-bucket/file', i, '.nc'
            cache_key = compute_cache_key(trim(test_uri))

            inquire(file=trim(test_cache_dir) // '/files/' // cache_key, exist=file_exists)
            call check(error, .not. file_exists, &
                       "Cached files should be removed after cache_clear")
            if (allocated(error)) return

            inquire(file=trim(test_cache_dir) // '/meta/' // cache_key // '.meta', exist=meta_exists)
            call check(error, .not. meta_exists, &
                       "Metadata files should be removed after cache_clear")
            if (allocated(error)) return
        end do

        ! Clean up
        call execute_command_line('rm -f ' // temp_file, exitstat=ios)
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

    end subroutine test_cache_clear

    !> Test that disabled cache always returns cache miss
    subroutine test_cache_disabled(error)
        type(error_type), allocatable, intent(out) :: error
        type(cache_config) :: config
        integer :: init_error, put_error, get_error, ios, unit
        logical :: is_cached
        character(len=:), allocatable :: local_path, test_cache_dir, temp_file
        character(len=*), parameter :: test_uri = 's3://test-bucket/disabled-test.nc'

        ! Use a test-specific cache directory
        test_cache_dir = '/tmp/fortran-s3-netcdf-test-cache-disabled'

        ! Clean up any existing test directory
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

        ! Configure cache with enabled=false
        config%cache_dir = test_cache_dir
        config%enabled = .false.

        call cache_init(config, init_error)

        call check(error, init_error == 0, "cache_init should succeed even when disabled")
        if (allocated(error)) return

        ! Create a temporary test file
        temp_file = '/tmp/fortran-s3-netcdf-test-disabled.nc'
        open(newunit=unit, file=temp_file, status='replace', action='write')
        write(unit, '(a)') 'Test content'
        close(unit)

        ! Try to put file in cache (should be no-op when disabled)
        call cache_put(test_uri, temp_file, config=config, error=put_error)

        call check(error, put_error == 0, "cache_put should succeed (no-op when disabled)")
        if (allocated(error)) return

        ! Try to get from cache - should always be a miss
        call cache_get(test_uri, local_path, is_cached, config, get_error)

        call check(error, get_error == 0, "cache_get should succeed")
        if (allocated(error)) return

        call check(error, .not. is_cached, &
                   "cache_get should return miss when caching is disabled")
        if (allocated(error)) return

        ! Clean up
        call execute_command_line('rm -f ' // temp_file, exitstat=ios)
        call execute_command_line('rm -rf ' // test_cache_dir, exitstat=ios)

    end subroutine test_cache_disabled

    !> Helper function to compute cache key (duplicated for testing)
    !> TODO: Consider making this public in s3_cache module
    function compute_cache_key(uri) result(cache_key)
        character(len=*), intent(in) :: uri
        character(len=16) :: cache_key
        integer :: i, hash_val
        character(len=8) :: hex_str

        hash_val = 0
        do i = 1, len_trim(uri)
            hash_val = mod(hash_val * 31 + ichar(uri(i:i)), 2147483647)
        end do

        write(hex_str, '(z8.8)') hash_val
        cache_key = hex_str // '00000000'

    end function compute_cache_key

end module test_cache
