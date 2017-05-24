!
!///////////////////////////////////////////////////////////////////////////////////////////////////////
!
!    HORSES2D - A high-order discontinuous Galerkin spectral element solver.
!    Copyright (C) 2017  Juan Manzanero Torrico (juan.manzanero@upm.es)
!
!    This program is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    This program is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with this program.  If not, see <http://www.gnu.org/licenses/>.
!
!////////////////////////////////////////////////////////////////////////////////////////////////////////
!
module InitialConditions
   use SMConstants
   use Physics
   implicit none

#include "Defines.h"
!
!  *******
   private
   public ICFcn , getInitialCondition , InitialCondition_Describe
!  *******
!

   integer,            parameter :: STR_LEN_IC     = 128
   character(len = *), parameter :: ConstantIC     = "Uniform"
   character(len = *), parameter :: PerturbationIC = "Perturbation"
   character(len = *), parameter :: SteadyIC       = "Steady"
   character(len = *), parameter :: VortexIC       = "Vortex transport"
   character(len = *), parameter :: TaylorIC       = "Taylor vortex"
   character(len = *), parameter :: TurbulenceIC   = "Turbulence2D"
   character(len = *), parameter :: UserDefinedIC  = "User-defined"
   character(len = *), parameter :: RestartIC      = "Restart"
   character(len = *), parameter :: ChecksPolyIC   = "ChecksPolynomic"
   character(len = *), parameter :: ChecksTrigIC   = "ChecksTrigonometric"
   character(len = *), parameter :: WaveIC         = "Wave"

! 
!  ******************
   abstract interface
!  ******************
!
      function ICFcn (x , argin) result (val)
         use SMConstants
         use Physics
         implicit none
         real(kind=RP)           :: x(NDIM)
         real(kind=RP), optional :: argin
         real(kind=RP)           :: val(NCONS)
      end function ICFcn
!
!  *************
   end interface
!  *************
!
!
!  ========   
   contains
!  ========   
!

      subroutine getInitialCondition( fcn , which )
         use SMConstants
         use Setup_class
         implicit none
         procedure(ICFcn), pointer     :: fcn
         character(len=*), optional    :: which
         character(len=STR_LEN_IC)     :: ICName
         
         if (present(which)) then
            ICName = which
         else
            ICName = Setup % IC
         end if

!
!        ********************************
         select case ( trim(ICName) )
!        ********************************
!
!           =========================
            case ( trim(ConstantIC) ) 
!           =========================
!
               fcn => UniformInitialCondition
!
!           =========================
            case ( trim(PerturbationIC) ) 
!           =========================
!
               fcn => PerturbedUniformInitialCondition

!
!           ============================
            case ( trim(SteadyIC) )
!           ============================
!
               fcn => SteadyInitialCondition
!
!           ============================
            case ( trim(VortexIC) )
!           ============================
!
               fcn => InviscidVortexTransportInitialCondition
!
!           ============================
            case ( trim(UserDefinedIC) )
!           ============================
!
               fcn => UserDefinedInitialConditionDriver
!
!           ============================
            case ( trim(ChecksPolyIC) )
!           ============================
!
               fcn => ChecksPolynomicInitialCondition
!
!           ============================
            case ( trim(ChecksTrigIC) )
!           ============================
!
               fcn => ChecksTrigonometricInitialCondition

!
!           ============================
            case ( trim(TaylorIC) )
!           ============================
!
               fcn => TaylorVortexInitialCondition
!
!           ============================
            case ( trim(TurbulenceIC) )
!           ============================
!
               fcn => Turbulence2DInitialCondition
!
!           ============================
            case ( trim(WaveIC) )
!           ============================
!
               fcn => WaveInitialCondition

!
!           ============================
            case ( trim(RestartIC) )
!           ============================
!
               fcn => NULL()
!
!
!
!           ============               
            case default
!           ============               
!
               print*, 'Error: Unknown initial condition "',trim(ICName),'".'
               print*, "   Options available:"
               print*, "      * ",trim(ConstantIC)
               print*, "      * ",trim(SteadyIC)
               print*, "      * ",trim(VortexIC)
               print*, "      * ",trim(ChecksPolyIC)
               print*, "      * ",trim(ChecksTrigIC)
               print*, "      * ",trim(RestartIC) 
               print*, "      * ",trim(PerturbationIC) 
               print*, "      * ",trim(UserDefinedIC) 
               STOP "Stopped." 
!
!        **********
         end select
!        **********
!


      end subroutine getInitialCondition
            
      function UniformInitialCondition(x , argin ) result(val)
