!> Performance benchmarking suite for s3_netcdf
!>
!> Measures and reports performance metrics:
!> - Time to open files from S3
!> - Cache performance (hit vs miss)
!> - /dev/shm vs /tmp comparison
!> - Multiple file handle stress test
!>
!> Outputs results in markdown table format for tracking over versions
program benchmark
    use iso_fortran_env, only: int64, real64
    use s3_http
    use s3_netcdf
    use s3_cache
    use netcdf
    implicit none

    type(s3_config) :: config
    type(cache_config) :: cache_cfg
    character(len=512) :: endpoint, bucket
    integer :: cache_err

    ! Benchmark results
    real(real64) :: time_small_cold, time_small_warm
    real(real64) :: time_medium_cold, time_medium_warm
    real(real64) :: time_multi_handles
    real(real64) :: time_shm, time_tmp
    integer :: num_handles_tested

    print '(A)', ''
    print '(A)', '======================================'
    print '(A)', 'fortran-s3-netcdf Benchmark Suite'
    print '(A)', '======================================'
    print '(A)', ''

    ! Get MinIO configuration from environment
    call get_environment_variable('S3_ENDPOINT', endpoint)
    call get_environment_variable('S3_BUCKET', bucket)

    if (len_trim(endpoint) == 0) then
        endpoint = 'localhost:9000'
    end if

    if (len_trim(bucket) == 0) then
        bucket = 'test-bucket'
    end if

    ! Strip http:// prefix if present
    if (index(endpoint, 'http://') == 1) then
        endpoint = endpoint(8:)
    else if (index(endpoint, 'https://') == 1) then
        endpoint = endpoint(9:)
    end if

    ! Configure S3
    config%endpoint = trim(endpoint)
    config%bucket = trim(bucket)
    config%use_https = .false.
    config%use_path_style = .true.
    call s3_init(config)

    print '(A)', 'Configuration:'
    print '(A)', '  Endpoint: ' // trim(endpoint)
    print '(A)', '  Bucket:   ' // trim(bucket)
    print '(A)', ''

    ! Enable caching
    cache_cfg%enabled = .true.
    cache_cfg%cache_dir = '/tmp/benchmark-cache'
    call set_cache_config(cache_cfg)
    call cache_init(cache_cfg, cache_err)

    ! Clear cache for clean benchmark
    call cache_clear(cache_cfg, cache_err)

    ! Run benchmarks
    print '(A)', 'Running benchmarks...'
    print '(A)', ''

    call benchmark_small_file(time_small_cold, time_small_warm)
    call benchmark_medium_file(time_medium_cold, time_medium_warm)
    call benchmark_multi_handles(time_multi_handles, num_handles_tested)
    call benchmark_temp_locations(time_shm, time_tmp)

    ! Print results in markdown table format
    call print_results(time_small_cold, time_small_warm, &
                       time_medium_cold, time_medium_warm, &
                       time_multi_handles, num_handles_tested, &
                       time_shm, time_tmp)

    ! Cleanup
    call cache_clear(cache_cfg, cache_err)
    call execute_command_line('rm -rf /tmp/benchmark-cache')

