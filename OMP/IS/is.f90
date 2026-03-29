!-------------------------------------------------------------------------!
!        N  A  S     P A R A L L E L     B E N C H M A R K S  3.3        !
!                        O P E N M P   F O R T R A N   -   I S           !
!  Usage: compile with -DCLASS_X where X is S, W, A, B or C             !
!-------------------------------------------------------------------------!

MODULE is_params_omp
  IMPLICIT NONE

#if defined(CLASS_S)
  CHARACTER, PARAMETER :: benchmark_class   = 'S'
  INTEGER,   PARAMETER :: TOTAL_KEYS_LOG_2  = 16
  INTEGER,   PARAMETER :: MAX_KEY_LOG_2     = 11
  INTEGER,   PARAMETER :: NUM_BUCKETS_LOG_2 = 9
#elif defined(CLASS_W)
  CHARACTER, PARAMETER :: benchmark_class   = 'W'
  INTEGER,   PARAMETER :: TOTAL_KEYS_LOG_2  = 20
  INTEGER,   PARAMETER :: MAX_KEY_LOG_2     = 16
  INTEGER,   PARAMETER :: NUM_BUCKETS_LOG_2 = 10
#elif defined(CLASS_A)
  CHARACTER, PARAMETER :: benchmark_class   = 'A'
  INTEGER,   PARAMETER :: TOTAL_KEYS_LOG_2  = 23
  INTEGER,   PARAMETER :: MAX_KEY_LOG_2     = 19
  INTEGER,   PARAMETER :: NUM_BUCKETS_LOG_2 = 10
#elif defined(CLASS_B)
  CHARACTER, PARAMETER :: benchmark_class   = 'B'
  INTEGER,   PARAMETER :: TOTAL_KEYS_LOG_2  = 25
  INTEGER,   PARAMETER :: MAX_KEY_LOG_2     = 21
  INTEGER,   PARAMETER :: NUM_BUCKETS_LOG_2 = 10
#elif defined(CLASS_C)
  CHARACTER, PARAMETER :: benchmark_class   = 'C'
  INTEGER,   PARAMETER :: TOTAL_KEYS_LOG_2  = 27
  INTEGER,   PARAMETER :: MAX_KEY_LOG_2     = 23
  INTEGER,   PARAMETER :: NUM_BUCKETS_LOG_2 = 10
#else
  CHARACTER, PARAMETER :: benchmark_class   = 'S'
  INTEGER,   PARAMETER :: TOTAL_KEYS_LOG_2  = 16
  INTEGER,   PARAMETER :: MAX_KEY_LOG_2     = 11
  INTEGER,   PARAMETER :: NUM_BUCKETS_LOG_2 = 9
#endif

  INTEGER, PARAMETER :: TOTAL_KEYS      = ISHFT(1, TOTAL_KEYS_LOG_2)
  INTEGER, PARAMETER :: MAX_KEY         = ISHFT(1, MAX_KEY_LOG_2)
  INTEGER, PARAMETER :: NUM_BUCKETS     = ISHFT(1, NUM_BUCKETS_LOG_2)
  INTEGER, PARAMETER :: NUM_KEYS        = TOTAL_KEYS
  INTEGER, PARAMETER :: SIZE_OF_BUFFERS = NUM_KEYS
  INTEGER, PARAMETER :: MAX_ITERATIONS  = 10
  INTEGER, PARAMETER :: TEST_ARRAY_SIZE = 5

  INTEGER, PARAMETER :: S_test_index(5) = (/ 48427,17148,23627,62548,4431 /)
  INTEGER, PARAMETER :: S_test_rank(5)  = (/ 0,18,346,64917,65463 /)
  INTEGER, PARAMETER :: W_test_index(5) = (/ 357773,934767,875723,898999,404505 /)
  INTEGER, PARAMETER :: W_test_rank(5)  = (/ 1249,11698,1039987,1043896,1048018 /)
  INTEGER, PARAMETER :: A_test_index(5) = (/ 2112377,662041,5336171,3642833,4250760 /)
  INTEGER, PARAMETER :: A_test_rank(5)  = (/ 104,17523,123928,8288932,8388264 /)
  INTEGER, PARAMETER :: B_test_index(5) = (/ 41869,812306,5102857,18232239,26860214 /)
  INTEGER, PARAMETER :: B_test_rank(5)  = (/ 33422937,10244,59149,33135281,99 /)
  INTEGER, PARAMETER :: C_test_index(5) = (/ 44172927,72999161,74326391,129606274,21736814 /)
  INTEGER, PARAMETER :: C_test_rank(5)  = (/ 61147,882988,266290,133997595,133525895 /)

