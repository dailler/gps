------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2003-2013, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

--  This package handles build commands

with Ada.Strings.Unbounded;     use Ada.Strings.Unbounded;

with GPS.Kernel;
with GNATCOLL.VFS;              use GNATCOLL.VFS;
with Remote;                    use Remote;
with Interactive_Consoles;      use Interactive_Consoles;
with GNATCOLL.Arg_Lists;        use GNATCOLL.Arg_Lists;
with GPS.Kernel.Messages;
with Extending_Environments;    use Extending_Environments;
with Build_Command_Utils;       use Build_Command_Utils;

package Commands.Builder is

   Error_Category : constant String := "Builder results";
   --  -"Builder results"

   Builder_Message_Flags    : constant GPS.Kernel.Messages.Message_Flags :=
     (GPS.Kernel.Messages.Editor_Side => True,
      GPS.Kernel.Messages.Locations   => True);
   Background_Message_Flags : constant GPS.Kernel.Messages.Message_Flags :=
     (GPS.Kernel.Messages.Editor_Side => True,
      GPS.Kernel.Messages.Locations   => False);

   procedure Launch_Build_Command
     (Kernel           : GPS.Kernel.Kernel_Handle;
      CL               : Arg_List;
      Server           : Server_Type;
      Synchronous      : Boolean;
      Use_Shell        : Boolean;
      Console          : Interactive_Console;
      Directory        : Virtual_File;
      Builder          : Builder_Context;
      Background_Env   : Extending_Environment;
      Target_Name      : String;
      Mode             : String;
      Category_Name    : Unbounded_String;
      Quiet            : Boolean;
      Shadow           : Boolean;
      Background       : Boolean;
      Is_Run           : Boolean);
   --  Launch a build command.
   --  CL is the command line. The first item in CL should be the executable
   --  and the rest are arguments.
   --  Target_Name is the name of the target being launched.
   --  Category_Name is the name of the target category being launched.
   --  If Use_Shell, and if the SHELL environment variable is defined,
   --  then call the command through $SHELL -c "command line".
   --  Use given Console to send the output.
   --  See Build_Command_Manager.Launch_Target for the meanings of Quiet and
   --  Synchronous.

   function Get_Build_Console
     (Kernel              : GPS.Kernel.Kernel_Handle;
      Shadow              : Boolean;
      Background          : Boolean;
      Create_If_Not_Exist : Boolean;
      New_Console_Name    : String := "") return Interactive_Console;
   --  Return the console appropriate for showing compiler errors
   --  If New_Console_Name is specified, create a new console with this name.

end Commands.Builder;
