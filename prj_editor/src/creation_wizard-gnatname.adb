------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                        Copyright (C) 2012, AdaCore                       --
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

with Ada.Strings.Unbounded;     use Ada.Strings.Unbounded;

with Glib;                      use Glib;
with Gtk.Box;                   use Gtk.Box;
with Gtk.Frame;                 use Gtk.Frame;
with Gtk.Dialog;                use Gtk.Dialog;
with Gtk.GEntry;                use Gtk.GEntry;
with Gtk.Tree_View;             use Gtk.Tree_View;
with Gtk.Widget;                use Gtk.Widget;
with Gtk.Window;                use Gtk.Window;
with Gtk.Scrolled_Window;       use Gtk.Scrolled_Window;
with Gtk.Enums;                 use Gtk.Enums;
with Gtk.Check_Button;          use Gtk.Check_Button;
with Gtk.Button;                use Gtk.Button;
with Gtk.Stock;                 use Gtk.Stock;
with Gtk.Tree_Model;            use Gtk.Tree_Model;
with Gtk.Tree_Store;            use Gtk.Tree_Store;
with Gtk.Tree_Selection;        use Gtk.Tree_Selection;

with Gtkada.Handlers;           use Gtkada.Handlers;

with GNAT.Strings;
with GNATCOLL.Arg_Lists;        use GNATCOLL.Arg_Lists;
with GNATCOLL.VFS;              use GNATCOLL.VFS;

with GPS.Intl;                  use GPS.Intl;
with GPS.Kernel;                use GPS.Kernel;
with GPS.Kernel.Scripts;        use GPS.Kernel.Scripts;

with GUI_Utils;
with Wizards;                   use Wizards;
with Project_Properties;

