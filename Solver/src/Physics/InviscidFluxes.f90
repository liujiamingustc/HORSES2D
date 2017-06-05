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
submodule (PhysicsNS)  InviscidFluxes
   use SMConstants

#include "Defines.h"

   contains

      module pure function inviscidFlux0D(u) result(val)
         implicit none
         real(kind=RP), intent(in) :: u(NCONS)
         real(kind=RP)             :: val(NCONS,NDIM)
         real(kind=RP)             :: vx , vy  , p

         associate ( Gamma => Thermodynamics % Gamma , gm1 => Thermodynamics % gm1 , Mach => Dimensionless % Mach ) 

         vx = u(IRHOU) / u(IRHO)
         vy = u(IRHOV) / u(IRHO)
         p  = gm1 * ( u(IRHOE) - 0.5_RP * u(IRHOU) * vx - 0.5_RP * u(IRHOV) * vy )
         
         val(IRHO,IX)  = u(IRHOU)
         val(IRHOU,IX) = u(IRHOU) * vx + p 
         val(IRHOV,IX) = u(IRHOU) * vy
         val(IRHOE,IX) = (u(IRHOE) + p) * vx

         val(IRHO,IY)  = u(IRHOV)
         val(IRHOU,IY) = val(IRHOV,IX)
         val(IRHOV,IY) = u(IRHOV) * vy + p
         val(IRHOE,IY) = (u(IRHOE) + p) * vy

#ifdef _DIMENSIONLESS_TAU
         val = val * dimensionless % invSqrtGammaMach
#endif

         end associate

      end function inviscidFlux0D

      module pure function inviscidFlux1D(N,u) result(val)
         implicit none
         integer, intent(in)       :: N
         real(kind=RP), intent(in) :: u(0:N,1:NCONS)
         real(kind=RP)             :: val(0:N,1:NCONS,1:NDIM)
         real(kind=RP)             :: vx(0:N) , vy(0:N)  , p(0:N)

         associate ( Gamma => Thermodynamics % Gamma , gm1 => Thermodynamics % gm1 , Mach => Dimensionless % Mach ) 
    
         vx = u(:,IRHOU) / u(:,IRHO)
         vy = u(:,IRHOV) / u(:,IRHO)
         p  = gm1 * ( u(:,IRHOE) - 0.5_RP * u(:,IRHOU) * vx - 0.5_RP * u(:,IRHOV) * vy )
         
         val(:,IRHO,IX)  = u(:,IRHOU)
         val(:,IRHOU,IX) = u(:,IRHOU) * vx + p 
         val(:,IRHOV,IX) = u(:,IRHOU) * vy
         val(:,IRHOE,IX) = (u(:,IRHOE) + p) * vx

         val(:,IRHO,IY)  = u(:,IRHOV)
         val(:,IRHOU,IY) = val(:,IRHOV,IX)
         val(:,IRHOV,IY) = u(:,IRHOV) * vy + p
         val(:,IRHOE,IY) = (u(:,IRHOE) + p) * vy

#ifdef _DIMENSIONLESS_TAU
         val = val * dimensionless % invSqrtGammaMach
#endif

         end associate

      end function inviscidFlux1D

      module pure function InviscidFlux2D(N,u) result(val)
         implicit none
         integer, intent(in)       :: N
         real(kind=RP), intent(in) :: u(0:N,0:N,1:NCONS)
         real(kind=RP)             :: val(0:N,0:N,1:NCONS,1:NDIM)
         real(kind=RP)             :: vx(0:N,0:N) , vy(0:N,0:N)  , p(0:N,0:N)

         associate ( Gamma => Thermodynamics % Gamma , gm1 => Thermodynamics % gm1 , Mach => Dimensionless % Mach ) 
    
         vx = u(:,:,IRHOU) / u(:,:,IRHO)
         vy = u(:,:,IRHOV) / u(:,:,IRHO)
         p  = gm1 * ( u(:,:,IRHOE) - 0.5_RP * u(:,:,IRHOU) * vx - 0.5_RP * u(:,:,IRHOV) * vy )
         
         val(:,:,IRHO,IX)  = u(:,:,IRHOU)
         val(:,:,IRHOU,IX) = u(:,:,IRHOU) * vx + p 
         val(:,:,IRHOV,IX) = u(:,:,IRHOU) * vy
         val(:,:,IRHOE,IX) = (u(:,:,IRHOE) + p) * vx

         val(:,:,IRHO,IY)  = u(:,:,IRHOV)
         val(:,:,IRHOU,IY) = val(:,:,IRHOV,IX)
         val(:,:,IRHOV,IY) = u(:,:,IRHOV) * vy + p
         val(:,:,IRHOE,IY) = (u(:,:,IRHOE) + p) * vy

#ifdef _DIMENSIONLESS_TAU
         val = val * dimensionless % invSqrtGammaMach
#endif

         end associate

      end function inviscidFlux2D

      module pure function F_inviscidFlux(rho,u,v,p,H) result(F)
         implicit none
         real(kind=RP), intent(in) :: rho
         real(kind=RP), intent(in) :: u
         real(kind=RP), intent(in) :: v
         real(kind=RP), intent(in) :: p
         real(kind=RP), intent(in) :: H
         real(kind=RP)             :: F(NCONS)
   
         F(IRHO)  = rho * u
         F(IRHOU) = F(IRHO) * u + p
         F(IRHOV) = F(IRHO) * v
         F(IRHOE) = H * F(IRHO)

      end function F_inviscidFlux

end submodule InviscidFluxes