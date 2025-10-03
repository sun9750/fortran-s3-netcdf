program test_s3_netcdf
    use iso_fortran_env, only : error_unit
    use testdrive, only : run_testsuite, new_testsuite, testsuite_type
    use test_temp_dir, only : collect_temp_dir_tests
    use test_error_codes, only : collect_error_code_tests
    use test_helpers, only : collect_helper_tests
    use test_cache, only : collect_cache_tests
    implicit none
    integer :: stat, is
    type(testsuite_type), allocatable :: testsuites(:)

    stat = 0

    testsuites = [ &
        new_testsuite("temp_dir", collect_temp_dir_tests), &
        new_testsuite("error_codes", collect_error_code_tests), &
        new_testsuite("helpers", collect_helper_tests), &
        new_testsuite("cache", collect_cache_tests) &
    ]

    do is = 1, size(testsuites)
        write(error_unit, '(a, i0, a, i0, a)') &
            'Running test suite ', is, ' of ', size(testsuites), '...'
        call run_testsuite(testsuites(is)%collect, error_unit, stat)
    end do

    if (stat > 0) then
        write(error_unit, '(i0, a)') stat, ' test(s) failed!'
        error stop 1
    end if

end program test_s3_netcdf