!        ***************************************************************
!           Loads an uniform initial condition from reference values
!        ***************************************************************
         use SMConstants
         use Setup_Class
         implicit none
         real(kind=RP)            :: x(NDIM)
         real(kind=RP), optional  :: argin
         real(kind=RP)            :: val(NCONS)
         real(kind=RP), parameter :: AngleOfAttack = 0.0_RP
         real(kind=RP)            :: pressure

         pressure = Setup % pressure_ref / RefValues % p

         associate ( gamma => Thermodynamics % gamma , Mach => dimensionless % Mach ) 

#ifdef _DIMENSIONLESS_TAU
         val(IRHO)  = 1.0_RP
         val(IRHOU) = sqrt(gamma) * Mach * cos ( AngleOfAttack )
         val(IRHOV) = sqrt(gamma) * Mach * sin ( AngleOfAttack )
         val(IRHOE) = Dimensionless % cv * pressure + 0.5_RP * gamma * Mach * Mach
#else
         val(IRHO)  = 1.0_RP
         val(IRHOU) = cos ( AngleOfAttack )
         val(IRHOV) = sin ( AngleOfAttack )
         val(IRHOE) = Dimensionless % cv * pressure + 0.5_RP 
#endif

         end associate

      end function UniformInitialCondition

      function UserDefinedInitialConditionDriver( x , argin ) result ( val )
         use SMConstants
         use Setup_Class
         use Physics
         implicit none
         real(kind=RP)        :: x(NDIM)
         real(kind=RP), optional :: argin
         real(kind=RP)           :: val(NCONS)
         interface
            function UserDefinedInitialCondition(x , argin , Thermodynamics_ , Setup_ , refValues_ , dimensionless_ ) result (val)
               use SMConstants
               use Setup_class
               use Physics
               implicit none
               real(kind=RP)                        :: x(NDIM)
               real(kind=RP), optional              :: argin
               class(Thermodynamics_t), intent(in)  :: thermodynamics_
               class(Setup_t),          intent(in)  :: Setup_
               class(RefValues_t),      intent(in)  :: refValues_
               class(Dimensionless_t),  intent(in)  :: dimensionless_
               real(kind=RP)                        :: val(NCONS)
            end function UserDefinedInitialCOndition
         end interface 

         val = UserDefinedInitialCondition( x , argin , Thermodynamics , Setup , refValues , dimensionless )

      end function UserDefinedInitialConditionDriver

      function PerturbedUniformInitialCondition(x , argin) result(val)
!        ***************************************************************
!           Loads an uniform initial condition from reference values
!        ***************************************************************
         use SMConstants
         implicit none
         real(kind=RP)            :: x(NDIM)
         real(kind=RP), optional  :: argin
         real(kind=RP)            :: val(NCONS)
         real(kind=RP), parameter :: AngleOfAttack = 0.0_RP
         real(kind=RP), parameter :: perturbation = 0.1_RP
         real(kind=RP)            :: per

         associate ( gamma => Thermodynamics % gamma ) 
         per = 0.0_RP
         if ( (x(IX) .gt. 0.4_RP) .and. (x(IX) .lt. 0.6_RP) ) then
            if ( (x(IY) .gt. 0.4_RP) .and. (x(IY) .lt. 0.6_RP) ) then
               per = perturbation
            end if
         end if

         val(IRHO)  = 1.0_RP
         val(IRHOU) = sqrt( gamma ) * Dimensionless % Mach * (cos ( AngleOfAttack ) + per  )
         val(IRHOV) = sqrt( gamma ) * Dimensionless % Mach * sin ( AngleOfAttack )
         val(IRHOE) = Dimensionless % cv + 0.5_RP * gamma * Dimensionless % Mach * Dimensionless % Mach
         end associate

      end function PerturbedUniformInitialCondition



      function SteadyInitialCondition(x , argin) result(val)
!        ***************************************************************
!           Loads a steady flow from the reference values
!        ***************************************************************
         use SMConstants
         use Setup_Class
         implicit none
         real(kind=RP)           :: x(NDIM)
         real(kind=RP), optional :: argin
         real(kind=RP)           :: val(NCONS)
         real(kind=RP)           :: pressure

         pressure = Setup % pressure_ref / RefValues % p

         val(IRHO) = 1.0_RP
         val(IRHOU) = 0.0_RP
         val(IRHOV) = 0.0_RP
         val(IRHOE) = Dimensionless % cv * pressure

      end function SteadyInitialCondition
         
      function InviscidVortexTransportInitialCondition(x , argin) result(val)
