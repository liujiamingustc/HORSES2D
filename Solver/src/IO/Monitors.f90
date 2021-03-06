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
!
!///////////////////////////////////////////////////////////////////////////////////////////////////
!
!        Monitors.f90
!
!///////////////////////////////////////////////////////////////////////////////////////////////////
!
module MonitorsClass
   use SMConstants
   use Physics
   use QuadMeshClass
   implicit none
!
#include "Defines.h"

   private
   public      Monitor_t , ConstructMonitors
!
!                                ***********************
   integer, parameter         :: BUFFER_SIZE       = 100
   integer, parameter         :: STR_LEN_MONITORS  = 128
   integer, parameter         :: MONITOR_LENGTH    = 10
   integer, parameter         :: VOLUME_UNDEFINED  = 0
   integer, parameter         :: VOLUME_INTEGRAL   = 1
!                                ***********************
!
!  **********************
!  Probe class definition
!  **********************
!
   type Residuals_t
      logical                         :: active
      real(kind=RP)                   :: values(NCONS,BUFFER_SIZE)
      character(len=STR_LEN_MONITORS) :: fileName
      contains
         procedure   :: Initialization => Residuals_Initialization
         procedure   :: Update         => Residuals_Update
         procedure   :: WriteLabel     => Residuals_WriteLabel
         procedure   :: WriteValues    => Residuals_WriteValue
         procedure   :: WriteToFile    => Residuals_WriteToFile
   end type Residuals_t
!
!  *********************************************************************
!
!  *********************************************************************
!
   type Probe_t
      logical                         :: active
      integer                         :: ID
      integer                         :: eID
      real(kind=RP)                   :: x(NDIM)
      real(kind=RP)                   :: xi, eta
      real(kind=RP)                   :: values(BUFFER_SIZE)
      real(kind=RP), allocatable      :: l_xi(:) , l_eta(:)
      character(len=STR_LEN_MONITORS) :: fileName
      character(len=STR_LEN_MONITORS) :: monitorName
      character(len=STR_LEN_MONITORS) :: variable
      contains
         procedure   :: Initialization => Probe_Initialization
         procedure   :: Update         => Probe_Update
         procedure   :: WriteLabel     => Probe_WriteLabel
         procedure   :: WriteValues    => Probe_WriteValue
         procedure   :: WriteToFile    => Probe_WriteToFile
   end type Probe_t
!
!  ********************************
!  Surface monitor class definition
!  ********************************
!
   type SurfaceMonitor_t
      logical                         :: active
      logical                         :: isDimensionless
      integer                         :: ID
      integer, allocatable            :: direction
      integer                         :: marker
      real(kind=RP), allocatable      :: referenceSurface
      real(kind=RP)                   :: values(BUFFER_SIZE)
      real(kind=RP)                   :: dynamicPressure
      character(len=STR_LEN_MONITORS) :: monitorName
      character(len=STR_LEN_MONITORS) :: fileName
      character(len=STR_LEN_MONITORS) :: variable
      contains
         procedure   :: Initialization => SurfaceMonitor_Initialization
         procedure   :: Update         => SurfaceMonitor_Update
         procedure   :: WriteLabel     => SurfaceMonitor_WriteLabel
         procedure   :: WriteValues    => SurfaceMonitor_WriteValue
         procedure   :: WriteToFile    => SurfaceMonitor_WriteToFile
   end type SurfaceMonitor_t
!
!  *******************************
!  Volume monitor class definition
!  *******************************
!
   type VolumeMonitor_t
      logical                         :: active
      integer                         :: volumeType
      integer                         :: ID
      real(kind=RP)                   :: values(BUFFER_SIZE)
      character(len=STR_LEN_MONITORS) :: monitorName
      character(len=STR_LEN_MONITORS) :: fileName
      character(len=STR_LEN_MONITORS) :: variable
      real(kind=RP)                   :: referenceValue
      contains
         procedure   :: Initialization => VolumeMonitor_Initialization
         procedure   :: Update         => VolumeMonitor_Update
         procedure   :: WriteLabel     => VolumeMonitor_WriteLabel
         procedure   :: WriteValues    => VolumeMonitor_WriteValue
         procedure   :: WriteToFile    => VolumeMonitor_WriteToFile
   end type VolumeMonitor_t
!
!
!  *****************************
!  Main monitor class definition
!  *****************************
!  
   type Monitor_t
      integer                                  :: no_of_probes
      integer                                  :: no_of_surfaceMonitors
      integer                                  :: no_of_volumeMonitors
      integer                                  :: bufferLine
      integer                                  :: iter( BUFFER_SIZE )
      real(kind=RP)                            :: t   ( BUFFER_SIZE )
      type  ( Residuals_t      )               :: residuals
      class ( Probe_t          ) , allocatable :: probes          ( : )
      class ( SurfaceMonitor_t ) , allocatable :: surfaceMonitors ( : )
      class ( VolumeMonitor_t  ) , allocatable :: volumeMonitors  ( : )
      contains
         procedure   :: WriteLabel      => Monitor_WriteLabel
         procedure   :: WriteUnderlines => Monitor_WriteUnderlines
         procedure   :: WriteValues     => Monitor_WriteValues
         procedure   :: UpdateValues    => Monitor_UpdateValues
         procedure   :: WriteToFile     => Monitor_WriteToFile
   end type Monitor_t
!
!  ========
   contains
!  ========
!
!///////////////////////////////////////////////////////////////////////////////////////
!
      function ConstructMonitors( mesh ) result(Monitors)
         use Setup_Class
         use ParamfileIO
         implicit none
         type(Monitor_t)         :: Monitors
         class(QuadMesh_t)       :: mesh
!        -------------------------------------------------
         integer                         :: fID , io
         integer                         :: i
         character(len=STR_LEN_MONITORS) :: line
!
!        Search in case file for probes, surface monitors, and volume monitors
!        ---------------------------------------------------------------------
         Monitors % no_of_probes          = 0
         Monitors % no_of_surfaceMonitors = 0
         Monitors % no_of_volumeMonitors  = 0