END MODULE is_params_omp


MODULE is_data_omp
  USE is_params_omp
  IMPLICIT NONE

  INTEGER :: key_array(0:SIZE_OF_BUFFERS-1)
  INTEGER, TARGET :: key_buff1(0:MAX_KEY-1)
  INTEGER :: key_buff2(0:SIZE_OF_BUFFERS-1)
  INTEGER :: partial_verify_vals(0:TEST_ARRAY_SIZE-1)
  INTEGER :: bucket_size(0:NUM_BUCKETS-1)
  INTEGER :: bucket_ptrs(0:NUM_BUCKETS-1)
  INTEGER :: test_index_array(0:TEST_ARRAY_SIZE-1)
  INTEGER :: test_rank_array(0:TEST_ARRAY_SIZE-1)
  INTEGER, POINTER :: key_buff_ptr_global(:)
  INTEGER :: passed_verification

END MODULE is_data_omp


MODULE is_utils_omp
  IMPLICIT NONE
CONTAINS

  REAL(KIND=8) FUNCTION randlc(x, a)
    REAL(KIND=8), INTENT(INOUT) :: x
    REAL(KIND=8), INTENT(IN)    :: a
    REAL(KIND=8), SAVE :: r23, r46, t23, t46
    LOGICAL,      SAVE :: first = .TRUE.
    REAL(KIND=8) :: a1, a2, x1, x2, z, t1, t2, t3, t4
    INTEGER :: i
    IF (first) THEN
      r23 = 1.0d0; r46 = 1.0d0; t23 = 1.0d0; t46 = 1.0d0
      DO i = 1, 23; r23 = 0.5d0*r23; t23 = 2.0d0*t23; END DO
      DO i = 1, 46; r46 = 0.5d0*r46; t46 = 2.0d0*t46; END DO
      first = .FALSE.
    END IF
    t1 = r23*a; a1 = INT(t1); a2 = a - t23*a1
    t1 = r23*x; x1 = INT(t1); x2 = x - t23*x1
    t1 = a1*x2 + a2*x1
    t2 = INT(r23*t1); z = t1 - t23*t2
    t3 = t23*z + a2*x2
    t4 = INT(r46*t3); x = t3 - t46*t4
    randlc = r46 * x
  END FUNCTION randlc

  SUBROUTINE timer_start(t)
    REAL(KIND=8), INTENT(OUT) :: t
    CALL CPU_TIME(t)
  END SUBROUTINE

  SUBROUTINE timer_stop(t_start, elapsed)
    REAL(KIND=8), INTENT(IN)  :: t_start
    REAL(KIND=8), INTENT(OUT) :: elapsed
    REAL(KIND=8) :: t_end
    CALL CPU_TIME(t_end)
    elapsed = t_end - t_start
  END SUBROUTINE

END MODULE is_utils_omp


