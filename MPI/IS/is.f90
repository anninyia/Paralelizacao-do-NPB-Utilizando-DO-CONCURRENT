!-------------------------------------------------------------------------!
!        N  A  S     P A R A L L E L     B E N C H M A R K S  3.3        !
!                        M P I   F O R T R A N   -   I S                 !
!  Usage: compile with -DCLASS_X where X is S, W, A, B or C             !
!-------------------------------------------------------------------------!

MODULE is_params_mpi
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

END MODULE is_params_mpi


PROGRAM is_mpi
  USE is_params_mpi
  USE MPI
  IMPLICIT NONE

  ! Arrays 0-based igual ao C original
  INTEGER :: key_array(0:SIZE_OF_BUFFERS-1)
  INTEGER, TARGET :: key_buff1(0:MAX_KEY-1)
  INTEGER :: key_buff1_local(0:MAX_KEY-1)
  INTEGER :: key_buff2(0:SIZE_OF_BUFFERS-1)
  INTEGER :: partial_verify_vals(0:TEST_ARRAY_SIZE-1)
  INTEGER :: bucket_size(0:NUM_BUCKETS-1)
  INTEGER :: bucket_size_local(0:NUM_BUCKETS-1)
  INTEGER :: bucket_ptrs(0:NUM_BUCKETS-1)
  INTEGER :: test_index_array(0:TEST_ARRAY_SIZE-1)
  INTEGER :: test_rank_array(0:TEST_ARRAY_SIZE-1)
  INTEGER, POINTER :: key_buff_ptr_global(:)
  INTEGER :: passed_verification

  INTEGER :: my_rank, nprocs, ierr
  INTEGER :: my_keys_start, my_keys_end, my_num_keys
  INTEGER :: iteration, i, k, j_local, j_global
  REAL(KIND=8) :: t_start, t_end, timecounter, mops

  CALL MPI_Init(ierr)
  CALL MPI_Comm_rank(MPI_COMM_WORLD, my_rank, ierr)
  CALL MPI_Comm_size(MPI_COMM_WORLD, nprocs, ierr)

  ! Particionamento de chaves por processo (0-based)
  my_num_keys   = NUM_KEYS / nprocs
  my_keys_start = my_rank * my_num_keys
  my_keys_end   = my_keys_start + my_num_keys - 1
  IF (my_rank == nprocs - 1) THEN
    my_keys_end = NUM_KEYS - 1
    my_num_keys = my_keys_end - my_keys_start + 1
  END IF

  ! Inicializa arrays de verificação
  DO i = 0, TEST_ARRAY_SIZE-1
    SELECT CASE (benchmark_class)
      CASE ('S'); test_index_array(i) = S_test_index(i+1); test_rank_array(i) = S_test_rank(i+1)
      CASE ('W'); test_index_array(i) = W_test_index(i+1); test_rank_array(i) = W_test_rank(i+1)
      CASE ('A'); test_index_array(i) = A_test_index(i+1); test_rank_array(i) = A_test_rank(i+1)
      CASE ('B'); test_index_array(i) = B_test_index(i+1); test_rank_array(i) = B_test_rank(i+1)
      CASE ('C'); test_index_array(i) = C_test_index(i+1); test_rank_array(i) = C_test_rank(i+1)
    END SELECT
  END DO

  IF (my_rank == 0) THEN
    WRITE(*,*)
    WRITE(*,*) ' NAS Parallel Benchmarks - IS Benchmark (MPI Fortran)'
    WRITE(*,'(A,I12,A,A1,A)') '  Size: ', TOTAL_KEYS, '  (class ', benchmark_class, ')'
    WRITE(*,'(A,I4)') '  Iterations: ', MAX_ITERATIONS
    WRITE(*,'(A,I4)') '  Processes:  ', nprocs
    WRITE(*,*)
  END IF

  CALL create_seq(314159265.0d0, 1220703125.0d0)
  CALL rank_keys(1)

  passed_verification = 0
  IF (my_rank == 0 .AND. benchmark_class /= 'S') WRITE(*,*) '   iteration'

  CALL MPI_Barrier(MPI_COMM_WORLD, ierr)
  CALL CPU_TIME(t_start)

  DO iteration = 1, MAX_ITERATIONS
    IF (my_rank == 0 .AND. benchmark_class /= 'S') &
      WRITE(*,'(A,I8)') '        ', iteration
    CALL rank_keys(iteration)
  END DO

  CALL MPI_Barrier(MPI_COMM_WORLD, ierr)
  CALL CPU_TIME(t_end)
  timecounter = t_end - t_start
  CALL MPI_Allreduce(MPI_IN_PLACE, timecounter, 1, MPI_DOUBLE_PRECISION, &
                     MPI_MAX, MPI_COMM_WORLD, ierr)

  CALL full_verify()

  IF (my_rank == 0) THEN
    IF (passed_verification /= 5*MAX_ITERATIONS + 1) passed_verification = 0
    mops = DBLE(MAX_ITERATIONS) * DBLE(TOTAL_KEYS) / timecounter / 1.0d6
    WRITE(*,*)
    WRITE(*,*) '============================================'
    WRITE(*,*) ' IS Benchmark Completed  [MPI]'
    WRITE(*,'(A,A1)')      '  Class           = ', benchmark_class
    WRITE(*,'(A,I12)')     '  Size (total keys)= ', TOTAL_KEYS
    WRITE(*,'(A,I4)')      '  Iterations       = ', MAX_ITERATIONS
    WRITE(*,'(A,I4)')      '  Processes        = ', nprocs
    WRITE(*,'(A,F12.4,A)') '  Time in seconds  = ', timecounter, ' s'
    WRITE(*,'(A,F12.4,A)') '  Mop/s total      = ', mops, ' Mkeys/s'
    IF (passed_verification > 0) THEN
      WRITE(*,*) '  Verification     = SUCCESSFUL'
    ELSE
      WRITE(*,*) '  Verification     = UNSUCCESSFUL'
    END IF
    WRITE(*,*) '============================================'
  END IF

  CALL MPI_Finalize(ierr)

