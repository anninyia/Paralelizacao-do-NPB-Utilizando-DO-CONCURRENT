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
        parameter (npbversion='3.4.2')
        character cs1*46
        parameter (cs1='/home/anninyia/nvhpc_2025_257_Linux_x86_64_...')
        character cs2*5
        parameter (cs2='$(FC)')
        character cs3*6
        parameter (cs3='(none)')
        character cs4*6
        parameter (cs4='(none)')
        character cs5*21
        parameter (cs5='-O3 -stdpar=multicore')
        character cs6*9
        parameter (cs6='$(FFLAGS)')
        character cs7*6
        parameter (cs7='randi8')