PROGRAM is_omp
  USE is_params_omp
  USE is_data_omp
  USE is_utils_omp
  USE OMP_LIB
  IMPLICIT NONE

  INTEGER      :: i, iteration
  REAL(KIND=8) :: t_start, timecounter, mops

  DO i = 0, TEST_ARRAY_SIZE-1
    SELECT CASE (benchmark_class)
      CASE ('S'); test_index_array(i) = S_test_index(i+1); test_rank_array(i) = S_test_rank(i+1)
      CASE ('W'); test_index_array(i) = W_test_index(i+1); test_rank_array(i) = W_test_rank(i+1)
      CASE ('A'); test_index_array(i) = A_test_index(i+1); test_rank_array(i) = A_test_rank(i+1)
      CASE ('B'); test_index_array(i) = B_test_index(i+1); test_rank_array(i) = B_test_rank(i+1)
      CASE ('C'); test_index_array(i) = C_test_index(i+1); test_rank_array(i) = C_test_rank(i+1)
    END SELECT
  END DO

  WRITE(*,*)
  WRITE(*,*) ' NAS Parallel Benchmarks - IS Benchmark (OpenMP Fortran)'
  WRITE(*,'(A,I12,A,A1,A)') '  Size: ', TOTAL_KEYS, '  (class ', benchmark_class, ')'
  WRITE(*,'(A,I4)') '  Iterations: ', MAX_ITERATIONS
  WRITE(*,'(A,I4)') '  Threads:    ', OMP_GET_MAX_THREADS()
  WRITE(*,*)

  CALL create_seq(314159265.0d0, 1220703125.0d0)
  CALL rank(1)
  passed_verification = 0
  IF (benchmark_class /= 'S') WRITE(*,*) '   iteration'
  CALL timer_start(t_start)
  DO iteration = 1, MAX_ITERATIONS
    IF (benchmark_class /= 'S') WRITE(*,'(A,I8)') '        ', iteration
    CALL rank(iteration)
  END DO
  CALL timer_stop(t_start, timecounter)
  CALL full_verify()
  IF (passed_verification /= 5*MAX_ITERATIONS + 1) passed_verification = 0
  mops = DBLE(MAX_ITERATIONS) * DBLE(TOTAL_KEYS) / timecounter / 1.0d6

  WRITE(*,*)
  WRITE(*,*) '============================================'
  WRITE(*,*) ' IS Benchmark Completed  [OpenMP]'
  WRITE(*,'(A,A1)')      '  Class           = ', benchmark_class
  WRITE(*,'(A,I12)')     '  Size (total keys)= ', TOTAL_KEYS
  WRITE(*,'(A,I4)')      '  Iterations       = ', MAX_ITERATIONS
  WRITE(*,'(A,I4)')      '  Threads          = ', OMP_GET_MAX_THREADS()
  WRITE(*,'(A,F12.4,A)') '  Time in seconds  = ', timecounter, ' s'
  WRITE(*,'(A,F12.4,A)') '  Mop/s total      = ', mops, ' Mkeys/s'
  IF (passed_verification > 0) THEN
    WRITE(*,*) '  Verification     = SUCCESSFUL'
  ELSE
    WRITE(*,*) '  Verification     = UNSUCCESSFUL'
  END IF
  WRITE(*,*) '============================================'

