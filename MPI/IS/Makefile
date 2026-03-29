SHELL=/bin/sh
BENCHMARK=is
BENCHMARKU=IS

include ../config/make.def
include ../sys/make.common

.SUFFIXES:
.SUFFIXES: .f90 .f .o

OBJS = is.o ${COMMON}/print_results.o ${COMMON}/timers.o

${PROGRAM}: config ${OBJS}
	${FLINK} ${FLINKFLAGS} -o ${PROGRAM} ${OBJS} ${F_LIB}

.f90.o:
	mpif90 $(FFLAGS) -c -o $@ $

is.o: is.f90
	mpif90 $(FFLAGS) -DCLASS_$(CLASS) -c -o $@ is.f90

clean:
	- rm -f *.o *~ mputil*
	- rm -f is npbparams.h core

# Desativa regra implícita %: %.o
%: %.o
	@true
