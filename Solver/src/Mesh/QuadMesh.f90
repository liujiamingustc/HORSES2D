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
module QuadMeshClass
    use SMConstants
    use NodeClass
    use QuadElementClass
    use InitialConditions
    use Storage_module
    use DGBoundaryConditions

#include "Defines.h"
    private
    public Zone_t , QuadMesh_t , InitializeMesh

    integer, parameter        :: STR_LEN_MESH = 128
!
!//////////////////////////////////////////////////////////////////////////////////////////////////////////
!
!        QuadMesh type
!        -------------
!
    type QuadMesh_t
         integer                               :: no_of_nodes
         integer                               :: no_of_edges
         integer                               :: no_of_elements
         class(Node_t),         pointer        :: nodes(:)
         class(Edge_p),         pointer        :: edges(:)           ! This is an array to pointers
         class(QuadElement_t) , pointer        :: elements(:)
         class(Zone_t)        , pointer        :: zones(:)
         procedure(ICFcn)   , pointer , NOPASS :: IC
         real(kind=RP)                         :: Volume
         contains
             procedure  :: ConstructFromFile
             procedure  :: ConstructZones            => Mesh_ConstructZones
             procedure  :: SetInitialCondition
             procedure  :: ApplyInitialCondition
             procedure  :: SetStorage                  => QuadMesh_SetStorage
             procedure  :: VolumeIntegral              => Compute_VolumeIntegral
             procedure  :: ScalarScalarSurfaceIntegral => Compute_ScalarScalarSurfaceIntegral
             procedure  :: ScalarVectorSurfaceIntegral => Compute_ScalarVectorSurfaceIntegral
             procedure  :: VectorVectorSurfaceIntegral => Compute_VectorVectorSurfaceIntegral
             procedure  :: TensorVectorSurfaceIntegral => Compute_TensorVectorSurfaceIntegral
             procedure  :: ComputeResiduals            => Mesh_ComputeResiduals
             procedure  :: ComputeMaxJumps             => Mesh_ComputeMaxJumps
             procedure  :: FindElementWithCoords       => Mesh_FindElementWithCoords
    end type QuadMesh_t
!
!/////////////////////////////////////////////////////////////////////////////////////////////////////////////
!
!        Zone type
!        ---------
!
    type Zone_t
       integer                             :: marker
       character(len=STR_LEN_MESH)         :: Name
       integer                             :: no_of_edges
       class(Edge_p), pointer              :: edges(:)
       class(BoundaryCondition_t), pointer :: BC
       contains
          procedure      :: Construct      => Zone_Construct
          procedure      :: UpdateSolution => Zone_UpdateSolution
          procedure      :: Describe       => Zone_Describe
    end type Zone_t
 

    interface InitializeMesh
          module procedure newMesh
    end interface InitializeMesh
!
!   ========
    contains
!   ========
!
!////////////////////////////////////////////////////////////////////////////////////////////////////
!
#include "./QuadMesh_Auxiliars.incf"
#include "./QuadMesh_Construct.incf"
#include "./QuadMesh_Integrals.incf"
#include "./QuadMesh_Zones.incf"

         function newMesh()
             implicit none
             type(QuadMesh_t)    :: newMesh
!
!            Set to zero all dimensions            
!            --------------------------
             newMesh % no_of_nodes    = 0
             newMesh % no_of_edges    = 0
             newMesh % no_of_elements = 0
!
!            Point all contents to NULL
!            --------------------------
             newMesh % nodes    => NULL()
             newMesh % edges    => NULL()
             newMesh % elements => NULL() 

         end function newMesh

         subroutine constructFromFile( self , meshFile , spA , Storage , spI)
             use MeshFileClass
             use Setup_class
             use Physics
             use NodesAndWeights_Class
             implicit none
             class(QuadMesh_t),                 intent (inout)                 :: self
             class(MeshFile_t),                 intent (in   )                 :: meshFile
             class(NodalStorage),               intent (in   )                 :: spA
             class(Storage_t),                  intent (in   )                 :: storage
             class(NodesAndWeights_t), pointer, intent (in   )                 :: spI
!
!            ---------------
!            Local variables
!            ---------------
!
             integer :: node
!
!            Set dimensions
!            --------------
             self % no_of_nodes    = meshFile % no_of_nodes
             self % no_of_edges    = meshFile % no_of_edges
             self % no_of_elements = meshFile % no_of_elements
!
!            Allocate the contents
!            ---------------------
             allocate ( self % nodes    ( self % no_of_nodes    )  ) 
             allocate ( self % edges    ( self % no_of_edges    )  ) 
             allocate ( self % elements ( self % no_of_elements )  ) 