CONTAINS

  SUBROUTINE create_seq(seed, a)
    REAL(KIND=8), INTENT(IN) :: seed, a
    REAL(KIND=8) :: s, x
    INTEGER :: i, k
    s = seed
    k = MAX_KEY / 4
    DO i = 0, NUM_KEYS-1
      x =  randlc(s, a)
      x = x + randlc(s, a)
      x = x + randlc(s, a)
      x = x + randlc(s, a)
      key_array(i) = INT(k * x)
    END DO
  END SUBROUTINE create_seq

  SUBROUTINE rank(iteration)
    INTEGER, INTENT(IN) :: iteration
    INTEGER :: i, k, shift, key, key_rank, failed, bp
    INTEGER :: priv_bucket(0:NUM_BUCKETS-1)
    INTEGER :: priv_hist(0:MAX_KEY-1)

    shift = MAX_KEY_LOG_2 - NUM_BUCKETS_LOG_2

    key_array(iteration)                  = iteration
    key_array(iteration + MAX_ITERATIONS) = MAX_KEY - iteration

    DO i = 0, TEST_ARRAY_SIZE-1
      partial_verify_vals(i) = key_array(test_index_array(i))
    END DO

    ! Zera bucket_size
    !$OMP PARALLEL DO SCHEDULE(STATIC) DEFAULT(SHARED) PRIVATE(i)
    DO i = 0, NUM_BUCKETS-1
      bucket_size(i) = 0
    END DO
    !$OMP END PARALLEL DO

    ! Contagem com histograma privado por thread
    !$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i, priv_bucket)
      DO i = 0, NUM_BUCKETS-1
        priv_bucket(i) = 0
      END DO
      !$OMP DO SCHEDULE(STATIC)
      DO i = 0, NUM_KEYS-1
        priv_bucket(ISHFT(key_array(i), -shift)) = &
          priv_bucket(ISHFT(key_array(i), -shift)) + 1
      END DO
      !$OMP END DO
      !$OMP CRITICAL
        DO i = 0, NUM_BUCKETS-1
          bucket_size(i) = bucket_size(i) + priv_bucket(i)
        END DO
      !$OMP END CRITICAL
    !$OMP END PARALLEL

    ! Prefix sum serial
    bucket_ptrs(0) = 0
    DO i = 1, NUM_BUCKETS-1
      bucket_ptrs(i) = bucket_ptrs(i-1) + bucket_size(i-1)
    END DO

    ! Scatter serial (dependência em bucket_ptrs)
    DO i = 0, NUM_KEYS-1
      key = key_array(i)
      bp = ISHFT(key, -shift)
      key_buff2(bucket_ptrs(bp)) = key
      bucket_ptrs(bp) = bucket_ptrs(bp) + 1
    END DO

    ! Zera key_buff1
    !$OMP PARALLEL DO SCHEDULE(STATIC) DEFAULT(SHARED) PRIVATE(i)
    DO i = 0, MAX_KEY-1
      key_buff1(i) = 0
    END DO
    !$OMP END PARALLEL DO

    ! Histograma com redução privada
    !$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i, priv_hist)
      DO i = 0, MAX_KEY-1
        priv_hist(i) = 0
      END DO
      !$OMP DO SCHEDULE(STATIC)
      DO i = 0, NUM_KEYS-1
        priv_hist(key_buff2(i)) = priv_hist(key_buff2(i)) + 1
      END DO
      !$OMP END DO
      !$OMP CRITICAL
        DO i = 0, MAX_KEY-1
          key_buff1(i) = key_buff1(i) + priv_hist(i)
        END DO
      !$OMP END CRITICAL
    !$OMP END PARALLEL

    ! Prefix sum serial
    DO i = 1, MAX_KEY-1
      key_buff1(i) = key_buff1(i) + key_buff1(i-1)
    END DO

    ! Verificação parcial
    DO i = 0, TEST_ARRAY_SIZE-1
      k = partial_verify_vals(i)
      IF (k > 0 .AND. k <= NUM_KEYS-1) THEN
        key_rank = key_buff1(k-1)
        failed = 0
        SELECT CASE (benchmark_class)
          CASE ('S')
            IF (i <= 2) THEN
              IF (key_rank /= test_rank_array(i) + iteration) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(i) - iteration) failed = 1
            END IF
          CASE ('W')
            IF (i < 2) THEN
              IF (key_rank /= test_rank_array(i) + (iteration-2)) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(i) - iteration) failed = 1
            END IF
          CASE ('A')
            IF (i <= 2) THEN
              IF (key_rank /= test_rank_array(i) + (iteration-1)) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(i) - (iteration-1)) failed = 1
            END IF
          CASE ('B')
            IF (i==1 .OR. i==2 .OR. i==4) THEN
              IF (key_rank /= test_rank_array(i) + iteration) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(i) - iteration) failed = 1
            END IF
          CASE ('C')
            IF (i <= 2) THEN
              IF (key_rank /= test_rank_array(i) + iteration) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(i) - iteration) failed = 1
            END IF
        END SELECT
        IF (failed == 0) THEN
          passed_verification = passed_verification + 1
        ELSE
          WRITE(*,'(A,I3,A,I3)') '  Failed partial verification: iteration ', &
                                   iteration, ', test key ', i
        END IF
      END IF
    END DO

    IF (iteration == MAX_ITERATIONS) key_buff_ptr_global => key_buff1

  END SUBROUTINE rank

  SUBROUTINE full_verify()
    INTEGER :: i, j

    ! Scatter final serial
    DO i = 0, NUM_KEYS-1
      key_buff_ptr_global(key_buff2(i)) = key_buff_ptr_global(key_buff2(i)) - 1
      key_array(key_buff_ptr_global(key_buff2(i))) = key_buff2(i)
    END DO

    j = 0
    !$OMP PARALLEL DO REDUCTION(+:j) SCHEDULE(STATIC) DEFAULT(SHARED) PRIVATE(i)
    DO i = 1, NUM_KEYS-1
      IF (key_array(i-1) > key_array(i)) j = j + 1
    END DO
    !$OMP END PARALLEL DO

    IF (j /= 0) THEN
      WRITE(*,'(A,I10)') '  Full_verify: keys out of sort: ', j
    ELSE
      passed_verification = passed_verification + 1
    END IF

  END SUBROUTINE full_verify

END PROGRAM is_omp