!
!        Open case file
!        --------------
         open ( newunit = fID , file = trim(Setup % case_file) , status = "old" , action = "read" )

!
!        Read the whole file to find monitors
!        ------------------------------------
readloop:do 
            read ( fID , '(A)' , iostat = io ) line

            if ( io .lt. 0 ) then
!
!              End of file
!              -----------
               line = ""
               exit readloop

            elseif ( io .gt. 0 ) then
!
!              Error
!              -----
               errorMessage(STD_OUT)
               stop "Stopped."

            else
!
!              Succeeded
!              ---------
               line = getSquashedLine( line )

               if ( index ( line , '#defineprobe' ) .gt. 0 ) then
                  Monitors % no_of_probes = Monitors % no_of_probes + 1

               elseif ( index ( line , '#definesurfacemonitor' ) .gt. 0 ) then
                  Monitors % no_of_surfaceMonitors = Monitors % no_of_surfaceMonitors + 1

               elseif ( index ( line , '#definevolumemonitor' ) .gt. 0 ) then
                  Monitors % no_of_volumeMonitors = Monitors % no_of_volumeMonitors + 1

               end if
               
            end if

         end do readloop
!
!        Close case file
!        ---------------
         close ( fID )
!
!        Allocate monitors
!        -----------------
         allocate ( Monitors % probes          ( Monitors % no_of_probes          )  ) 
         allocate ( Monitors % surfaceMonitors ( Monitors % no_of_surfaceMonitors )  ) 
         allocate ( Monitors % volumeMonitors  ( Monitors % no_of_volumeMonitors  )  ) 
!
!        Initialize
!        ----------
         call Monitors % residuals % Initialization

         do i = 1 , Monitors % no_of_probes
            call Monitors % probes(i) % Initialization(mesh , i)
         end do

         do i = 1 , Monitors % no_of_surfaceMonitors
            call Monitors % surfaceMonitors(i) % Initialization ( mesh , i )
         end do

         do i = 1 , Monitors % no_of_volumeMonitors
            call Monitors % volumeMonitors(i) % Initialization( mesh , i )
         end do

         Monitors % bufferLine = 0

      end function ConstructMonitors

      subroutine Monitor_WriteLabel ( self )
!
!        ***************************************************
!           This subroutine prints the labels for the time
!         integrator Display procedure.
!        ***************************************************
!
         implicit none
         class(Monitor_t)              :: self
         integer                       :: i 
!
!        Write "Iteration" and "Time"
!        ----------------------------
         write ( STD_OUT , ' ( A10    ) ' , advance = "no" ) "Iteration"
         write ( STD_OUT , ' ( 3X,A10 ) ' , advance = "no" ) "Time"
!
!        Write residuals labels
!        ----------------------
         call self % residuals % WriteLabel
!
!        Write probe labels
!        ------------------
         do i = 1 , self % no_of_probes
            call self % probes(i) % WriteLabel
         end do
!
!        Write surface monitors labels
!        -----------------------------
         do i = 1 , self % no_of_surfaceMonitors
            call self % surfaceMonitors(i) % WriteLabel
         end do

         do i = 1 , self % no_of_volumeMonitors
            call self % volumeMonitors(i) % WriteLabel
         end do
         
         write(STD_OUT , *) 

      end subroutine Monitor_WriteLabel

      subroutine Monitor_WriteUnderlines( self ) 
!
!        ********************************************************
!              This subroutine displays the underlines for the
!           time integrator Display procedure.
!        ********************************************************
!
         implicit none
         class(Monitor_t)                         :: self
!        -----------------------------------------------------------
         integer                                  :: i
         character(len=MONITOR_LENGTH), parameter :: dashes = "----------"
!
!        Print dashes for "Iteration" and "Time"
!        ---------------------------------------
         write ( STD_OUT , ' ( A10    ) ' , advance = "no" ) trim ( dashes ) 
         write ( STD_OUT , ' ( 3X,A10 ) ' , advance = "no" ) trim ( dashes ) 
!
!        Print dashes for residuals
!        --------------------------
         do i = 1 , NCONS
            write(STD_OUT , '(3X,A10)' , advance = "no" ) trim(dashes)
         end do
!
!        Print dashes for probes
!        -----------------------
         do i = 1 , self % no_of_probes
            if ( self % probes(i) % active ) then
               write(STD_OUT , '(3X,A10)' , advance = "no" ) dashes(1 : min(10 , len_trim( self % probes(i) % monitorName ) + 2 ) )
            end if
         end do
!
!        Print dashes for surface monitors
!        ---------------------------------
         do i = 1 , self % no_of_surfaceMonitors
            write(STD_OUT , '(3X,A10)' , advance = "no" ) dashes(1 : min(10 , len_trim( self % surfaceMonitors(i) % monitorName ) + 2 ) )
         end do
!
!        Print dashes for volume monitors
!        --------------------------------
         do i = 1 , self % no_of_volumeMonitors
            write(STD_OUT , '(3X,A10)' , advance = "no" ) dashes(1 : min(10 , len_trim( self % volumeMonitors(i) % monitorName ) + 2 ) )
         end do

         write(STD_OUT , *) 

      end subroutine Monitor_WriteUnderlines

      subroutine Monitor_WriteValues ( self )
!
!        *******************************************************
!              This subroutine prints the values for the time
!           integrator Display procedure.
!        *******************************************************
!
         implicit none
         class(Monitor_t)           :: self
         integer                    :: i
!
!        Print iteration and time
!        ------------------------
         write ( STD_OUT , ' ( I10            ) ' , advance = "no" ) self % iter    ( self % bufferLine ) 
         write ( STD_OUT , ' ( 1X,A,1X,ES10.3 ) ' , advance = "no" ) "|" , self % t ( self % bufferLine ) 
!
!        Print residuals
!        ---------------
         call self % residuals % WriteValues( self % bufferLine )
!
!        Print probes
!        ------------
         do i = 1 , self % no_of_probes
            call self % probes(i) % WriteValues ( self % bufferLine )
         end do
!
!        Print surface monitors
!        ----------------------
         do i = 1 , self % no_of_surfaceMonitors
            call self % surfaceMonitors(i) % WriteValues ( self % bufferLine )
         end do
