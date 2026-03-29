SHELL=/bin/sh
BENCHMARK=is
BENCHMARKU=IS

include ../config/make.def
include ../sys/make.common

OBJS = is.o ${COMMON}/print_results.o ${COMMON}/timers.o ${COMMON}/wtime.o

${PROGRAM}: config ${OBJS}
	${FLINK} ${FLINKFLAGS} -o ${PROGRAM} ${OBJS} ${F_LIB}

.f90.o:
	${FCOMPILE} $<

is.o: is.f90
	${FC} ${FFLAGS} -DCLASS_${CLASS} -c -o $@ $<

clean:
	- rm -f *.o *~ mputil*
	- rm -f is npbparams.h core
