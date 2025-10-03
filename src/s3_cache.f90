!> Local caching layer for S3-backed NetCDF files
!>
!> Provides XDG-compliant disk caching with ETag validation to avoid
!> redundant S3 downloads for repeated file access.
!>
!> Cache Architecture:
!>   - Location: $S3_NETCDF_CACHE_DIR or $XDG_CACHE_HOME/fortran-s3-netcdf
!>               or ~/.cache/fortran-s3-netcdf
!>   - Structure: files/ (cached NetCDF) and meta/ (metadata) subdirs
!>   - Naming: SHA256 hash of S3 URI (first 16 hex characters)
!>   - Metadata: Plain text with uri, size, cached_at, etag, etc.
!>
!> Public API:
!>   - cache_init: Initialize cache directory structure
!>   - cache_get: Check if URI is cached and valid, return local path
!>   - cache_put: Store downloaded file in cache with metadata
!>   - cache_evict: Remove old/large files based on policy
!>   - cache_clear: Remove all cached files
!>
!> Author: Paul Gierz <paul.gierz@awi.de>
!> License: MIT
module s3_cache
    use iso_fortran_env, only: int64
    implicit none
    private

    ! Public API
    public :: cache_config
    public :: cache_init
    public :: cache_get
    public :: cache_put
    public :: cache_evict
    public :: cache_clear
    public :: get_cache_dir

    !> Cache configuration type
    type :: cache_config
        logical :: enabled = .true.
        character(len=:), allocatable :: cache_dir
        integer(int64) :: max_size_bytes = 10737418240_int64  ! 10 GB default
        integer :: ttl_seconds = 604800  ! 7 days default
        logical :: validate_etag = .true.
    end type cache_config

    ! Module-level cache configuration (singleton pattern)
    type(cache_config), save :: default_config