!
!        Print volume monitors
!        ---------------------
         do i = 1 , self % no_of_volumeMonitors
            call self % volumeMonitors(i) % WriteValues ( self % bufferLine )
         end do


         write(STD_OUT , *) 

      end subroutine Monitor_WriteValues

      subroutine Monitor_UpdateValues ( self , mesh , t , iter )
!
!        ***************************************************************
!              This subroutine updates the values for the residuals,
!           for the probes, surface and volume monitors.
!        ***************************************************************
!        
         implicit none
         class(Monitor_t)              :: self
         class(QuadMesh_t)             :: mesh
         real(kind=RP)                 :: t
         integer                       :: iter
!        -------------------------------------------------
         real(kind=RP)                 :: max_residuals(NCONS)
         integer                       :: i 
!
!        Move to next buffer line
!        ------------------------
         self % bufferLine = self % bufferLine + 1
!
!        Save time and iteration
!        -----------------------
         self % t    ( self % bufferLine )  = t
         self % iter ( self % bufferLine )  = iter
!
!        Compute current residuals
!        -------------------------
         max_residuals = mesh % ComputeResiduals()
         call self % residuals % Update( max_residuals , self % bufferLine )
!
!        Update probes
!        -------------
         do i = 1 , self % no_of_probes
            call self % probes(i) % Update( mesh , self % bufferLine )
         end do
!
!        Update surface monitors
!        -----------------------
         do i = 1 , self % no_of_surfaceMonitors
            call self % surfaceMonitors(i) % Update( mesh , self % bufferLine )
         end do
!
!        Update volume monitors
!        ----------------------
         do i = 1 , self % no_of_volumeMonitors
            call self % volumeMonitors(i) % Update( mesh , self % bufferLine )
         end do

      end subroutine Monitor_UpdateValues

      subroutine Monitor_WriteToFile ( self , force) 
!
!        ******************************************************************
!              This routine has a double behaviour:
!           force = .true.  -> Writes to file and resets buffers
!           force = .false. -> Just writes to file if the buffer is full
!        ******************************************************************
!
         implicit none
         class(Monitor_t)        :: self
         logical, optional       :: force
!        ------------------------------------------------
         integer                 :: i 
         logical                 :: forceVal

         if ( present ( force ) ) then
            forceVal = force

         else
            forceVal = .false.

         end if

         if ( forceVal ) then 
!
!           In this case the monitors are exported to their files and the buffer is reseted
!           -------------------------------------------------------------------------------
            call self % residuals % WriteToFile ( self % iter , self % t , self % bufferLine )

            do i = 1 , self % no_of_probes
               call self % probes(i) % WriteToFile ( self % iter , self % t , self % bufferLine )
            end do

            do i = 1 , self % no_of_surfaceMonitors
               call self % surfaceMonitors(i) % WriteToFile ( self % iter , self % t , self % bufferLine )
            end do

            do i = 1 , self % no_of_volumeMonitors
               call self % volumeMonitors(i) % WriteToFile ( self % iter , self % t , self % bufferLine )
            end do
!
!           Reset buffer
!           ------------
            self % bufferLine = 0

         else
!
!           The monitors are exported just if the buffer is full
!           ----------------------------------------------------
            if ( self % bufferLine .eq. BUFFER_SIZE ) then

               call self % residuals % WriteToFile ( self % iter , self % t , BUFFER_SIZE )

               do i = 1 , self % no_of_probes
                  call self % probes(i) % WriteToFile ( self % iter , self % t , BUFFER_SIZE ) 
               end do

               do i = 1 , self % no_of_surfaceMonitors
                  call self % surfaceMonitors(i) % WriteToFile ( self % iter , self % t , self % bufferLine )
               end do

               do i = 1 , self % no_of_volumeMonitors
                  call self % volumeMonitors(i) % WriteToFile ( self % iter , self % t , self % bufferLine )
               end do

               self % bufferLine = 0
   
            end if
         end if

      end subroutine Monitor_WriteToFile
!
!//////////////////////////////////////////////////////////////////////////////////////////////////
!
!           RESIDUALS ROUTINES
!           ------------------
!//////////////////////////////////////////////////////////////////////////////////////////////////
!
      subroutine Residuals_Initialization( self ) 
!
!        *******************************************************************
!              This subroutine initializes the residuals structure
!        *******************************************************************
!
         use ParamfileIO
         use Setup_Class
         use MatrixOperations
         implicit none
         class(Residuals_t)      :: self
!        ----------------------------------------------
         character(len=STR_LEN_MONITORS)  :: fileName
         integer                          :: fID
         integer                          :: pos
!
!        Enable the monitor
!        ------------------
         self % active = .true.
!
!        Get monitor file name
!        ---------------------
         fileName = trim (Setup % solution_file      )
         pos      = index(trim(fileName) , '.HiORst' )
         write( self % fileName , '(A,A,A,A)') fileName(1:pos-1) , ".residuals"  
!
!        Create file to write the residuals
!        ----------------------------------
         open ( newunit = fID , file = trim(self % fileName) , status = "unknown" , action = "write" ) 
         write ( fID , ' ( A                                      ) ' ) "Residuals file"
         write ( fID , ' ( A10,2X,A24,2X,A24,2X,A24,2X,A24,2X,A24 ) ' ) "Iteration" , "Time" , "continuity" , "x-momentum" , "y-momentum" , "energy"
!
!        Close file
!        ----------
         close ( fID ) 
              
      end subroutine Residuals_Initialization

      subroutine Residuals_Update ( self , max_residuals , bufferPosition )
!
!        *********************************************************
!              This subroutine updates the residuals values from
!           those computed in the Monitor procedure
!        *********************************************************
!
         use MatrixOperations
         implicit none
         class(Residuals_t)        :: self
         real(kind=RP), intent(in) :: max_residuals(NCONS)
         integer                   :: bufferPosition
!
!        Update buffer values
!        --------------------      
         self % values( 1:NCONS , bufferPosition ) = max_residuals

      end subroutine Residuals_Update

      subroutine Residuals_WriteLabel ( self )