!        ****************************************************************
!           Loads an initial condition consistent with the Taylor Green 
!          vortex problem
!        ****************************************************************
         use SMConstants
         implicit none
         real(kind=RP)            :: x(NDIM)
         real(kind=RP), optional  :: argin
         real(kind=RP)            :: val(NCONS)
         real(kind=RP), parameter :: R = 0.1_RP                         ! This is the "vortex radius" (dimensionless)
         real(kind=RP), parameter :: Beta = 0.01_RP                      ! This is the "vortex strength"
         real(kind=RP), parameter :: XC = 0.5_RP                         ! Vortex X position (in dimensionless coordinates)
         real(kind=RP), parameter :: YC = 0.5_RP                         ! Vortex Y position (in dimensionless coordinates)
         real(kind=RP), parameter :: AngleOfAttack = 0.0_RP
         real(kind=RP)            :: r2 , rho , u , v , T

         associate ( gamma => Thermodynamics % Gamma , Mach => Dimensionless % Mach , cv => Dimensionless % cv )

         r2 = ((x(IX) - XC)*(x(IX) - XC) + (x(IY) - YC)*(x(IY) - YC)) / (R*R)
      
         u = sqrt(gamma) * Mach * (cos(AngleOfAttack) - Beta * (x(IY) - YC) / R * exp(-0.5_RP * r2))
         v = sqrt(gamma) * Mach * (sin(AngleOfAttack) + Beta * (x(IX) - XC) / R * exp(-0.5_RP * r2))
         T = 1.0_RP - gamma * Mach * Mach * beta * beta / (2.0_RP * Dimensionless % cp) * exp(-r2)
         rho = T**( Thermodynamics % invgm1 ) 

         val(IRHO)  = rho
         val(IRHOU) = rho * u
         val(IRHOV) = rho * v
         val(IRHOE) = Dimensionless % cv * (rho * T) + 0.5_RP * rho * ( u*u + v*v )

         end associate
            
      end function InviscidVortexTransportInitialCondition

      function TaylorVortexInitialCondition(x , argin) result(val)
!        ****************************************************************
!           Loads an initial condition consistent with the Taylor Green 
!          vortex problem
!        ****************************************************************
         use SMConstants
         implicit none
         real(kind=RP)           :: x(NDIM)
         real(kind=RP), optional :: argin
         real(kind=RP)           :: val(NCONS)
         real(kind=RP)           :: rho , u , v , p

         associate ( gamma => Thermodynamics % Gamma , Mach => Dimensionless % Mach , cv => Dimensionless % cv )

         rho = 1.0_RP
         u = sqrt(gamma) * Mach * sin(PI*x(1)) * cos(PI*x(2))
         v = -sqrt(gamma) * Mach *  cos(PI*x(1)) * sin(PI*x(2))
         p = 1.0_RP + 0.125_RP * gamma * Mach * Mach * (cos(2.0_RP * PI * x(1)) + cos(2.0_RP * PI * x(2)) )

         val(IRHO)  = rho
         val(IRHOU) = rho * u
         val(IRHOV) = rho * v
         val(IRHOE) = cv * p + 0.5_RP * rho * ( u*u + v*v )

         end associate
            
      end function TaylorVortexInitialCondition

      function Turbulence2DInitialCondition(x , argin) result(val)
!        ****************************************************************
!           Loads an initial condition to generate 2D Turbulence
!        ****************************************************************
         use SMConstants
         implicit none
         real(kind=RP)            :: x(NDIM)
         real(kind=RP), optional  :: argin
         real(kind=RP)            :: val(NCONS)
         real(kind=RP)            :: rho , u , v , p
         real(kind=RP), parameter :: k = 10.0_RP

         associate ( gamma => Thermodynamics % Gamma , Mach => Dimensionless % Mach , cv => Dimensionless % cv )

         rho = 1.0_RP
         u = -sqrt(gamma) * Mach * cos(2.0_RP * k * PI*x(1)) * sin(2.0_RP * k * PI*x(2))
         v = sqrt(gamma) * Mach *  sin(2.0_RP * k * PI*x(1)) * cos(2.0_RP * k * PI*x(2))
         p = 1.0_RP 

         val(IRHO)  = rho
         val(IRHOU) = rho * u
         val(IRHOV) = rho * v
         val(IRHOE) = cv * p + 0.5_RP * rho * ( u*u + v*v )

         end associate
            
      end function Turbulence2DInitialCondition

      function ChecksPolynomicInitialCondition (x , argin) result (val)
         use SMConstants
         use Physics
         implicit none
         real(kind=RP)              :: x(NDIM)
         real(kind=RP), optional    :: argin
         real(kind=RP)              :: val(NCONS)
         real(kind=RP)              :: L
         real(kind=RP)              :: rho , u , v , p

         associate ( gamma => Thermodynamics % Gamma , Mach => Dimensionless % Mach , cv => Dimensionless % cv )

         if ( present( argin) ) then      
            L = argin
      
         else     
            L = 1.0_RP

         end if

