-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2009-2011, AdaCore              --
--                                                                   --
-- GPS is Free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Calendar;       use Ada.Calendar;
with GNATCOLL.Projects;  use GNATCOLL.Projects;
with GNATCOLL.VFS;       use GNATCOLL.VFS;

with GPS.Kernel.Console; use GPS.Kernel;
with GPS.Kernel.Project;
with GPS.Kernel.Timeout;
with GPS.Intl;           use GPS.Intl;

with GNATCOLL.Arg_Lists;  use GNATCOLL.Arg_Lists;

with Code_Peer.Bridge.Commands;
with Code_Peer.Shell_Commands;

package body Code_Peer.Module.Bridge is

   type Bridge_Mode is (Add_Audit, Audit_Trail, Inspection);

   type Bridge_Context (Mode : Bridge_Mode) is
     new GPS.Kernel.Timeout.Callback_Data_Record with record
      Module    : Code_Peer.Module.Code_Peer_Module_Id;
      File_Name : Virtual_File;

      case Mode is
         when Inspection =>
            null;

         when Add_Audit | Audit_Trail =>
            Message : Code_Peer.Message_Access;
      end case;
   end record;

   overriding procedure Destroy (Data : in out Bridge_Context);

   Audit_Request_File_Name      : constant Filesystem_String :=
      "audit_trail_request.xml";
   Audit_Reply_File_Name        : constant Filesystem_String :=
      "audit_trail_reply.xml";
   Add_Audit_File_Name          : constant Filesystem_String :=
      "add_audit_record.xml";
   Inspection_Request_File_Name : constant Filesystem_String :=
      "inspection_request.xml";
   Inspection_Reply_File_Name   : constant Filesystem_String :=
      "inspection_reply.xml";

   procedure On_Bridge_Exit
     (Process : GPS.Kernel.Timeout.Process_Data;
      Status  : Integer);
   --  Called when gps_codepeer_bridge program execution is done

   ----------------------
   -- Add_Audit_Record --
   ----------------------

   procedure Add_Audit_Record
     (Module  : Code_Peer.Module.Code_Peer_Module_Id;
      Message : Code_Peer.Message_Access)
   is
      Project           : constant Project_Type :=
                            GPS.Kernel.Project.Get_Project (Module.Kernel);
      Object_Directory  : constant Virtual_File := Project.Object_Dir;
      Command_File_Name : constant Virtual_File :=
                            Create_From_Dir
                              (Object_Directory, Add_Audit_File_Name);

      Mode              : constant String :=
                            Code_Peer.Shell_Commands.Get_Build_Mode
                              (Kernel_Handle (Module.Kernel));
      CodePeer_Subdir   : constant Boolean :=
                            Use_CodePeer_Subdir
                              (Kernel_Handle (Module.Kernel));
      Success           : Boolean;
      CL                : Arg_List;
      Ids               : Natural_Sets.Set;
      pragma Warnings (Off, Success);

   begin
      CL := Create ("gps_codepeer_bridge");
      Append_Argument (CL, +Command_File_Name.Full_Name.all, One_Arg);

      if CodePeer_Subdir then
         Code_Peer.Shell_Commands.Set_Build_Mode
           (Kernel_Handle (Module.Kernel), "codepeer");
      end if;

      --  Generate command file

      Ids.Insert (Message.Id);
      Ids.Union (Message.Merged);

      if Message.Audit.First_Element.Probability_Changed then
         Code_Peer.Bridge.Commands.Add_Audit_Record
           (Command_File_Name,
            Codepeer_Output_Directory (Project),
            Ids,
            True,
            Message.Audit.First_Element.Ranking,
            Message.Audit.First_Element.Comment.all);

      else
         Code_Peer.Bridge.Commands.Add_Audit_Record
           (Command_File_Name,
            Codepeer_Output_Directory (Project),
            Ids,
            False,
            Code_Peer.High,
            Message.Audit.First_Element.Comment.all);
      end if;

      --  Run gps_codepeer_bridge

      GPS.Kernel.Timeout.Launch_Process
        (Kernel        => GPS.Kernel.Kernel_Handle (Module.Kernel),
         CL            => CL,
         Console       => GPS.Kernel.Console.Get_Console (Module.Kernel),
         Directory     => Object_Directory,
         Callback_Data =>
           new Bridge_Context'(Add_Audit, Module, No_File, Message),
         Success       => Success,
         Exit_Cb       => On_Bridge_Exit'Access);

      if CodePeer_Subdir then
         Code_Peer.Shell_Commands.Set_Build_Mode
           (Kernel_Handle (Module.Kernel), Mode);
      end if;
   end Add_Audit_Record;

   -------------
   -- Destroy --
   -------------

   overriding procedure Destroy (Data : in out Bridge_Context) is
   begin
      null;
   end Destroy;

   ----------------
   -- Inspection --
   ----------------

   procedure Inspection (Module : Code_Peer.Module.Code_Peer_Module_Id) is
      Project           : constant Project_Type :=
                            GPS.Kernel.Project.Get_Project (Module.Kernel);
      Object_Directory  : constant Virtual_File := Project.Object_Dir;
      Command_File_Name : constant Virtual_File :=
                            Create_From_Dir
                              (Object_Directory,
                               Inspection_Request_File_Name);
      Reply_File_Name   : constant Virtual_File :=
                            Create_From_Dir
                              (Object_Directory, Inspection_Reply_File_Name);
      DB_File_Name      : constant Virtual_File :=
                            Create_From_Dir
                              (Codepeer_Database_Directory (Project),
                               "Sqlite.db");
      Output_Directory  : constant Virtual_File :=
                            Codepeer_Output_Directory (Project);
      CL                : Arg_List;
      Success           : Boolean;
      pragma Warnings (Off, Success);

   begin
      CL := Create ("gps_codepeer_bridge");

      if not Is_Directory (Output_Directory) then
         Console.Insert
           (Module.Kernel,
            -"cannot find CodePeer output directory: " &
            Output_Directory.Display_Full_Name,
            Mode => Console.Error);
         return;
      end if;

      if DB_File_Name.Is_Regular_File
         and then Reply_File_Name.Is_Regular_File
         and then DB_File_Name.File_Time_Stamp
            < Reply_File_Name.File_Time_Stamp
      then
         Module.Load (Reply_File_Name);

      else
         Append_Argument (CL, +Command_File_Name.Full_Name.all, One_Arg);
         --  Generate command file

         Code_Peer.Bridge.Commands.Inspection
            (Command_File_Name, Output_Directory, Reply_File_Name);

         --  Run gps_codepeer_bridge

         GPS.Kernel.Timeout.Launch_Process
           (Kernel        => GPS.Kernel.Kernel_Handle (Module.Kernel),
            CL            => CL,
            Console       => GPS.Kernel.Console.Get_Console (Module.Kernel),
            Directory     => Object_Directory,
            Callback_Data => new Bridge_Context'
              (Inspection, Module, Reply_File_Name),
            Success       => Success,
            Exit_Cb       => On_Bridge_Exit'Access);
      end if;
   end Inspection;

   --------------------
   -- On_Bridge_Exit --
   --------------------

   procedure On_Bridge_Exit
     (Process : GPS.Kernel.Timeout.Process_Data;
      Status  : Integer)
   is
      Context : Bridge_Context'Class
      renames Bridge_Context'Class (Process.Callback_Data.all);

   begin
      if Status = 0 then
         case Context.Mode is
            when Inspection =>
               Context.Module.Load (Context.File_Name);

            when Audit_Trail =>
               Context.Module.Review_Message
                 (Context.Message, Context.File_Name);

            when Add_Audit =>
               null;
         end case;

      else
         GPS.Kernel.Console.Insert
           (Context.Module.Get_Kernel,
            "gps_codepeer_bridge execution failed",
            True,
            GPS.Kernel.Console.Error);
      end if;
   end On_Bridge_Exit;

   ----------------------------------
   -- Remove_Inspection_Cache_File --
   ----------------------------------

   procedure Remove_Inspection_Cache_File
     (Module : Code_Peer.Module.Code_Peer_Module_Id)
   is
      Project           : constant Project_Type :=
                            GPS.Kernel.Project.Get_Project (Module.Kernel);
      Object_Directory  : constant Virtual_File := Project.Object_Dir;
      Reply_File_Name   : constant Virtual_File :=
                            Create_From_Dir
                              (Object_Directory, Inspection_Reply_File_Name);
      Success           : Boolean;

   begin
      if Reply_File_Name.Is_Regular_File then
         Delete (Reply_File_Name, Success);

         if not Success then
            Console.Insert
              (Module.Kernel, -"Unable to remove code review file");
         end if;
      end if;
   end Remove_Inspection_Cache_File;

   --------------------
   -- Review_Message --
   --------------------

   procedure Review_Message
     (Module  : Code_Peer.Module.Code_Peer_Module_Id;
      Message : Code_Peer.Message_Access)
   is
      Project            : constant Project_Type :=
                             GPS.Kernel.Project.Get_Project (Module.Kernel);
      Object_Directory   : constant Virtual_File := Project.Object_Dir;
      Command_File_Name  : constant Virtual_File :=
                             Create_From_Dir
                               (Object_Directory, Audit_Request_File_Name);
      Reply_File_Name    : constant Virtual_File :=
                             Create_From_Dir
                               (Object_Directory, Audit_Reply_File_Name);
      Mode               : constant String :=
                             Code_Peer.Shell_Commands.Get_Build_Mode
                               (Kernel_Handle (Module.Kernel));
      CodePeer_Subdir    : constant Boolean :=
                             Use_CodePeer_Subdir
                               (Kernel_Handle (Module.Kernel));
      CL                 : Arg_List;
      Success            : Boolean;
      pragma Warnings (Off, Success);

   begin
      CL := Create ("gps_codepeer_bridge");
      Append_Argument (CL, +Command_File_Name.Full_Name.all, One_Arg);

      if CodePeer_Subdir then
         Code_Peer.Shell_Commands.Set_Build_Mode
           (Kernel_Handle (Module.Kernel), "codepeer");
      end if;

      --  Generate command file

      Code_Peer.Bridge.Commands.Audit_Trail
        (Command_File_Name,
         Codepeer_Output_Directory (Project),
         Reply_File_Name,
         Message.Id);

      --  Run gps_codepeer_bridge

      GPS.Kernel.Timeout.Launch_Process
        (Kernel        => GPS.Kernel.Kernel_Handle (Module.Kernel),
         CL            => CL,
         Console       => GPS.Kernel.Console.Get_Console (Module.Kernel),
         Directory     => Object_Directory,
         Callback_Data =>
           new Bridge_Context'
           (Audit_Trail, Module, Reply_File_Name, Message),
         Success       => Success,
         Exit_Cb       => On_Bridge_Exit'Access);

      if CodePeer_Subdir then
         Code_Peer.Shell_Commands.Set_Build_Mode
           (Kernel_Handle (Module.Kernel), Mode);
      end if;
   end Review_Message;

end Code_Peer.Module.Bridge;