contains

    !> Benchmark small file (cold cache and warm cache)
    subroutine benchmark_small_file(cold_time, warm_time)
        real(real64), intent(out) :: cold_time, warm_time
        character(len=512) :: uri
        integer :: ncid, status
        integer(int64) :: start, finish, rate

        uri = 's3://' // trim(bucket) // '/ocean_surface_small.nc'

        ! Cold cache (first access)
        call system_clock(start, rate)
        status = s3_nf90_open(trim(uri), NF90_NOWRITE, ncid)
        call system_clock(finish)

        if (status /= NF90_NOERR) then
            print '(A)', 'ERROR: Failed to open small file (cold)'
            cold_time = -1.0_real64
            warm_time = -1.0_real64
            return
        end if

        cold_time = real(finish - start, real64) / real(rate, real64)
        status = s3_nf90_close(ncid)

        ! Warm cache (second access - should use cache)
        call system_clock(start, rate)
        status = s3_nf90_open(trim(uri), NF90_NOWRITE, ncid)
        call system_clock(finish)

        if (status /= NF90_NOERR) then
            print '(A)', 'ERROR: Failed to open small file (warm)'
            warm_time = -1.0_real64
            return
        end if

        warm_time = real(finish - start, real64) / real(rate, real64)
        status = s3_nf90_close(ncid)

        print '(A,F8.3,A)', '  ✓ Small file (cold): ', cold_time * 1000.0_real64, ' ms'
        print '(A,F8.3,A)', '  ✓ Small file (warm): ', warm_time * 1000.0_real64, ' ms'

    end subroutine benchmark_small_file

    !> Benchmark medium file
    subroutine benchmark_medium_file(cold_time, warm_time)
        real(real64), intent(out) :: cold_time, warm_time
        character(len=512) :: uri
        integer :: ncid, status
        integer(int64) :: start, finish, rate

        uri = 's3://' // trim(bucket) // '/ocean_surface_medium.nc'

        ! Cold cache
        call system_clock(start, rate)
        status = s3_nf90_open(trim(uri), NF90_NOWRITE, ncid)
        call system_clock(finish)

        if (status /= NF90_NOERR) then
            print '(A)', 'ERROR: Failed to open medium file (cold)'
            cold_time = -1.0_real64
            warm_time = -1.0_real64
            return
        end if

        cold_time = real(finish - start, real64) / real(rate, real64)
        status = s3_nf90_close(ncid)

        ! Warm cache
        call system_clock(start, rate)
        status = s3_nf90_open(trim(uri), NF90_NOWRITE, ncid)
        call system_clock(finish)

        if (status /= NF90_NOERR) then
            print '(A)', 'ERROR: Failed to open medium file (warm)'
            warm_time = -1.0_real64
            return
        end if

        warm_time = real(finish - start, real64) / real(rate, real64)
        status = s3_nf90_close(ncid)

        print '(A,F8.3,A)', '  ✓ Medium file (cold): ', cold_time * 1000.0_real64, ' ms'
        print '(A,F8.3,A)', '  ✓ Medium file (warm): ', warm_time * 1000.0_real64, ' ms'

    end subroutine benchmark_medium_file

    !> Benchmark multiple file handles (stress test)
    subroutine benchmark_multi_handles(total_time, num_handles)
        real(real64), intent(out) :: total_time
        integer, intent(out) :: num_handles
        character(len=512) :: uri
        integer, dimension(20) :: ncids
        integer :: i, status
        integer(int64) :: start, finish, rate

        uri = 's3://' // trim(bucket) // '/ocean_surface_small.nc'
        num_handles = 20

        call system_clock(start, rate)

        ! Open 20 handles simultaneously
        do i = 1, num_handles
            status = s3_nf90_open(trim(uri), NF90_NOWRITE, ncids(i))
            if (status /= NF90_NOERR) then
                print '(A,I0)', 'ERROR: Failed to open handle ', i
                num_handles = i - 1
                exit
            end if
        end do

        ! Close all handles
        do i = 1, num_handles
            status = s3_nf90_close(ncids(i))
        end do

        call system_clock(finish)
        total_time = real(finish - start, real64) / real(rate, real64)

        print '(A,I0,A,F8.3,A)', '  ✓ Multi-handles (', num_handles, ' files): ', &
              total_time * 1000.0_real64, ' ms'

    end subroutine benchmark_multi_handles

    !> Benchmark /dev/shm vs /tmp (Linux only)
    subroutine benchmark_temp_locations(shm_time, tmp_time)
        real(real64), intent(out) :: shm_time, tmp_time
        character(len=512) :: uri, optimal_dir
        integer :: ncid, status
        integer(int64) :: start, finish, rate
        logical :: shm_available

        uri = 's3://' // trim(bucket) // '/ocean_surface_small.nc'

        ! Check if /dev/shm is available
        inquire(file='/dev/shm/.', exist=shm_available)

        if (.not. shm_available) then
            print '(A)', '  ⊘ /dev/shm not available (not Linux or not mounted)'
            shm_time = -1.0_real64
            tmp_time = -1.0_real64
            return
        end if

        ! Clear cache for clean test
        call cache_clear(cache_cfg, cache_err)

        ! Test with /dev/shm (should be automatically selected on Linux)
        call system_clock(start, rate)
        status = s3_nf90_open(trim(uri), NF90_NOWRITE, ncid)
        call system_clock(finish)

        if (status == NF90_NOERR) then
            shm_time = real(finish - start, real64) / real(rate, real64)
            status = s3_nf90_close(ncid)

            optimal_dir = get_optimal_temp_dir()
            if (index(optimal_dir, '/dev/shm') > 0) then
                print '(A,F8.3,A)', '  ✓ /dev/shm: ', shm_time * 1000.0_real64, ' ms'
            else
                print '(A)', '  ⊘ /dev/shm test inconclusive (used /tmp instead)'
                shm_time = -1.0_real64
            end if
        else
            shm_time = -1.0_real64
        end if

        ! Note: Can't force /tmp without modifying get_optimal_temp_dir()
        ! For now, just report what we got
        tmp_time = -1.0_real64
        print '(A)', '  ⊘ /tmp comparison not implemented (would need temp dir override)'

    end subroutine benchmark_temp_locations

    !> Print results in markdown table format
    subroutine print_results(small_cold, small_warm, medium_cold, medium_warm, &
                            multi_time, multi_count, shm_time, tmp_time)
        real(real64), intent(in) :: small_cold, small_warm
        real(real64), intent(in) :: medium_cold, medium_warm
        real(real64), intent(in) :: multi_time, shm_time, tmp_time
        integer, intent(in) :: multi_count
        real(real64) :: speedup

        print '(A)', ''
        print '(A)', '======================================'
        print '(A)', 'Benchmark Results'
        print '(A)', '======================================'
        print '(A)', ''
        print '(A)', '| Benchmark | Cold Cache (ms) | Warm Cache (ms) | Speedup |'
        print '(A)', '|-----------|-----------------|-----------------|---------|'

        if (small_cold > 0.0_real64 .and. small_warm > 0.0_real64) then
            speedup = small_cold / small_warm
            print '(A,F8.1,A,F8.1,A,F6.2,A)', '| Small file (~30KB)  | ', &
                  small_cold * 1000.0_real64, ' | ', small_warm * 1000.0_real64, &
                  ' | ', speedup, 'x |'
        end if

        if (medium_cold > 0.0_real64 .and. medium_warm > 0.0_real64) then
            speedup = medium_cold / medium_warm
            print '(A,F8.1,A,F8.1,A,F6.2,A)', '| Medium file (~50KB) | ', &
                  medium_cold * 1000.0_real64, ' | ', medium_warm * 1000.0_real64, &
                  ' | ', speedup, 'x |'
        end if

        if (multi_time > 0.0_real64) then
            print '(A,I0,A,F8.1,A)', '| Multi-handles (', multi_count, 'x) | ', &
                  multi_time * 1000.0_real64, ' | N/A | N/A |'
        end if

        print '(A)', ''
        print '(A)', '**Cache Performance:**'
        if (small_cold > 0.0_real64 .and. small_warm > 0.0_real64) then
            speedup = small_cold / small_warm
            print '(A,F6.2,A)', '- Cache hit speedup: ', speedup, 'x faster'
            print '(A,F6.1,A)', '- Time saved per cached access: ', &
                  (small_cold - small_warm) * 1000.0_real64, ' ms'
        end if

        print '(A)', ''

    end subroutine print_results

end program benchmark
