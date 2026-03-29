SHELL=/bin/sh
BENCHMARK=is
BENCHMARKU=IS

include ../config/make.def
include ../sys/make.common

.SUFFIXES:
.SUFFIXES: .f90 .f .o

OBJS = is.o ${COMMON}/print_results.o ${COMMON}/timers.o ${COMMON}/wtime.o

${PROGRAM}: config ${OBJS}
	${FLINK} ${FLINKFLAGS} -o ${PROGRAM} ${OBJS} ${F_LIB}

.f90.o:
	$(FC) $(FFLAGS) -c -o $@ $<

is.o: is.f90
	$(FC) $(FFLAGS) -cpp -DCLASS_$(CLASS) -c -o $@ is.f90

clean:
	- rm -f *.o *~ mputil*
	- rm -f is npbparams.h core