!
!        ************************************************************
!              This subroutine displays the residuals labels for the
!           time integrator Display procedure.
!        ************************************************************
!
         implicit none
         class(Residuals_t)             :: self

         write(STD_OUT , '(3X,A10)' , advance = "no") "continuity"
         write(STD_OUT , '(3X,A10)' , advance = "no") "x-momentum"
         write(STD_OUT , '(3X,A10)' , advance = "no") "y-momentum"
         write(STD_OUT , '(3X,A10)' , advance = "no") "energy"

      end subroutine Residuals_WriteLabel
   
      subroutine Residuals_WriteValue ( self , bufferLine ) 
!
!        ***************************************************************
!              This subroutine displays the residuals values for the 
!           time integrator Display procedure
!        ***************************************************************
!
         implicit none
         class(Residuals_t) :: self
         integer            :: bufferLine
!        ---------------------------------------------------------
         integer            :: eq
      
         do eq = 1 , NCONS
            write(STD_OUT , '(1X,A,1X,ES10.3)' , advance = "no") "|" , self % values(eq , bufferLine)
         end do

      end subroutine Residuals_WriteValue 

      subroutine Residuals_WriteToFile ( self , iter , t , no_of_lines)
!
!        *********************************************************************
!              This subroutine exports the results to the monitor file.
!           Just "no_of_lines" buffer lines are written.
!        *********************************************************************
!
         implicit none  
         class(Residuals_t)             :: self
         integer                    :: iter(:)
         real(kind=RP)              :: t(:)
         integer                    :: no_of_lines
!        -------------------------------------------
         integer                    :: i
         integer                    :: fID
!
!        Open file
!        ---------
         open( newunit = fID , file = trim ( self % fileName ) , action = "write" , access = "append" , status = "old" )
!
!        Write values
!        ------------         
         do i = 1 , no_of_lines
            write( fID , '(I10,2X,ES24.16,4(2X,ES24.16))' ) iter(i) , t(i) , self % values(1:NCONS,i)
         end do
!
!        Close file
!        ----------        
         close ( fID )

         self % values(1:NCONS,1) = self % values(1:NCONS,no_of_lines)
      
      end subroutine Residuals_WriteToFile

!
!//////////////////////////////////////////////////////////////////////////////////////////////////
!
!           PROBE ROUTINES
!           --------------
!//////////////////////////////////////////////////////////////////////////////////////////////////
!
      subroutine Probe_Initialization( self , mesh , ID ) 
!
!        **********************************************************
!              This subroutine initializes the probe.
!           Reads from the case file the following variables needed:
!              -> Name: The probe name (max 10 characters)
!              -> x position: The x coordinate of the probe
!              -> y position: The y coordinate of the probe
!              -> variable: The name of the variable to be tracked
!           Then, the element which contains the probe and its position
!           in the reference element is computed. If any trouble occurs,
!           the parameter "active" is set to .false.
!        **********************************************************
!
         use ParamfileIO
         use Setup_Class
         use MatrixOperations
         implicit none
         class(Probe_t)          :: self
         class(QuadMesh_t)       :: mesh
         integer                 :: ID
!        ----------------------------------------------
         character(len=STR_LEN_MONITORS)  :: in_label
         character(len=STR_LEN_MONITORS)  :: fileName
         real(kind=RP), allocatable       :: x,y
         integer                          :: pos
         integer                          :: fID
!
!        Probe ID
!        --------
         self % ID = ID
!
!        Label to search for the probe data in the file
!        ----------------------------------------------
         write(in_label , '(A,I0)') "#define probe " , self % ID
         
         call readValueInRegion ( trim ( Setup % case_file )  , "Name"       , self % monitorName , in_label , "# end" ) 
         call readValueInRegion ( trim ( Setup % case_file )  , "x position" , x                  , in_label , "# end" ) 
         call readValueInRegion ( trim ( Setup % case_file )  , "Variable"   , self % variable    , in_label , "# end" ) 
         call readValueInRegion ( trim ( Setup % case_file )  , "y position" , y                  , in_label , "# end" ) 
!
!        Find for the element in the mesh, and the position in the reference element, that contains the probe
!        ----------------------------------------------------------------------------------------------------
         call mesh % findElementWithCoords([x,y] , self % eID , self % xi , self % eta )
!
!        In case is not found, the active parameter is set to false
!        ----------------------------------------------------------
         if ( self % eID .eq. -1 ) then
            self % active = .false.
            return

         else
            self % active = .true.

         end if
!
!        Compute the Lagrange interpolants for the probe position
!        --------------------------------------------------------
         self % l_xi  = mesh % elements(self % eID) % spA % lj( self % xi  )
         self % l_eta = mesh % elements(self % eID) % spA % lj( self % eta )
!
!        Obtain the real coordinates: this will be the ones used
!        -------------------------------------------------------
         self % x = [ BilinearForm_F ( mesh % elements(self % eID) % X(:,:,IX) , self % l_xi , self % l_eta ) , &
                      BilinearForm_F ( mesh % elements(self % eID) % X(:,:,IY) , self % l_xi , self % l_eta ) ]
!
!        Get the monitor file name
!        -------------------------
         fileName = trim(Setup % solution_file)
         pos      = index(trim(fileName) , '.HiORst' )
         write( self % fileName , '(A,A,A,A)') fileName(1:pos-1) , "." , trim(self % monitorName) , ".probe"  
!
!        Create file
!        -----------
         open ( newunit = fID , file = trim(self % fileName) , status = "unknown" , action = "write" ) 
!
!        Set its header
!        --------------
         write( fID , '(A20,A    )') "Probe name :       " , trim(self % monitorName)
         write( fID , '(A20,F10.3)') "x position :       " , self % x(IX) 
         write( fID , '(A20,F10.3)') "y position :       " , self % x(IY) 
         write( fID , '(A20,I10  )') "Element    :       " , self % eID
         write( fID , '(A20,A    )') "Tracked variable : " , trim( self % variable )
         write( fID , * )