!
!            ***********************
!            Construct the contents
!            ***********************
!
!            Construct nodes
!            ---------------
             do node = 1 , self % no_of_nodes
                 call self % nodes(node) % construct( ID = node, x = meshFile % points_coords(1:NDIM,node))
             end do
!
!            Construct edges and elements
!            ----------------------------
             call constructElementsAndEdges( self , meshFile , spA, Storage , spI )
!
!            Compute the domain volume
!            -------------------------
             self % Volume = self % VolumeIntegral("One")            

         end subroutine constructFromFile

         subroutine SetInitialCondition( self , which)
             use InitialConditions
             implicit none
             class(QuadMesh_t)            :: self
             character(len=*), optional   :: which
!
!            Get Initial Condition procedure              
!            -------------------------------
             if (present(which)) then
               call getInitialCondition( self % IC , which)

             else
               call getInitialCondition( self % IC )

             end if
!
!            Apply the initial condition to the solution
!            -------------------------------------------
             call self % ApplyInitialCondition()

             call BoundaryConditions_SetInitialCondition( self % IC )

          end subroutine setInitialCondition

          subroutine ApplyInitialCondition( self )
             use Physics
             implicit none
             class(QuadMesh_t)        :: self
             integer                  :: eID
             integer                  :: iXi
             integer                  :: iEta
             real(kind=RP)            :: X(NDIM)
             real(kind=RP)            :: ICval(NCONS)

             do eID = 1 , self % no_of_elements
               do iXi = 0 , self % elements(eID) % spA % N
                  do iEta = 0 , self % elements(eID) % spA % N
                     X = self % elements(eID) % X(iXi,iEta,IX:IY)
                     ICval = self % IC(x)
                     self % elements(eID) % Q(1:NCONS,iXi,iEta)  = getDimensionlessVariables ( ICval )

                  end do
               end do
             end do

          end subroutine ApplyInitialCondition

          subroutine Mesh_ConstructZones( self , meshFile  )
            use MeshFileClass
            use Headers
            implicit none
            class(QuadMesh_t)                        :: self
            class(MeshFile_t)                        :: meshFile
            character(len=STR_LEN_MESH), allocatable :: zoneNames(:)
            integer                                  :: zone

            write(STD_OUT,'(/)') 
            call Section_header("Boundary conditions overview")
!
!           Write the zone names
!           --------------------
            allocate( zoneNames( 0 :  meshFile % no_of_markers) )
            zoneNames(0) = "Interior"
            zoneNames(1 : meshFile % no_of_markers) = meshFile % bdryzones_names
!
!           Construct the zones
!           -------------------
            allocate( self % Zones( 0 : meshFile % no_of_markers ) )
            do zone = 0 , meshFile % no_of_markers
               call self % Zones(zone) % Construct( self , zone , zoneNames(zone) )
            end do
!
!           Just periodic boundary conditions: It is neccesary to perform the linking
!           -------------------------------------------------------------------------
            do zone = 1 , meshFile % no_of_markers
               select type ( BC => self % Zones(zone) % BC ) 
                  type is (PeriodicBC_t)
                     if ( .not. BC % associated ) then
                        call Zone_LinkPeriodicZones( self % Zones(zone) , self % Zones( BC % connected_marker ) ) 

                     end if
                  class default
               end select
            end do

!
         end subroutine Mesh_ConstructZones

         subroutine Zone_construct( self , mesh , marker , name)
            implicit none
            class(Zone_t)           :: self
            class(QuadMesh_t)       :: mesh
            integer                 :: marker
            character(len=*)        :: name
            integer                 :: edID
            integer                 :: current
   
            self % marker = marker
            self % Name = trim(Name)
   
            self % no_of_edges = 0
!   
!           Gather the number of edges for a marker
!           ---------------------------------------
            do edID = 1 , mesh % no_of_edges
               if ( mesh % edges(edID) % f % edgeType .eq. marker) then
                  self % no_of_edges = self % no_of_edges + 1
               end if
            end do
!   
!           Allocate the structure
!           ----------------------
            allocate( self % edges( self % no_of_edges ) )
!   
!           Point to all edges in the zone
!           ------------------------------
            current = 0
            do edID = 1 , mesh % no_of_edges
               if ( mesh % edges(edID) % f % edgeType .eq. marker) then
                  current = current + 1
                  self % edges( current ) % f => mesh % edges(edID) % f

               end if
            end do
!
!           Create the boundary condition structure
!           ---------------------------------------
            if (marker .eq. FACE_INTERIOR) then
               self % BC => NULL()

            else
               call Construct( self % BC , marker )
   
               do edID = 1 , self % no_of_edges
                  call self % BC % Associate( self % edges(edID) % f )
               end do

            end if

            call self % Describe

         end subroutine Zone_construct

end module QuadMeshClass   