package body Creation_Wizard.GNATname is

   type GNATname_Page_Record is new Project_Wizard_Page_Record with record
      Check_Button : Gtk_Check_Button;
      Tree_View    : Gtk.Tree_View.Gtk_Tree_View;
      Hbox         : Gtk_Hbox;
   end record;
   type GNATname_Page_Access is access all GNATname_Page_Record'Class;
   overriding procedure Generate_Project
     (Page               : access GNATname_Page_Record;
      Kernel             : access GPS.Kernel.Kernel_Handle_Record'Class;
      Scenario_Variables : Scenario_Variable_Array;
      Project            : in out Project_Type;
      Changed            : in out Boolean);
   overriding procedure Project_Saved
     (Page               : access GNATname_Page_Record;
      Kernel             : access GPS.Kernel.Kernel_Handle_Record'Class;
      Project            : Project_Type);
   overriding function Create_Content
     (Page : access GNATname_Page_Record;
      Wiz  : access Wizard_Record'Class) return Gtk.Widget.Gtk_Widget;
   overriding function Is_Complete
     (Page : access GNATname_Page_Record) return String;
   overriding function Next_Page
     (Page : access GNATname_Page_Record;
      Wiz  : access Wizard_Record'Class) return Wizard_Page;
   --  See inherited documentation

   procedure Toggle_Enabled (Widget : access Gtk_Widget_Record'Class);
   --  Callback to toggle sensitivity on check box clicks

   procedure Add_Pattern (Widget : access Gtk_Widget_Record'Class);
   procedure Remove_Pattern (Widget : access Gtk_Widget_Record'Class);
   --  Callbacks on Add/Remove buttons click

   function Build_Target
     (Kernel : GPS.Kernel.Kernel_Handle;
      Name   : String)
      return String;
   --  Creates BuildTarget and returns it.

   procedure Build_Target_Execute
     (Kernel      : GPS.Kernel.Kernel_Handle;
      Target_ID   : String;
      Main_Name   : String       := "";
      File        : Virtual_File := GNATCOLL.VFS.No_File;
      Force       : Boolean      := False;
      Extra_Args  : String       := "";
      Build_Mode  : String       := "";
      Synchronous : Boolean      := True;
      Dir         : Virtual_File := GNATCOLL.VFS.No_File);
   --  Executes BuildTarget.execute function.

   -----------------------
   -- Add_GNATname_Page --
   -----------------------

   procedure Add_GNATname_Page
     (Wiz : access Project_Wizard_Record'Class)
   is
      Description : constant String :=
        -"Search for units with arbitrary file naming conventions";
      P : constant GNATname_Page_Access := new GNATname_Page_Record;
   begin
      Add_Page
        (Wiz,
         Page        => P,
         Description => Description,
         Toc         => -"GNATname");
   end Add_GNATname_Page;

   -----------------
   -- Add_Pattern --
   -----------------

   procedure Add_Pattern (Widget : access Gtk_Widget_Record'Class) is
      Tree_View  : constant Gtk_Tree_View := Gtk_Tree_View (Widget);
      Tree_Store : constant Gtk_Tree_Store :=
        Gtk_Tree_Store (Tree_View.Get_Model);
      Dialog : Gtk_Dialog;
      Ent    : Gtk_Entry;
      Button : Gtk_Widget;
      Ignore : Gtk_Widget;
      pragma Unreferenced (Ignore);
   begin
      Gtk_New (Dialog,
               Title  => -"Enter new value",
               Parent => Gtk_Window (Get_Toplevel (Widget)),
               Flags  => Modal or Destroy_With_Parent);
      Gtk_New (Ent);
      Set_Activates_Default (Ent, True);
      Pack_Start (Get_Vbox (Dialog), Ent, Expand => True, Fill => True);

      Button := Add_Button (Dialog, Stock_Ok, Gtk_Response_OK);
      Grab_Default (Button);
      Ignore := Add_Button (Dialog, Stock_Cancel, Gtk_Response_Cancel);

      Show_All (Dialog);

      case Run (Dialog) is
         when Gtk_Response_OK =>
            declare
               Iter    : Gtk_Tree_Iter;
               Pattern : constant String := Ent.Get_Text;
            begin
               Append (Tree_Store, Iter, Null_Iter);
               Set (Tree_Store, Iter, 0, Pattern);
            end;
         when others =>
            null;
      end case;

      Destroy (Dialog);
   end Add_Pattern;

   ------------------
   -- Build_Target --
   ------------------

   function Build_Target
     (Kernel : GPS.Kernel.Kernel_Handle;
      Name   : String)
      return String
   is
      CL : Arg_List := Create ("BuildTarget");
   begin
      Append_Argument (CL, Name, One_Arg);
      return GPS.Kernel.Scripts.Execute_GPS_Shell_Command (Kernel, CL);
   end Build_Target;

   --------------------------
   -- Build_Target_Execute --
   --------------------------

   procedure Build_Target_Execute
     (Kernel      : GPS.Kernel.Kernel_Handle;
      Target_ID   : String;
      Main_Name   : String       := "";
      File        : Virtual_File := GNATCOLL.VFS.No_File;
      Force       : Boolean      := False;
      Extra_Args  : String       := "";
      Build_Mode  : String       := "";
      Synchronous : Boolean      := True;
      Dir         : Virtual_File := GNATCOLL.VFS.No_File)
   is
      CL : Arg_List := Create ("BuildTarget.execute");
   begin
      Append_Argument (CL, Target_ID, One_Arg);
      Append_Argument (CL, Main_Name, One_Arg);
      Append_Argument (CL, +Full_Name (File), One_Arg);
      Append_Argument (CL, Boolean'Image (Force), One_Arg);
      Append_Argument (CL, Extra_Args, One_Arg);
      Append_Argument (CL, Build_Mode, One_Arg);
      Append_Argument (CL, Boolean'Image (Synchronous), One_Arg);
      Append_Argument (CL, +Full_Name (Dir), One_Arg);

      declare
         Result : constant String :=
           GPS.Kernel.Scripts.Execute_GPS_Shell_Command (Kernel, CL);
         pragma Unreferenced (Result);
      begin
         null;
      end;
   end Build_Target_Execute;

   --------------------
   -- Create_Content --
   --------------------

   overriding function Create_Content
     (Page : access GNATname_Page_Record;
      Wiz  : access Wizard_Record'Class) return Gtk.Widget.Gtk_Widget
   is
      Frame        : Gtk_Frame;
      Box          : Gtk_Box;
      Vbox         : Gtk_Vbox;
      Scrolled     : Gtk_Scrolled_Window;
      Button       : Gtk_Button;
      Names  : constant GNAT.Strings.String_List :=
        (1 => new String'(-"File pattern"));
   begin
      Gtk_New_Vbox (Vbox);

      Gtk_New
        (Page.Check_Button,
         -"Skip unit search and use standard naming convention");

      Page.Check_Button.Set_Active (True);

      Pack_Start (Vbox, Page.Check_Button, Expand => False, Fill => True);

      Gtk_New (Frame, "Search in");
      Set_Border_Width (Frame, 5);
      Pack_Start (Vbox, Frame, Expand => True, Fill => True);

      Gtk_New_Hbox (Page.Hbox);
      Add (Frame, Page.Hbox);

      Page.Hbox.Set_Sensitive (False);

      Page.Tree_View := GUI_Utils.Create_Tree_View
        (Column_Types => (0 => GType_String),
         Column_Names => Names);

      Gtk_New (Scrolled);
      Pack_Start (Page.Hbox, Scrolled, Expand => True, Fill => True);
      Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);
      Add (Scrolled, Page.Tree_View);

      Gtk_New_Vbox (Box, Homogeneous => False);
      Pack_Start (Page.Hbox, Box, Expand => False);

      Gtk_New_From_Stock (Button, Stock_Add);
      Pack_Start (Box, Button, Expand => False);

      Widget_Callback.Object_Connect
        (Button, Signal_Clicked, Add_Pattern'Access, Page.Tree_View);

      Gtk_New_From_Stock (Button, Stock_Remove);
      Pack_Start (Box, Button, Expand => False);

      Widget_Callback.Object_Connect
        (Button, Signal_Clicked, Remove_Pattern'Access, Page.Tree_View);

      Vbox.Show_All;

      Widget_Callback.Object_Connect
        (Page.Check_Button, Signal_Clicked, Toggle_Enabled'Access, Page.Hbox);

      Widget_Callback.Object_Connect
        (Page.Check_Button,
         Signal_Clicked,
         Update_Buttons_Sensitivity'Access,
         Wiz);

      Widget_Callback.Object_Connect
        (Page.Tree_View.Get_Model,
         Signal_Row_Inserted,
         Update_Buttons_Sensitivity'Access,
         Wiz);

      Widget_Callback.Object_Connect
        (Page.Tree_View.Get_Model,
         Signal_Row_Deleted,
         Update_Buttons_Sensitivity'Access,
         Wiz);

      return Gtk.Widget.Gtk_Widget (Vbox);
   end Create_Content;

   ----------------------
   -- Generate_Project --
   ----------------------

   overriding procedure Generate_Project
     (Page               : access GNATname_Page_Record;
      Kernel             : access GPS.Kernel.Kernel_Handle_Record'Class;
      Scenario_Variables : Scenario_Variable_Array;
      Project            : in out Project_Type;
      Changed            : in out Boolean)
   is
      pragma Unreferenced (Page, Kernel, Scenario_Variables, Project, Changed);
   begin
      null;
   end Generate_Project;

   -----------------
   -- Is_Complete --
   -----------------

   overriding function Is_Complete
     (Page : access GNATname_Page_Record) return String is
   begin
      if Page.Check_Button = null
        or else Page.Check_Button.Get_Active
        or else Page.Tree_View.Get_Model.Get_Iter_First /= Null_Iter
      then
         return "";
      else
         return -"List of file patters is empty";
      end if;
   end Is_Complete;

   ---------------
   -- Next_Page --
   ---------------

   overriding function Next_Page
     (Page : access GNATname_Page_Record;
      Wiz  : access Wizard_Record'Class) return Wizard_Page
   is
      This  : constant Wizard_Page := Wizard_Page (Page);
      Pages : constant Wizard_Pages_Array_Access := Wiz.Get_Pages;
   begin
      if not Page.Check_Button.Get_Active then
         for J in Pages'First .. Pages'Last - 2 loop
            if Pages (J) = This then
               --  Skip over next page ("Naming scheme")
               return Pages (J + 2);
            end if;
         end loop;
      end if;

      return null;
   end Next_Page;

   -------------------
   -- Project_Saved --
   -------------------

   overriding procedure Project_Saved
     (Page               : access GNATname_Page_Record;
      Kernel             : access GPS.Kernel.Kernel_Handle_Record'Class;
      Project            : Project_Type)
   is
      Extra : Unbounded_String;
      Iter  : Gtk_Tree_Iter;
      Model : constant Gtk.Tree_Model.Gtk_Tree_Model :=
        Page.Tree_View.Get_Model;
   begin
      if Page.Check_Button.Get_Active then
         return;
      end if;

      Append (Extra, "-P" & Project.Project_Path.Display_Full_Name);

      --  Append source directories
      declare
         Sources : constant GNAT.Strings.String_List_Access :=
           Project_Properties.Get_Current_Value
             (Kernel, Pkg => "", Name => "source_dirs");
      begin
         for J in Sources'Range loop
            Append (Extra, " -d" & Sources (J).all);
         end loop;
      end;

      Iter := Model.Get_Iter_First;

      --  Append search file patterns
      while Iter /= Null_Iter loop
         Append (Extra, " " & Model.Get_String (Iter, 0));
         Model.Next (Iter);
      end loop;

      declare
         Target : constant String :=
           Build_Target (Kernel_Handle (Kernel), "gnatname");
      begin
         Build_Target_Execute
           (Kernel      => Kernel_Handle (Kernel),
            Target_ID   => Target,
            Extra_Args  => To_String (Extra));
      end;
   end Project_Saved;

   --------------------
   -- Remove_Pattern --
   --------------------

   procedure Remove_Pattern (Widget : access Gtk_Widget_Record'Class) is
      Tree_View  : constant Gtk_Tree_View := Gtk_Tree_View (Widget);
      Tree_Store : constant Gtk_Tree_Store :=
        Gtk_Tree_Store (Tree_View.Get_Model);
      Model : Gtk_Tree_Model;
      Iter  : Gtk_Tree_Iter;
   begin
      Get_Selected (Get_Selection (Tree_View), Model, Iter);

      if Iter /= Null_Iter then
         Tree_Store.Remove (Iter);
      end if;
   end Remove_Pattern;

   --------------------
   -- Toggle_Enabled --
   --------------------

   procedure Toggle_Enabled (Widget : access Gtk_Widget_Record'Class) is
   begin
      Widget.Set_Sensitive ((Widget.Flags and Sensitive) = 0);
   end Toggle_Enabled;

end Creation_Wizard.GNATname;