!
!        Write "iteration", "time", and the label of the variable
!        --------------------------------------------------------
         write( fID , '(A10,2X,A24,2X,A24)' ) "Iteration" , "Time" , trim(self % variable)
         close( fID ) 
              
      end subroutine Probe_Initialization

      subroutine Probe_Update ( self , mesh , bufferPosition )
!
!        ***************************************************************************
!              This subroutine updates the value of the probe. From the mesh,
!           it computes the value of the tracked variable by means of an 
!           interpolation. It is stored in the buffer.
!        ***************************************************************************
!        
         use MatrixOperations
         implicit none
         class(Probe_t)          :: self
         class(QuadMesh_t)       :: mesh
         integer                 :: bufferPosition
!        ------------------------------------------------------
         integer                 :: N 
         real(kind=RP)           :: rho  , rhou  , rhov  , rhoe
         real(kind=RP)           :: rhot , rhout , rhovt , rhoet
      
         if ( self % active ) then
            N = mesh % elements( self % eID ) % spA % N 
!   
!           Select the variable
!           -------------------
            select case ( trim( self % variable ) )
   
               case ("rho")
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHO , 0:N , 0:N )  , self % l_xi , self % l_eta , rho   ) 
                  self % values(bufferPosition) = rho * refValues % rho
    
               case ("rhou")
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOU , 0:N , 0:N )  , self % l_xi , self % l_eta , rhou  ) 
                  self % values(bufferPosition) = rhou * refValues % rho * refValues % a
    
               case ("rhov")
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOV , 0:N , 0:N )  , self % l_xi , self % l_eta , rhov  ) 
                  self % values(bufferPosition) = rhov * refValues % rho * refValues % a
    
               case ("rhoe")
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOE , 0:N , 0:N )  , self % l_xi , self % l_eta , rhoe  ) 
                  self % values(bufferPosition) = rhoe * refValues % rho * refValues % p
    
               case ("rhot")
                  call BilinearForm ( mesh % elements ( self % eID )  % QDot ( IRHO , 0:N , 0:N  )  , self % l_xi , self % l_eta , rhot  ) 
                  self % values(bufferPosition) = rhot * refValues % rho / refValues % tc
    
               case ("rhout")
                  call BilinearForm ( mesh % elements ( self % eID )  % QDot ( IRHOU , 0:N , 0:N )  , self % l_xi , self % l_eta , rhout ) 
                  self % values(bufferPosition) = rhout * refValues % rho * refValues % a / refValues % tc
    
               case ("rhovt")
                  call BilinearForm ( mesh % elements ( self % eID )  % QDot ( IRHOV , 0:N , 0:N )  , self % l_xi , self % l_eta , rhovt ) 
                  self % values(bufferPosition) = rhovt * refValues % rho * refValues % a / refValues % tc
    
               case ("rhoet")
                  call BilinearForm ( mesh % elements ( self % eID )  % QDot ( IRHOE , 0:N , 0:N  )  , self % l_xi , self % l_eta , rhoet ) 
                  self % values(bufferPosition) = rhoet * refValues % rho * refValues % p / refValues % tc
    
               case ("u")
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHO  , 0:N , 0:N )  , self % l_xi , self % l_eta , rho   ) 
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOU , 0:N , 0:N )  , self % l_xi , self % l_eta , rhou  ) 
                  self % values(bufferPosition) = rhou / rho * refValues % a
    
               case ("v")
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHO  , 0:N , 0:N )  , self % l_xi , self % l_eta , rho   ) 
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOV , 0:N , 0:N )  , self % l_xi , self % l_eta , rhov  ) 
                  self % values(bufferPosition) = rhov / rho * refValues % a
       
               case ("p")
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHO  , 0:N , 0:N )  , self % l_xi , self % l_eta , rho   ) 
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOU , 0:N , 0:N )  , self % l_xi , self % l_eta , rhou  ) 
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOV , 0:N , 0:N )  , self % l_xi , self % l_eta , rhov  ) 
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOE , 0:N , 0:N )  , self % l_xi , self % l_eta , rhoe  ) 
                  self % values(bufferPosition) = Thermodynamics % gm1 * ( rhoe - 0.5_RP * ( rhou * rhou + rhov * rhov ) / rho ) * refValues % p
          
               case ("Mach")
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHO  , 0:N , 0:N )  , self % l_xi , self % l_eta , rho   ) 
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOU , 0:N , 0:N )  , self % l_xi , self % l_eta , rhou  ) 
                  call BilinearForm ( mesh % elements ( self % eID )  % Q    ( IRHOV , 0:N , 0:N )  , self % l_xi , self % l_eta , rhov  ) 
                  self % values(bufferPosition) = sqrt(rhou * rhou + rhov * rhov) / rho / sqrt(Thermodynamics % gamma)
    
               case default
   
                  if ( len_trim (self % variable) .eq. 0 ) then
                     print*, "Variable was not specified for probe " , self % ID , "."
                  else
                     print*, 'Variable "',trim(self % variable),'" in probe ', self % ID, ' not implemented yet.'
                     print*, "Options available are:"
                     print*, "   * rho"
                     print*, "   * rhou"
                     print*, "   * rhov"
                     print*, "   * rhoe"
                     print*, "   * rhot"
                     print*, "   * rhout"
                     print*, "   * rhovt"
                     print*, "   * rhoet"
                     print*, "   * u"
                     print*, "   * v"
                     print*, "   * p"
                     print*, "   * Mach"
                     stop "Stopped."
   
                  end if
   
            end select                        
   
         end if

      end subroutine Probe_Update

      subroutine Probe_WriteLabel ( self )
!
!        ************************************************************
!              This subroutine displays the probe label for the time
!           integrator Display procedure.
!        ************************************************************
!
         implicit none
         class(Probe_t)             :: self
      
         if ( self % active ) then
            write(STD_OUT , '(3X,A10)' , advance = "no") trim(self % monitorName(1 : MONITOR_LENGTH))
         end if

      end subroutine Probe_WriteLabel
   
      subroutine Probe_WriteValue ( self , bufferLine ) 
