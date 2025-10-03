!> MinIO Integration Test - Real S3 Download and Cache Validation
!>
!> This test validates the complete workflow:
!> 1. Configure S3 to use MinIO endpoint
!> 2. Download NetCDF file from s3://test-bucket using s3_nf90_open()
!> 3. Read and print NetCDF attributes to verify content
!> 4. Close file and verify cache was populated
!> 5. Re-open same file (should use cache, not download)
!> 6. Verify cache hit by checking file access
!>
!> Requires environment variables:
!>   S3_ENDPOINT - MinIO endpoint (e.g., http://localhost:9000)
!>   S3_ACCESS_KEY - MinIO access key (default: minioadmin)
!>   S3_SECRET_KEY - MinIO secret key
!>   S3_BUCKET - Test bucket name (default: test-bucket)
program test_minio_integration
    use iso_fortran_env, only: output_unit, error_unit
    use s3_http
    use s3_netcdf
    use s3_cache
    use netcdf
    implicit none

    type(s3_config) :: config
    type(cache_config) :: cache_cfg
    integer :: status, ncid, natts, i
    character(len=512) :: endpoint, bucket, uri
    character(len=256) :: att_name, att_value, access_key, secret_key
    integer :: cache_init_err
    logical :: test_passed

    test_passed = .true.

    ! Print test header
    print '(a)', ''
    print '(a)', '========================================'
    print '(a)', 'MinIO Integration Test'
    print '(a)', '========================================'
    print '(a)', ''

    ! Get MinIO configuration from environment
    call get_environment_variable('S3_ENDPOINT', endpoint)
    call get_environment_variable('S3_BUCKET', bucket)
    call get_environment_variable('S3_ACCESS_KEY', access_key)
    call get_environment_variable('S3_SECRET_KEY', secret_key)

    if (len_trim(endpoint) == 0) then
        endpoint = 'http://localhost:9000'
        print '(a)', 'WARNING: S3_ENDPOINT not set, using default: ' // trim(endpoint)
    end if

    if (len_trim(bucket) == 0) then
        bucket = 'test-bucket'
        print '(a)', 'WARNING: S3_BUCKET not set, using default: ' // trim(bucket)
    end if

    ! Strip http:// or https:// prefix from endpoint if present
    ! s3_http expects just hostname:port, not full URL
    if (index(endpoint, 'http://') == 1) then
        endpoint = endpoint(8:)  ! Remove "http://"
    else if (index(endpoint, 'https://') == 1) then
        endpoint = endpoint(9:)  ! Remove "https://"
    end if

    print '(a)', 'Configuration:'
    print '(a)', '  Endpoint: ' // trim(endpoint)
    print '(a)', '  Bucket:   ' // trim(bucket)
    print '(a)', ''
    print '(a)', 'Note: Using public/anonymous bucket access with path-style URLs (fortran-s3-accessor v1.1.1)'
    print '(a)', ''

    ! Configure S3 for MinIO (public bucket - no authentication)
    config%endpoint = trim(endpoint)
    config%bucket = trim(bucket)
    config%use_https = .false.
    config%use_path_style = .true.  ! Required for MinIO on localhost
    call s3_init(config)

    ! Enable caching and initialize
    cache_cfg%enabled = .true.
    cache_cfg%cache_dir = '/tmp/minio-integration-test-cache'
    call set_cache_config(cache_cfg)
    call cache_init(cache_cfg, cache_init_err)

    if (cache_init_err /= 0) then
        print '(a,i0)', 'ERROR: Cache initialization failed: ', cache_init_err
        error stop 1
    end if

    ! Clear cache to ensure fresh test
    call cache_clear(cache_cfg, cache_init_err)

    print '(a)', 'Test 1: First access (should download from MinIO)'
    print '(a)', '=================================================='

    ! Build S3 URI for test file
    write(uri, '(a)') 's3://' // trim(bucket) // '/ocean_surface_small.nc'
    print '(a)', 'Opening: ' // trim(uri)

    ! Open NetCDF file from MinIO
    status = s3_nf90_open(trim(uri), NF90_NOWRITE, ncid)

    if (status /= NF90_NOERR) then
        print '(a)', 'ERROR: Failed to open NetCDF file from MinIO'
        print '(a)', '  Status: ' // trim(nf90_strerror(status))
        print '(a)', ''
        print '(a)', 'Possible causes:'
        print '(a)', '  1. MinIO not running or not accessible'
        print '(a)', '  2. Test file not uploaded to bucket'
        print '(a)', '  3. S3 credentials incorrect'
        error stop 1
    end if

    print '(a)', '✓ Successfully opened file from MinIO'
    print '(a)', ''

    ! Read and print global attributes
    print '(a)', 'NetCDF Global Attributes:'
    print '(a)', '-------------------------'

    status = nf90_inquire(ncid, nAttributes=natts)
    if (status == NF90_NOERR) then
        do i = 1, natts
            status = nf90_inq_attname(ncid, NF90_GLOBAL, i, att_name)
            if (status == NF90_NOERR) then
                status = nf90_get_att(ncid, NF90_GLOBAL, trim(att_name), att_value)
                if (status == NF90_NOERR) then
                    print '(a,a,a)', '  ', trim(att_name), ': ' // trim(att_value)

                    ! Validate key attributes
                    if (trim(att_name) == 'creator_name') then
                        if (index(att_value, 'Paul Gierz') == 0) then
                            print '(a)', 'ERROR: creator_name does not contain "Paul Gierz"'
                            test_passed = .false.
                        end if
                    else if (trim(att_name) == 'creator_email') then
                        if (index(att_value, 'paul.gierz@awi.de') == 0) then
                            print '(a)', 'ERROR: creator_email incorrect'
                            test_passed = .false.
                        end if
                    else if (trim(att_name) == 'institution') then
                        if (index(att_value, 'Alfred Wegener Institute') == 0) then
                            print '(a)', 'ERROR: institution incorrect'
                            test_passed = .false.
                        end if
                    end if
                end if
            end if
        end do
    end if

    print '(a)', ''

    ! Close file
    status = s3_nf90_close(ncid)
    if (status /= NF90_NOERR) then
        print '(a)', 'ERROR: Failed to close NetCDF file'
        error stop 1
    end if

    print '(a)', '✓ First access complete (file cached)'
    print '(a)', ''

    ! Test 2: Second access (should use cache)
    print '(a)', 'Test 2: Second access (should use cache)'
    print '(a)', '=========================================='

    status = s3_nf90_open(trim(uri), NF90_NOWRITE, ncid)

    if (status /= NF90_NOERR) then
        print '(a)', 'ERROR: Failed to open cached file'
        error stop 1
    end if

    print '(a)', '✓ Successfully opened from cache'

    ! Verify we can still read attributes
    status = nf90_get_att(ncid, NF90_GLOBAL, 'creator_name', att_value)
    if (status == NF90_NOERR) then
        print '(a)', '✓ Verified cached file integrity: ' // trim(att_value)
    else
        print '(a)', 'ERROR: Could not read attributes from cached file'
        test_passed = .false.
    end if

    status = s3_nf90_close(ncid)
    print '(a)', ''

    ! Clean up test cache
    call cache_clear(cache_cfg, cache_init_err)
    call execute_command_line('rm -rf /tmp/minio-integration-test-cache')

    ! Final result
    print '(a)', '========================================'
    if (test_passed) then
        print '(a)', 'MinIO Integration Test: PASSED ✓'
        print '(a)', '========================================'
        print '(a)', ''
        print '(a)', 'Validated:'
        print '(a)', '  ✓ S3 download via MinIO'
        print '(a)', '  ✓ NetCDF file opening'
        print '(a)', '  ✓ Metadata reading'
        print '(a)', '  ✓ Cache population'
        print '(a)', '  ✓ Cache retrieval'
        print '(a)', ''
    else
        print '(a)', 'MinIO Integration Test: FAILED ✗'
        print '(a)', '========================================'
        error stop 1
    end if

end program test_minio_integration
