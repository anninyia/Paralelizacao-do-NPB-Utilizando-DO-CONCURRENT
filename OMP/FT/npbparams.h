! CLASS = C
!  
!  
!  This file is generated automatically by the setparams utility.
!  It sets the number of processors and the class of the NPB
!  in this directory. Do not modify it by hand.
!  
        integer nx, ny, nz, maxdim, niter_default
        parameter (nx=512, ny=512, nz=512, maxdim=512)
        parameter (niter_default=20)
        integer kind2
        parameter (kind2=4)
        logical  convertdouble
        parameter (convertdouble = .false.)
        character compiletime*11
        parameter (compiletime='27 Aug 2025')
        character npbversion*5
        parameter (npbversion='3.4.3')
        character cs1*6
        parameter (cs1='(none)')
        character cs2*6
        parameter (cs2='$(F77)')
        character cs3*6
        parameter (cs3='(none)')
        character cs4*6
        parameter (cs4='(none)')
        character cs5*12
        parameter (cs5='-O3 -fopenmp')
        character cs6*9
        parameter (cs6='$(FFLAGS)')
        character cs7*6
        parameter (cs7='randi8')