!
!        ***********************************************************
!              This subroutine displays the probe value for the time
!           integrator Display procedure.
!        ***********************************************************
!
         implicit none
         class(Probe_t)             :: self
         integer                    :: bufferLine

         if ( self % active ) then
            write(STD_OUT , '(1X,A,1X,ES10.3)' , advance = "no") "|" , self % values ( bufferLine ) 
         end if

      end subroutine Probe_WriteValue 

      subroutine Probe_WriteToFile ( self , iter , t , no_of_lines)
!
!        *********************************************************************
!              This subroutine exports the results to the monitor file.
!           Just "no_of_lines" buffer lines are written.
!        *********************************************************************
!
         implicit none  
         class(Probe_t)             :: self
         integer                    :: iter(:)
         real(kind=RP)              :: t(:)
         integer                    :: no_of_lines
!        -------------------------------------------
         integer                    :: i
         integer                    :: fID

         if ( self % active ) then
            open( newunit = fID , file = trim ( self % fileName ) , action = "write" , access = "append" , status = "old" )
            
            do i = 1 , no_of_lines
               write( fID , '(I10,2X,ES24.16,2X,ES24.16)' ) iter(i) , t(i) , self % values(i)
   
            end do
           
            close ( fID )

            self % values(1) = self % values(no_of_lines)
         end if
      
      end subroutine Probe_WriteToFile
!
!/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
!
!           SURFACE MONITOR PROCEDURES
!           --------------------------
!/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
!
      subroutine SurfaceMonitor_Initialization( self , mesh , ID )
!
!        *****************************************************************************
!              This subroutine initializes the surface monitor. The following
!           data is obtained from the case file:
!              -> Name: The monitor name (10 characters maximum)
!              -> Marker: The surface marker in which the monitor will be computed.
!              -> Variable: The variable to be monitorized.
!              -> Reference surface (optional): Reference surface for lift/drag coefficients
!              -> Direction (optional): Direction in which the forces are computed
!        *****************************************************************************
!  
         use ParamfileIO
         use Setup_Class
         use MatrixOperations
         implicit none
         class(SurfaceMonitor_t) :: self
         class(QuadMesh_t)       :: mesh
         integer                 :: ID
!        ----------------------------------------------
         character(len=STR_LEN_MONITORS)  :: in_label
         character(len=STR_LEN_MONITORS)  :: fileName
         integer, allocatable             :: marker
         integer                          :: pos
         integer                          :: fID
!
!        Get monitor ID
!        --------------
         self % ID = ID
!
!        Search for the parameters in the case file
!        ------------------------------------------
         write(in_label , '(A,I0)') "#define surface monitor " , self % ID
         
         call readValueInRegion ( trim ( Setup % case_file )  , "Name"              , self % monitorName      , in_label , "# end" ) 
         call readValueInRegion ( trim ( Setup % case_file )  , "Marker"            , marker                  , in_label , "# end" ) 
         call readValueInRegion ( trim ( Setup % case_file )  , "Variable"          , self % variable         , in_label , "# end" ) 
         call readValueInRegion ( trim ( Setup % case_file )  , "Reference surface" , self % referenceSurface , in_label , "# end" ) 
         call readValueInRegion ( trim ( Setup % case_file )  , "Direction"         , self % direction        , in_label , "# end" ) 
!
!        Enable the monitor
!        ------------------
         self % active = .true.
!
!        Get the surface marker
!        ----------------------
         if ( allocated ( marker ) ) then
            self % marker = marker
         else
            print*, "Marker not specified for surface monitor " , self % ID, "."
            stop "Stopped"

         end if
!
!        Select the variable from the available list, and compute auxiliary variables if needed
!        --------------------------------------------------------------------------------------
!
!        ****************************************
         select case ( trim ( self % variable ) )
!        ****************************************
!
!
!           ---------------------------------------------------
            case ("mass-flow")
               self % isDimensionless = .false.
!
!           ---------------------------------------------------
            case ("flow")
               self % isDimensionless = .false.
!
!           ---------------------------------------------------
            case ("pressure-force")
               self % isDimensionless = .false.
               if ( .not. allocated ( self % direction ) ) then
                  print*, "Direction not specified for pressure-force in surface monitor " , self % ID , "."
                  stop "Stopped"
               end if
!            
!           ---------------------------------------------------
            case ("viscous-force")
               self % isDimensionless = .false.
               if ( .not. allocated ( self % direction ) ) then
                  print*, "Direction not specified for viscous-force in surface monitor " , self % ID , "."
                  stop "Stopped"
               end if
!
!           ---------------------------------------------------
            case ("force")
               self % isDimensionless = .false.
               if ( .not. allocated ( self % direction ) ) then
                  print*, "Direction not specified for force in surface monitor " , self % ID , "."
                  stop "Stopped"
               end if
!
!           ---------------------------------------------------
            case ("lift")
               self % isDimensionless = .true.

               if ( .not. allocated ( self % referenceSurface ) ) then
                  print*, "Reference surface not specified for lift surface monitor " , self % ID , "."
                  stop "Stopped"
               end if

               self % dynamicPressure = 0.5_RP * refValues % rho * refValues % V * refValues % V * self % referenceSurface
!
!           ---------------------------------------------------
            case ("drag")
               self % isDimensionless = .true.

               if ( .not. allocated ( self % referenceSurface ) ) then
                  print*, "Reference surface not specified for drag surface monitor " , self % ID , "."
                  stop "Stopped"
               end if

               self % dynamicPressure = 0.5_RP * refValues % rho * refValues % V * refValues % V * self % referenceSurface
!
!           ---------------------------------------------------
            case ("pressure-average")
               self % isDimensionless = .false.
!
!           ---------------------------------------------------
            case default

               if ( len_trim (self % variable) .eq. 0 ) then
                  print*, "Variable was not specified for surface monitor " , self % ID , "."
               else
                  print*, 'Variable "',trim(self % variable),'" surface monitor ', self % ID, ' not implemented yet.'
                  print*, "Options available are:"
                  print*, "   * mass-flow"
                  print*, "   * flow"
                  print*, "   * pressure-force"
                  print*, "   * viscous-force"
                  print*, "   * force"
                  print*, "   * lift"
                  print*, "   * drag"
                  print*, "   * pressure-average"
                  stop "Stopped."

               end if
