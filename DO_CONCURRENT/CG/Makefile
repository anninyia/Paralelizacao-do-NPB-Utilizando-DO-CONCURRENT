SHELL=/bin/sh
BENCHMARK=cg
BENCHMARKU=CG
include ../config/make.def
OBJS = cg.o cg_data.o ${COMMON}/print_results.o  \
       ${COMMON}/${RAND}.o ${COMMON}/timers.o ${COMMON}/wtime.o
include ../sys/make.common
.SUFFIXES:
.SUFFIXES: .c .f .f90 .h .o
${PROGRAM}: config ${OBJS}
	${FLINK} ${FLINKFLAGS} -o ${PROGRAM} ${OBJS} ${F_LIB}
.f90.o:
	${FC} ${F_INC} ${FFLAGS} -c $
npbparams_fixed.h: npbparams.h
	sed 's/ &$$//; s/^     &/     >/' npbparams.h > npbparams_fixed.h
cg.o: cg.f90 cg_data.o npbparams_fixed.h
	${FC} ${F_INC} -c -O3 -stdpar=multicore -Mpreprocess -Mfixed cg.f90
cg_data.o: cg_data.f90 npbparams.h
	${FC} ${F_INC} ${FFLAGS} -c cg_data.f90
clean:
	- rm -f *.o *~ *.mod
	- rm -f npbparams.h npbparams_fixed.h core
	- if [ -d rii_files ]; then rm -r rii_files; fi

# Desativa regra implícita %: %.o
%: %.o
	@true