contains

    !> Compute cache key from S3 URI
    !>
    !> Uses a simple hash function to generate a deterministic cache key
    !> from the S3 URI. For now, uses a simple character-based hash.
    !> TODO: Replace with SHA256 for production use.
    !>
    !> @param uri S3 URI
    !> @return 16-character hex string cache key
    function compute_cache_key(uri) result(cache_key)
        character(len=*), intent(in) :: uri
        character(len=16) :: cache_key
        integer :: i, hash_val
        character(len=8) :: hex_str

        ! Simple hash: sum of character codes modulo large prime
        hash_val = 0
        do i = 1, len_trim(uri)
            hash_val = mod(hash_val * 31 + ichar(uri(i:i)), 2147483647)
        end do

        ! Convert to hex string (8 hex digits from hash)
        write(hex_str, '(z8.8)') hash_val

        ! Pad to 16 characters for consistency
        cache_key = hex_str // '00000000'

    end function compute_cache_key

    !> Initialize cache directory structure
    !>
    !> Creates the cache root directory and subdirectories (files/, meta/)
    !> if they don't exist. Determines cache location from environment
    !> variables in priority order:
    !>   1. S3_NETCDF_CACHE_DIR
    !>   2. XDG_CACHE_HOME/fortran-s3-netcdf
    !>   3. ~/.cache/fortran-s3-netcdf (fallback)
    !>
    !> @param config Cache configuration (optional, uses default if not provided)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_init(config, error)
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error
        character(len=:), allocatable :: cache_root
        integer :: exit_status

        error = 0

        ! Determine cache directory
        if (present(config)) then
            if (allocated(config%cache_dir)) then
                cache_root = config%cache_dir
            else
                cache_root = get_cache_dir()
            end if
        else
            cache_root = get_cache_dir()
        end if

        ! Create main cache directory
        call execute_command_line('mkdir -p ' // cache_root, exitstat=exit_status)
        if (exit_status /= 0) then
            error = 1
            return
        end if

        ! Create files/ subdirectory
        call execute_command_line('mkdir -p ' // cache_root // '/files', exitstat=exit_status)
        if (exit_status /= 0) then
            error = 2
            return
        end if

        ! Create meta/ subdirectory
        call execute_command_line('mkdir -p ' // cache_root // '/meta', exitstat=exit_status)
        if (exit_status /= 0) then
            error = 3
            return
        end if

    end subroutine cache_init

    !> Check if S3 URI is cached and return local file path
    !>
    !> Computes cache key from URI, checks if cached file exists,
    !> optionally validates ETag if configured, and returns path
    !> to local cached file if valid.
    !>
    !> @param uri S3 URI (e.g., s3://bucket/path/file.nc)
    !> @param local_path Output: path to cached file if cache hit
    !> @param is_cached Output: .true. if cache hit, .false. if miss
    !> @param config Cache configuration (optional)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_get(uri, local_path, is_cached, config, error)
        character(len=*), intent(in) :: uri
        character(len=:), allocatable, intent(out) :: local_path
        logical, intent(out) :: is_cached
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error
        character(len=:), allocatable :: cache_root, cache_key
        logical :: file_exists
        logical :: caching_enabled

        error = 0
        is_cached = .false.

        ! Check if caching is enabled
        caching_enabled = .true.
        if (present(config)) then
            caching_enabled = config%enabled
        end if

        ! If caching disabled, always return cache miss
        if (.not. caching_enabled) then
            return
        end if

        ! Determine cache directory
        if (present(config)) then
            if (allocated(config%cache_dir)) then
                cache_root = config%cache_dir
            else
                cache_root = get_cache_dir()
            end if
        else
            cache_root = get_cache_dir()
        end if

        ! Compute cache key from URI
        cache_key = compute_cache_key(uri)

        ! Build path to cached file
        local_path = cache_root // '/files/' // cache_key

        ! Check if cached file exists
        inquire(file=local_path, exist=file_exists)

        if (file_exists) then
            is_cached = .true.
            ! TODO: Add ETag validation if config%validate_etag is true
            ! TODO: Check TTL against metadata
        else
            is_cached = .false.
        end if

    end subroutine cache_get

    !> Store downloaded file in cache with metadata
    !>
    !> Copies file to cache directory with hash-based name,
    !> writes metadata file with URI, size, ETag, timestamps, etc.
    !>
    !> @param uri S3 URI that was downloaded
    !> @param local_file Path to local file to cache
    !> @param etag ETag from S3 HEAD/GET response (optional)
    !> @param config Cache configuration (optional)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_put(uri, local_file, etag, config, error)
        use iso_fortran_env, only: int64
        character(len=*), intent(in) :: uri
        character(len=*), intent(in) :: local_file
        character(len=*), intent(in), optional :: etag
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error
        character(len=:), allocatable :: cache_root, cache_key, cached_file_path, meta_file_path
        integer :: exit_status, meta_unit, file_size_bytes
        integer(int64) :: file_size
        character(len=32) :: timestamp, size_str
        logical :: caching_enabled

        error = 0

        ! Check if caching is enabled
        caching_enabled = .true.
        if (present(config)) then
            caching_enabled = config%enabled
        end if

        ! If caching disabled, just return success (no-op)
        if (.not. caching_enabled) then
            return
        end if

        ! Determine cache directory
        if (present(config)) then
            if (allocated(config%cache_dir)) then
                cache_root = config%cache_dir
            else
                cache_root = get_cache_dir()
            end if
        else
            cache_root = get_cache_dir()
        end if

        ! Compute cache key from URI
        cache_key = compute_cache_key(uri)

        ! Build paths
        cached_file_path = cache_root // '/files/' // cache_key
        meta_file_path = cache_root // '/meta/' // cache_key // '.meta'

        ! Copy file to cache (using cp command)
        call execute_command_line('cp ' // trim(local_file) // ' ' // cached_file_path, &
                                 exitstat=exit_status)
        if (exit_status /= 0) then
            error = 1
            return
        end if

        ! Get file size
        call execute_command_line('stat -f%z ' // cached_file_path // ' > /tmp/fsize.tmp 2>/dev/null || stat -c%s ' // &
                                 cached_file_path // ' > /tmp/fsize.tmp', exitstat=exit_status)
        if (exit_status == 0) then
            open(newunit=meta_unit, file='/tmp/fsize.tmp', status='old', action='read')
            read(meta_unit, *, iostat=exit_status) file_size_bytes
            close(meta_unit, status='delete')
            file_size = int(file_size_bytes, int64)
        else
            file_size = 0_int64
        end if

        ! Get current timestamp (ISO 8601)
        call execute_command_line('date -u +"%Y-%m-%dT%H:%M:%SZ" > /tmp/ftime.tmp', exitstat=exit_status)
        if (exit_status == 0) then
            open(newunit=meta_unit, file='/tmp/ftime.tmp', status='old', action='read')
            read(meta_unit, '(a)') timestamp
            close(meta_unit, status='delete')
        else
            timestamp = '1970-01-01T00:00:00Z'
        end if

        ! Write metadata file
        open(newunit=meta_unit, file=meta_file_path, status='replace', action='write')
        write(meta_unit, '(a)') 'uri=' // trim(uri)
        write(size_str, '(i0)') file_size
        write(meta_unit, '(a)') 'size=' // trim(adjustl(size_str))
        write(meta_unit, '(a)') 'cached_at=' // trim(adjustl(timestamp))
        if (present(etag)) then
            write(meta_unit, '(a)') 'etag=' // trim(etag)
        end if
        write(meta_unit, '(a)') 'last_validated=' // trim(adjustl(timestamp))
        close(meta_unit)

    end subroutine cache_put

    !> Evict old or large cached files based on policy
    !>
    !> Removes cached files that exceed TTL or when total cache
    !> size exceeds max_size_bytes. Uses LRU policy (least recently
    !> accessed files removed first).
    !>
    !> @param config Cache configuration (optional)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_evict(config, error)
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error

        error = -1
        ! TODO: Implementation
    end subroutine cache_evict

    !> Clear all cached files and metadata
    !>
    !> Removes all files from cache directories. Useful for testing
    !> or manual cache reset.
    !>
    !> @param config Cache configuration (optional)
    !> @param error Error code: 0=success, non-zero=failure
    subroutine cache_clear(config, error)
        type(cache_config), intent(in), optional :: config
        integer, intent(out) :: error
        character(len=:), allocatable :: cache_root
        integer :: exit_status

        error = 0

        ! Determine cache directory
        if (present(config)) then
            if (allocated(config%cache_dir)) then
                cache_root = config%cache_dir
            else
                cache_root = get_cache_dir()
            end if
        else
            cache_root = get_cache_dir()
        end if

        ! Remove all files in files/ subdirectory
        call execute_command_line('rm -f ' // cache_root // '/files/*', exitstat=exit_status)
        if (exit_status /= 0) then
            error = 1
            return
        end if

        ! Remove all metadata in meta/ subdirectory
        call execute_command_line('rm -f ' // cache_root // '/meta/*', exitstat=exit_status)
        if (exit_status /= 0) then
            error = 2
            return
        end if

    end subroutine cache_clear

    !> Get cache directory path from environment
    !>
    !> Determines cache location in priority order:
    !>   1. S3_NETCDF_CACHE_DIR environment variable
    !>   2. XDG_CACHE_HOME/fortran-s3-netcdf
    !>   3. ~/.cache/fortran-s3-netcdf (fallback)
    !>
    !> @return Allocatable string with cache directory path
    function get_cache_dir() result(cache_dir)
        character(len=:), allocatable :: cache_dir
        character(len=512) :: env_value
        integer :: env_stat

        ! Priority 1: S3_NETCDF_CACHE_DIR
        call get_environment_variable('S3_NETCDF_CACHE_DIR', env_value, status=env_stat)
        if (env_stat == 0 .and. len_trim(env_value) > 0) then
            cache_dir = trim(env_value)
            return
        end if

        ! Priority 2: XDG_CACHE_HOME/fortran-s3-netcdf
        call get_environment_variable('XDG_CACHE_HOME', env_value, status=env_stat)
        if (env_stat == 0 .and. len_trim(env_value) > 0) then
            cache_dir = trim(env_value) // '/fortran-s3-netcdf'
            return
        end if

        ! Priority 3: ~/.cache/fortran-s3-netcdf (fallback)
        call get_environment_variable('HOME', env_value, status=env_stat)
        if (env_stat == 0 .and. len_trim(env_value) > 0) then
            cache_dir = trim(env_value) // '/.cache/fortran-s3-netcdf'
            return
        end if

        ! Absolute fallback (should rarely happen)
        cache_dir = '/tmp/fortran-s3-netcdf-cache'
    end function get_cache_dir

end module s3_cache