#ifdef _DIMENSIONLESS_TAU
         rho = 1.0_RP
         u = sqrt(gamma) * Mach * x(IX) / L
         v = sqrt(gamma) * Mach * x(IY) / L 
         p = 1.0_RP + gamma * Mach * Mach * ( x(IX) * x(IX)  + x(IY) * x(IY) ) / (L **2.0_RP)
#else
         rho = 1.0_RP
         u = x(IX) / L
         v = x(IY) / L 
         p = 1.0_RP + ( x(IX) * x(IX)  + x(IY) * x(IY) ) / (L **2.0_RP)
#endif

         val(IRHO)  = rho
         val(IRHOU) = rho * u
         val(IRHOV) = rho * v
         val(IRHOE) = cv * p + 0.5_RP * rho * ( u*u + v*v )

         end associate
 
         
      end function ChecksPolynomicInitialCondition

      function ChecksTrigonometricInitialCondition (x , argin) result (val)
         use SMConstants
         use Physics
         implicit none
         real(kind=RP)              :: x(NDIM)
         real(kind=RP), optional    :: argin
         real(kind=RP)              :: val(NCONS)
         real(kind=RP)        :: rho , u , v , p
         real(kind=RP)        :: L 

         associate ( gamma => Thermodynamics % Gamma , Mach => Dimensionless % Mach , cv => Dimensionless % cv )

         if ( present ( argin ) ) then
   
            L = argin
         else
   
            L = 1.0_RP
         end if

#ifdef _DIMENSIONLESS_TAU
         rho = 1.0_RP
         u = sqrt(gamma) * Mach * sin(PI*x(IX) / L ) * cos(PI*x(IY) / L)
         v = -sqrt(gamma) * Mach * cos(PI*x(IX) / L ) * sin(PI*x(IY) / L)
         p = 1.0_RP + 0.125_RP * gamma * Mach * Mach * (cos(2.0_RP * PI * x(IX) / L ) + cos(2.0_RP * PI * x(IY) / L ) )
#else
         rho = 1.0_RP
         u = sin(PI*x(IX) / L ) * cos(PI*x(IY) / L)
         v = -cos(PI*x(IX) / L ) * sin(PI*x(IY) / L)
         p = 1.0_RP + 0.125_RP * (cos(2.0_RP * PI * x(IX) / L ) + cos(2.0_RP * PI * x(IY) / L ) )
#endif

         val(IRHO)  = rho
         val(IRHOU) = rho * u
         val(IRHOV) = rho * v
         val(IRHOE) = cv * p + 0.5_RP * rho * ( u*u + v*v )

         end associate
 
         
      end function ChecksTrigonometricInitialCondition

      function WaveInitialCondition ( x , argin) result( val )
         use SMConstants
         implicit none
         real(kind=RP)              :: x(NDIM)
         real(kind=RP), optional    :: argin
         real(kind=RP)              :: val(NCONS)

         associate ( gamma => Thermodynamics % Gamma  , Mach => Dimensionless % Mach ) 
         val(IRHO) = 1.0_RP
         val(IRHOU) = sqrt(gamma) * Mach * ( 1.0_RP + 0.05_RP * sin(2.0_RP * PI * x(1) ) ) 
         val(IRHOV) = 0.0_RP
         val(IRHOE) = Dimensionless % cv + 0.5_RP * 1.0_RP * ( val(IRHOU)**2.0_RP )
         end associate
      end function WaveInitialCondition
!
!/////////////////////////////////////////////////////////////////////////////////////////////////////
!
!        DESCRIBE
!        --------
!/////////////////////////////////////////////////////////////////////////////////////////////////////
!
      subroutine InitialCondition_Describe()
         use Headers
         use Setup_class
         implicit none
   
         write(STD_OUT ,'(/)')
         call Section_header("Initial condition description")
         write(STD_OUT ,*)
         
         write(STD_OUT , '(30X,A,A25,A,A)') "-> ", "Initial condition type: " , trim(Setup % IC) , "."
   
         if ( trim(Setup % IC) .eq. "Restart" ) then
            write(STD_OUT , '(30X,A,A25,A,A)') "-> ", "Data restart from file: " , trim(Setup % restart_file) , "."
         end if

         write(STD_OUT , '(30X,A,A25,ES10.4,A)' ) "-> " , "Initial time: " , Setup % initialTime

      end subroutine InitialCondition_Describe

end module InitialConditions