!
!        **********
         end select
!        **********
!
!        Prepare the file in which the monitor is exported
!        -------------------------------------------------
         fileName = trim(Setup % solution_file)
         pos      = index(trim(fileName) , '.HiORst' )
         write( self % fileName , '(A,A,A,A)') fileName(1:pos-1) , "." , trim(self % monitorName) , ".surface"  
!
!        Create file
!        -----------
         open ( newunit = fID , file = trim(self % fileName) , status = "unknown" , action = "write" ) 
!
!        Write the file headers
!        ----------------------
         write( fID , '(A20,A  )') "Monitor name:      ", trim(self % monitorName)
         write( fID , '(A20,I0 )') "Surface marker:    ", self % marker
         write( fID , '(A20,A  )') "Selected variable: " , trim(self % variable)

         if ( self % isDimensionless ) then
            write(fID , '(A20,ES24.10)') "Dynamic pressure: " , self % dynamicPressure
         end if

         write( fID , * )
         write( fID , '(A10,2X,A24,2X,A24)' ) "Iteration" , "Time" , trim(self % variable)

         close ( fID ) 

      end subroutine SurfaceMonitor_Initialization

      subroutine SurfaceMonitor_Update ( self , mesh , bufferPosition )
!
!        *******************************************************************
!           This subroutine updates the monitor value computing it from
!           the mesh. It is stored in the "bufferPosition" position of the 
!           buffer.
!        *******************************************************************
!
         use MatrixOperations
         implicit none
         class   (  SurfaceMonitor_t ) :: self
         class   (  QuadMesh_t       ) :: mesh
         integer                       :: bufferPosition
!        ------------------------------------------------------
         real(kind=RP)           :: vector(NDIM)
      
         associate ( N => mesh % elements( self % ID ) % spA % N )
!
!        Select variable from the available list
!        ---------------------------------------
         select case ( trim( self % variable ) )

            case ("mass-flow")
               self % values(bufferPosition) = mesh % VectorVectorSurfaceIntegral("mass-flow" , self % marker ) * RefValues % L * refValues % a * refValues % rho

            case ("flow")
               self % values(bufferPosition) = mesh % VectorVectorSurfaceIntegral("flow" , self % marker ) * RefValues % L * refValues % a
            
            case ("pressure-force")
               vector(IX:IY) =  mesh % ScalarVectorSurfaceIntegral("pressure" , self % marker) * refValues % p * refValues % L
               self % values(bufferPosition) = vector(self % direction)
   
            case ("viscous-force") 
               vector(IX:IY) = -mesh % TensorVectorSurfaceIntegral("viscous" , self % marker) * refValues % p * refValues % L * dimensionless % sqrtGammaMach
               self % values(bufferPosition) = vector(self % direction)
      
            case ("force") 
               vector(IX:IY) = mesh % ScalarVectorSurfaceIntegral("pressure" , self % marker) * refValues % p * refValues % L
               vector(IX:IY) = vector(IX:IY) - mesh % TensorVectorSurfaceIntegral("viscous" , self % marker) * refValues % p * refValues % L * dimensionless % sqrtGammaMach
               self % values(bufferPosition) = vector(self % direction)

            case ("lift")
               vector(IX:IY) = mesh % ScalarVectorSurfaceIntegral("pressure" , self % marker) * refValues % p * refValues % L
               vector(IX:IY) = vector(IX:IY) - mesh % TensorVectorSurfaceIntegral("viscous" , self % marker) * refValues % p * refValues % L * dimensionless % sqrtGammaMach
               self % values(bufferPosition) = vector(IY) / self % dynamicPressure

            case ("drag")
               vector(IX:IY) = mesh % ScalarVectorSurfaceIntegral("pressure" , self % marker) * refValues % p * refValues % L
               vector(IX:IY) = vector(IX:IY) - mesh % TensorVectorSurfaceIntegral("viscous" , self % marker) * refValues % p * refValues % L * dimensionless % sqrtGammaMach
               self % values(bufferPosition) = vector(IX) / self % dynamicPressure

            case ("pressure-average")
               self % values(bufferPosition) = mesh % ScalarScalarSurfaceIntegral("pressure",self % marker) / mesh % ScalarScalarSurfaceIntegral("Surface",self % marker) * refValues % p

         end select                        

         end associate

      end subroutine SurfaceMonitor_Update

      subroutine SurfaceMonitor_WriteLabel ( self )
!
!        *************************************************************
!              This subroutine writes the label for the surface
!           monitor, when invoked from the time integrator Display
!           procedure.
!        *************************************************************
!
         implicit none
         class(SurfaceMonitor_t)             :: self

         write(STD_OUT , '(3X,A10)' , advance = "no") trim(self % monitorName(1 : MONITOR_LENGTH))

      end subroutine SurfaceMonitor_WriteLabel
   
      subroutine SurfaceMonitor_WriteValue ( self , bufferLine ) 
!
!        *************************************************************
!              This subroutine writes the monitor value for the time
!           integrator Display procedure.
!        *************************************************************
!
         implicit none
         class(SurfaceMonitor_t) :: self
         integer                 :: bufferLine

         write(STD_OUT , '(1X,A,1X,ES10.3)' , advance = "no") "|" , self % values ( bufferLine ) 

      end subroutine SurfaceMonitor_WriteValue 

      subroutine SurfaceMonitor_WriteToFile ( self , iter , t , no_of_lines)
!
!        *************************************************************
!              This subroutine writes the buffer to the file.
!        *************************************************************
!
         implicit none  
         class(SurfaceMonitor_t) :: self
         integer                 :: iter(:)
         real(kind=RP)           :: t(:)
         integer                 :: no_of_lines
!        -------------------------------------------
         integer                    :: i
         integer                    :: fID

         open( newunit = fID , file = trim ( self % fileName ) , action = "write" , access = "append" , status = "old" )
         
         do i = 1 , no_of_lines
            write( fID , '(I10,2X,ES24.16,2X,ES24.16)' ) iter(i) , t(i) , self % values(i)

         end do
        
         close ( fID )

         self % values(1) = self % values(no_of_lines)
      
      end subroutine SurfaceMonitor_WriteToFile