CONTAINS

  REAL(KIND=8) FUNCTION randlc(x, a)
    REAL(KIND=8), INTENT(INOUT) :: x
    REAL(KIND=8), INTENT(IN)    :: a
    REAL(KIND=8), SAVE :: r23, r46, t23, t46
    LOGICAL,      SAVE :: first = .TRUE.
    REAL(KIND=8) :: a1, a2, x1, x2, z, t1, t2, t3, t4
    INTEGER :: ii
    IF (first) THEN
      r23 = 1.0d0; r46 = 1.0d0; t23 = 1.0d0; t46 = 1.0d0
      DO ii = 1, 23; r23 = 0.5d0*r23; t23 = 2.0d0*t23; END DO
      DO ii = 1, 46; r46 = 0.5d0*r46; t46 = 2.0d0*t46; END DO
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

  ! Todos os processos geram o array completo (simples e correto)
  SUBROUTINE create_seq(seed, a)
    REAL(KIND=8), INTENT(IN) :: seed, a
    REAL(KIND=8) :: s, x
    INTEGER :: ii, kk
    s  = seed
    kk = MAX_KEY / 4
    DO ii = 0, NUM_KEYS-1
      x =  randlc(s, a)
      x = x + randlc(s, a)
      x = x + randlc(s, a)
      x = x + randlc(s, a)
      key_array(ii) = INT(kk * x)
    END DO
  END SUBROUTINE create_seq

  SUBROUTINE rank_keys(iteration)
    INTEGER, INTENT(IN) :: iteration
    INTEGER :: ii, kk, key, key_rank, failed, shift, bp

    shift = MAX_KEY_LOG_2 - NUM_BUCKETS_LOG_2

    key_array(iteration)                  = iteration
    key_array(iteration + MAX_ITERATIONS) = MAX_KEY - iteration

    DO ii = 0, TEST_ARRAY_SIZE-1
      partial_verify_vals(ii) = key_array(test_index_array(ii))
    END DO

    ! Histograma local
    DO ii = 0, NUM_BUCKETS-1
      bucket_size_local(ii) = 0
    END DO
    DO ii = my_keys_start, my_keys_end
      bucket_size_local(ISHFT(key_array(ii), -shift)) = &
        bucket_size_local(ISHFT(key_array(ii), -shift)) + 1
    END DO

    ! Redução global dos buckets
    CALL MPI_Allreduce(bucket_size_local, bucket_size, NUM_BUCKETS, &
                       MPI_INTEGER, MPI_SUM, MPI_COMM_WORLD, ierr)

    ! Prefix sum global (replicado em todos os processos)
    bucket_ptrs(0) = 0
    DO ii = 1, NUM_BUCKETS-1
      bucket_ptrs(ii) = bucket_ptrs(ii-1) + bucket_size(ii-1)
    END DO

    ! Scatter: cada processo insere suas chaves nas posições corretas
    ! Calcula offset local dentro de cada bucket
    BLOCK
      INTEGER :: local_ptrs(0:NUM_BUCKETS-1)
      INTEGER :: all_bucket_sizes(0:NUM_BUCKETS-1, 0:nprocs-1)
      INTEGER :: recv_buf(0:SIZE_OF_BUFFERS-1)
      INTEGER :: pp

      CALL MPI_Allgather(bucket_size_local, NUM_BUCKETS, MPI_INTEGER, &
                         all_bucket_sizes,  NUM_BUCKETS, MPI_INTEGER, &
                         MPI_COMM_WORLD, ierr)

      ! Offset do processo dentro de cada bucket
      DO ii = 0, NUM_BUCKETS-1
        local_ptrs(ii) = bucket_ptrs(ii)
        DO pp = 0, my_rank-1
          local_ptrs(ii) = local_ptrs(ii) + all_bucket_sizes(ii, pp)
        END DO
      END DO

      ! Inicializa key_buff2 a zero (posições não escritas ficam 0)
      DO ii = 0, SIZE_OF_BUFFERS-1
        key_buff2(ii) = 0
      END DO

      ! Scatter local
      DO ii = my_keys_start, my_keys_end
        key = key_array(ii)
        bp = ISHFT(key, -shift)
        key_buff2(local_ptrs(bp)) = key
        local_ptrs(bp) = local_ptrs(bp) + 1
      END DO

      ! Cada posição foi escrita por exatamente 1 processo → soma = valor
      CALL MPI_Allreduce(key_buff2, recv_buf, SIZE_OF_BUFFERS, &
                         MPI_INTEGER, MPI_SUM, MPI_COMM_WORLD, ierr)
      key_buff2 = recv_buf
    END BLOCK

    ! Histograma local de chaves individuais
    DO ii = 0, MAX_KEY-1
      key_buff1_local(ii) = 0
    END DO
    DO ii = my_keys_start, my_keys_end
      key_buff1_local(key_buff2(ii)) = key_buff1_local(key_buff2(ii)) + 1
    END DO

    ! Redução global
    CALL MPI_Allreduce(key_buff1_local, key_buff1, MAX_KEY, &
                       MPI_INTEGER, MPI_SUM, MPI_COMM_WORLD, ierr)

    ! Prefix sum global serial
    DO ii = 1, MAX_KEY-1
      key_buff1(ii) = key_buff1(ii) + key_buff1(ii-1)
    END DO

    ! Verificação parcial (só processo 0 conta)
    DO ii = 0, TEST_ARRAY_SIZE-1
      kk = partial_verify_vals(ii)
      IF (kk > 0 .AND. kk <= NUM_KEYS-1) THEN
        key_rank = key_buff1(kk-1)
        failed   = 0
        SELECT CASE (benchmark_class)
          CASE ('S')
            IF (ii <= 2) THEN
              IF (key_rank /= test_rank_array(ii) + iteration) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(ii) - iteration) failed = 1
            END IF
          CASE ('W')
            IF (ii < 2) THEN
              IF (key_rank /= test_rank_array(ii) + (iteration-2)) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(ii) - iteration) failed = 1
            END IF
          CASE ('A')
            IF (ii <= 2) THEN
              IF (key_rank /= test_rank_array(ii) + (iteration-1)) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(ii) - (iteration-1)) failed = 1
            END IF
          CASE ('B')
            IF (ii==1 .OR. ii==2 .OR. ii==4) THEN
              IF (key_rank /= test_rank_array(ii) + iteration) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(ii) - iteration) failed = 1
            END IF
          CASE ('C')
            IF (ii <= 2) THEN
              IF (key_rank /= test_rank_array(ii) + iteration) failed = 1
            ELSE
              IF (key_rank /= test_rank_array(ii) - iteration) failed = 1
            END IF
        END SELECT
        IF (my_rank == 0) THEN
          IF (failed == 0) THEN
            passed_verification = passed_verification + 1
          ELSE
            WRITE(*,'(A,I3,A,I3)') '  Failed partial verification: iteration ', &
                                     iteration, ', test key ', ii
          END IF
        END IF
      END IF
    END DO

    IF (iteration == MAX_ITERATIONS) key_buff_ptr_global => key_buff1

  END SUBROUTINE rank_keys

  SUBROUTINE full_verify()
    INTEGER :: ii

    ! Scatter serial
    DO ii = 0, NUM_KEYS-1
      key_buff_ptr_global(key_buff2(ii)) = key_buff_ptr_global(key_buff2(ii)) - 1
      key_array(key_buff_ptr_global(key_buff2(ii))) = key_buff2(ii)
    END DO

    ! Verificação local na fatia do processo
    j_local = 0
    DO ii = my_keys_start+1, my_keys_end
      IF (key_array(ii-1) > key_array(ii)) j_local = j_local + 1
    END DO
    ! Verifica fronteira com processo anterior
    IF (my_rank > 0) THEN
      IF (key_array(my_keys_start-1) > key_array(my_keys_start)) &
        j_local = j_local + 1
    END IF

    CALL MPI_Allreduce(j_local, j_global, 1, MPI_INTEGER, &
                       MPI_SUM, MPI_COMM_WORLD, ierr)

    IF (my_rank == 0) THEN
      IF (j_global /= 0) THEN
        WRITE(*,'(A,I10)') '  Full_verify: keys out of sort: ', j_global
      ELSE
        passed_verification = passed_verification + 1
      END IF
    END IF

  END SUBROUTINE full_verify

END PROGRAM is_mpi