!
!/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
!
!           VOLUME MONITOR PROCEDURES
!           -------------------------
!/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
!
      subroutine VolumeMonitor_Initialization( self , mesh , ID )
!
!        *****************************************************************************
!              This subroutine initializes the volume monitor. The following
!           data is obtained from the case file:
!              -> Name: The monitor name (10 characters maximum)
!              -> Variable: The variable to be monitorized.
!        *****************************************************************************
!  
         use ParamfileIO
         use Setup_Class
         use MatrixOperations
         implicit none
         class(VolumeMonitor_t) :: self
         class(QuadMesh_t)      :: mesh
         integer                :: ID
!        ----------------------------------------------
         character(len=STR_LEN_MONITORS)  :: in_label
         character(len=STR_LEN_MONITORS)  :: fileName
         integer                          :: fID
         integer                          :: pos
!
!        Get monitor ID
!        --------------
         self % ID = ID
!
!        Search for the parameters in the case file
!        ------------------------------------------
         write(in_label , '(A,I0)') "#define volume monitor " , self % ID
         
         call readValueInRegion ( trim ( Setup % case_file )  , "Name"              , self % monitorName      , in_label , "# end" ) 
         call readValueInRegion ( trim ( Setup % case_file )  , "Variable"          , self % variable         , in_label , "# end" ) 
!
!        Enable the monitor
!        ------------------
         self % active = .true.
!
!        Select the variable from the available list, and compute auxiliary variables if needed
!        --------------------------------------------------------------------------------------
!
!        ****************************************
         select case ( trim ( self % variable ) )
!        ****************************************
!
!
!           ---------------------------------------------------
            case ("dSnorm")
               self % referenceValue = 1.0_RP
               self % volumeType = VOLUME_INTEGRAL
!
!           ---------------------------------------------------
            case ("MaxJumps") 
               self % volumeType = VOLUME_UNDEFINED

            case default

               if ( len_trim (self % variable) .eq. 0 ) then
                  print*, "Variable was not specified for surface monitor " , self % ID , "."
               else
                  print*, 'Variable "',trim(self % variable),'" surface monitor ', self % ID, ' not implemented yet.'
                  print*, "Options available are:"
                  print*, "   * dSnorm"
                  stop "Stopped."

               end if
!
!        **********
         end select

!
!        Prepare the file in which the monitor is exported
!        -------------------------------------------------
         fileName = trim(Setup % solution_file)
         pos      = index(trim(fileName) , '.HiORst' )
         write( self % fileName , '(A,A,A,A)') fileName(1:pos-1) , "." , trim(self % monitorName) , ".volume"  
!
!        Create file
!        -----------
         open ( newunit = fID , file = trim(self % fileName) , status = "unknown" , action = "write" ) 
!
!        Write the file headers
!        ----------------------
         write( fID , '(A20,A  )') "Monitor name:      ", trim(self % monitorName)
         write( fID , '(A20,A  )') "Selected variable: " , trim(self % variable)

         write( fID , * )
         write( fID , '(A10,2X,A24,2X,A24)' ) "Iteration" , "Time" , trim(self % variable)

         close ( fID ) 

      end subroutine VolumeMonitor_Initialization

      subroutine VolumeMonitor_Update ( self , mesh , bufferPosition )
!
!        *******************************************************************
!           This subroutine updates the monitor value computing it from
!           the mesh. It is stored in the "bufferPosition" position of the 
!           buffer.
!        *******************************************************************
!
         use MatrixOperations
         implicit none
         class   (  VolumeMonitor_t )  :: self
         class   (  QuadMesh_t       ) :: mesh
         integer                       :: bufferPosition
!
!        Compute the volume integral
!        ---------------------------
         if ( self % volumeType .eq. VOLUME_INTEGRAL ) then
            self % values(bufferPosition) = mesh % VolumeIntegral(trim(self % variable)) / mesh % Volume
   
         else

            select case ( trim(self % variable) ) 
   
               case ( "MaxJumps" ) 

                  self % values(bufferPosition) = mesh % ComputeMaxJumps()

            end select
   
         end if



      end subroutine VolumeMonitor_Update

      subroutine VolumeMonitor_WriteLabel ( self )
!
!        *************************************************************
!              This subroutine writes the label for the volume
!           monitor, when invoked from the time integrator Display
!           procedure.
!        *************************************************************
!
         implicit none
         class(VolumeMonitor_t)             :: self

         write(STD_OUT , '(3X,A10)' , advance = "no") trim(self % monitorName(1 : MONITOR_LENGTH))

      end subroutine VolumeMonitor_WriteLabel
   
      subroutine VolumeMonitor_WriteValue ( self , bufferLine ) 
!
!        *************************************************************
!              This subroutine writes the monitor value for the time
!           integrator Display procedure.
!        *************************************************************
!
         implicit none
         class(VolumeMonitor_t) :: self
         integer                 :: bufferLine

         write(STD_OUT , '(1X,A,1X,ES10.3)' , advance = "no") "|" , self % values ( bufferLine ) 

      end subroutine VolumeMonitor_WriteValue 

      subroutine VolumeMonitor_WriteToFile ( self , iter , t , no_of_lines)
!
!        *************************************************************
!              This subroutine writes the buffer to the file.
!        *************************************************************
!
         implicit none  
         class(VolumeMonitor_t) :: self
         integer                 :: iter(:)
         real(kind=RP)           :: t(:)
         integer                 :: no_of_lines
!        -------------------------------------------
         integer                    :: i
         integer                    :: fID

         open( newunit = fID , file = trim ( self % fileName ) , action = "write" , access = "append" , status = "old" )
         
         do i = 1 , no_of_lines
            write( fID , '(I10,2X,ES24.16,2X,ES24.16)' ) iter(i) , t(i) , self % values(i)

         end do
        
         close ( fID )

         self % values(1) = self % values(no_of_lines)
      
      end subroutine VolumeMonitor_WriteToFile



end module MonitorsClass
!
!////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
!
!
