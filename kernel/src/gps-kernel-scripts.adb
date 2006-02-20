-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2003-2006                       --
--                            AdaCore                                --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
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

with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;

with GNAT.OS_Lib;             use GNAT.OS_Lib;

with Glib.Object;             use Glib.Object;
with Gtk.Label;               use Gtk.Label;
with Gtk.Menu;                use Gtk.Menu;
with Gtk.Menu_Item;           use Gtk.Menu_Item;
with Gtk.Widget;              use Gtk.Widget;
with Gtkada.Types;            use Gtkada.Types;

with Basic_Types;             use Basic_Types;
with Commands.Interactive;    use Commands, Commands.Interactive;
with Entities.Queries;        use Entities, Entities.Queries;
with GPS.Intl;                use GPS.Intl;
with GPS.Kernel.Actions;      use GPS.Kernel.Actions;
with GPS.Kernel.Console;      use GPS.Kernel.Console;
with GPS.Kernel.Contexts;     use GPS.Kernel.Contexts;
with GPS.Kernel.Custom;       use GPS.Kernel.Custom;
with GPS.Kernel.Hooks;        use GPS.Kernel.Hooks;
with GPS.Kernel.Modules;      use GPS.Kernel.Modules;
with GPS.Kernel.Project;      use GPS.Kernel.Project;
with GPS.Kernel.Properties;   use GPS.Kernel.Properties;
with GPS.Kernel.Task_Manager; use GPS.Kernel.Task_Manager;
with GPS.Kernel.Command_API;  use GPS.Kernel.Command_API;
with Histories;               use Histories;
with Interactive_Consoles;    use Interactive_Consoles;
with Language_Handlers;       use Language_Handlers;
with Prj.Ext;                 use Prj.Ext;
with Projects.Editor;         use Projects.Editor;
with Projects.Registry;       use Projects.Registry;
with Projects;                use Projects;
with String_List_Utils;
with String_Utils;            use String_Utils;
with System;                  use System;
with System.Assertions;
with Traces;                  use Traces;
with VFS;                     use VFS;

package body GPS.Kernel.Scripts is

   Me     : constant Debug_Handle := Create ("GPS.Kernel.Scripts");
   Ref_Me : constant Debug_Handle := Create ("Scripts.Ref", Off);

   Entity_Class_Name        : constant String := "Entity";
   File_Class_Name          : constant String := "File";
   Project_Class_Name       : constant String := "Project";
   Context_Class_Name       : constant String := "Context";
   File_Location_Class_Name : constant String := "FileLocation";
   Logger_Class_Name        : constant String := "Logger";

   -----------------------------------
   -- Data stored in class_instance --
   -----------------------------------

   type User_Data_Type is
     (Strings,
      Objects,
      Integers,
      Files,
      Contexts,
      Entities,
      Projects,
      File_Locations,
      Debug_Handles);

   type Scalar_Properties_Record (Typ : User_Data_Type) is
     new Instance_Property_Record
   with record
      case Typ is
         when Strings =>
            Str : GNAT.OS_Lib.String_Access;
         when Objects =>
            Obj : Glib.Object.GObject;
         when Integers =>
            Int : Integer;
         when Files =>
            File : Virtual_File;
         when Contexts =>
            Context : Selection_Context := No_Context;
         when Entities =>
            Entity  : Entity_Information;
         when Projects =>
            Project : Project_Type;
         when File_Locations =>
            Location : File_Location_Info;
         when Debug_Handles =>
            Handle   : Debug_Handle;
      end case;
   end record;

   type Scalar_Properties is access all Scalar_Properties_Record'Class;

   procedure Destroy (Prop : in out Scalar_Properties_Record);
   --  See inherited documentation

   -----------------
   -- Subprograms --
   -----------------
   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (Class_Instance_Record'Class, Class_Instance_Record_Access);

   type Scripting_Language_List is access Scripting_Language_Array;
   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (Scripting_Language_Array, Scripting_Language_List);

   procedure Free (Class : in out Class_Type);
   package Classes_Hash is new String_Hash (Class_Type, Free, No_Class);
   use Classes_Hash.String_Hash_Table;

   type Scripting_Data_Record is new Kernel_Scripting_Data_Record with record
      Scripting_Languages  : Scripting_Language_List :=
        new Scripting_Language_Array'(1 .. 0 => null);
      Classes              : Classes_Hash.String_Hash_Table.HTable;
      Entity_Class         : Class_Type := No_Class;
      File_Class           : Class_Type := No_Class;
      Project_Class        : Class_Type := No_Class;
      Context_Class        : Class_Type := No_Class;
      Area_Context_Class   : Class_Type := No_Class;
      File_Context_Class   : Class_Type := No_Class;
      File_Location_Class  : Class_Type := No_Class;
      Entity_Context_Class : Class_Type := No_Class;
      GUI_Class            : Class_Type := No_Class;
      Hook_Class           : Class_Type := No_Class;
   end record;
   type Scripting_Data is access all Scripting_Data_Record'Class;

   procedure On_Console_Destroy
     (Console : access Gtk_Widget_Record'Class;
      Subprogram : Subprogram_Type);
   --  Called when an interactive console is destroyed

   procedure Default_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for the default commands

   procedure Create_Entity_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for the "Entity" command

   procedure Create_File_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for the "File" command

   procedure Create_Project_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for the "Project" command

   procedure Create_Location_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for the "Location" command

   procedure Context_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for all context-related commands

   procedure Entity_Context_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for all entity_context-related commands

   procedure GUI_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for all GUI class commands

   procedure Logger_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for all Logger class commands

   procedure Set_Data (Instance : Class_Instance; File : Virtual_File);
   procedure Set_Data
     (Instance : Class_Instance; Project  : Project_Type);
   procedure Set_Data
     (Instance : Class_Instance; Location : File_Location_Info);
   procedure Set_Data
     (Instance : Class_Instance; Context  : Selection_Context);
   --  Set the data for an instance

   function On_Console_Input
     (Console : access Interactive_Console_Record'Class;
      Input   : String; User_Data : System.Address) return String;
   --  Called when input is available on a console

   procedure Console_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handles command related to GPS.Console

   function Get_Or_Create_Context
     (Script : access Scripting_Language_Record'Class;
      Class  : Class_Type;
      Context : GPS.Kernel.Selection_Context)
      return Class_Instance;
   --  Create a new instance representing the context. If such an instance
   --  already exists for that context, return the same one so that the user
   --  can store his own data in it.

   procedure Free_User_Data (Data : in out User_Data_List);
   --  Free the memory used by Data. Data is reset to null, and this doesn't
   --  free other user data in the list.

   function Get_Data
     (Instance : Class_Instance; Name : String) return User_Data_List;
   --  Return the user data with the given name, or null if there is none

   type CIR_Data_Type (Length : Natural) is record
      CIR : Class_Instance_Record_Access;
      Property_Name : String (1 .. Length);
   end record;
   package CIR_User_Data is new Glib.Object.User_Data
     (Data_Type => CIR_Data_Type);

   procedure On_Widget_Data_Destroyed (CIR : CIR_Data_Type);
   --  Called when the widget associated with CIR is destroyed

   Name_Cst       : aliased constant String := "name";
   Filename_Cst   : aliased constant String := "filename";
   File_Cst       : aliased constant String := "file";
   Line_Cst       : aliased constant String := "line";
   Col_Cst        : aliased constant String := "column";
   Shared_Lib_Cst : aliased constant String := "shared_lib";
   Module_Cst     : aliased constant String := "module";
   Xml_Cst        : aliased constant String := "xml";
   Action_Cst     : aliased constant String := "action";
   Prefix_Cst     : aliased constant String := "prefix";
   Sensitive_Cst  : aliased constant String := "sensitive";
   Force_Cst      : aliased constant String := "force";
   Value_Cst      : aliased constant String := "value";
   Recursive_Cst  : aliased constant String := "recursive";
   Default_Cst    : aliased constant String := "default_to_root";
   Nth_Cst        : aliased constant String := "nth";
   Project_Cmd_Parameters : constant Cst_Argument_List :=
     (1 => Name_Cst'Access);
   Insmod_Cmd_Parameters  : constant Cst_Argument_List :=
     (1 => Shared_Lib_Cst'Access, 2 => Module_Cst'Access);
   Body_Cmd_Parameters    : constant Cst_Argument_List :=
     (1 => Nth_Cst'Access);
   Entity_Cmd_Parameters   : constant Cst_Argument_List :=
     (Name_Cst'Access, File_Cst'Access, Line_Cst'Access, Col_Cst'Access);
   File_Cmd_Parameters     : constant Cst_Argument_List :=
     (1 => Name_Cst'Access);
   File_Project_Parameters : constant Cst_Argument_List :=
     (1 => Default_Cst'Access);
   Open_Cmd_Parameters     : constant Cst_Argument_List :=
     (1 => Filename_Cst'Access,
      2 => Force_Cst'Access);
   Location_Cmd_Parameters : constant Cst_Argument_List :=
     (1 => Filename_Cst'Access,
      2 => Line_Cst'Access,
      3 => Col_Cst'Access);
   Xml_Custom_Parameters : constant Cst_Argument_List :=
     (1 => Xml_Cst'Access);
   Exec_Action_Parameters : constant Cst_Argument_List :=
     (1 => Action_Cst'Access);
   Scenar_Var_Parameters : constant Cst_Argument_List :=
     (1 => Prefix_Cst'Access);
   Set_Sensitive_Parameters : constant Cst_Argument_List :=
     (1 => Sensitive_Cst'Access);
   Set_Scenario_Parameters : constant Cst_Argument_List :=
     (1 => Name_Cst'Access, 2 => Value_Cst'Access);

   On_Input_Cst     : aliased constant String := "on_input";
   On_Destroy_Cst   : aliased constant String := "on_destroy";
   Console_Constructor_Args : constant Cst_Argument_List :=
     (Name_Cst'Access, Force_Cst'Access,
      On_Input_Cst'Access, On_Destroy_Cst'Access);

   Text_Cst         : aliased constant String := "text";
   Console_Write_Args : constant Cst_Argument_List := (1 => Text_Cst'Access);

   -------------
   -- Destroy --
   -------------

   procedure Destroy (Prop : in out Instance_Property_Record) is
      pragma Unreferenced (Prop);
   begin
      null;
   end Destroy;

   ----------
   -- Free --
   ----------

   procedure Free (List : in out Instance_List) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Instance_Array, Instance_Array_Access);
   begin
      --  Class_Instance are automatically Finalized by the compiler
      Unchecked_Free (List.List);
   end Free;

   ---------
   -- Get --
   ---------

   function Get
     (List   : Instance_List;
      Script : access Scripting_Language_Record'Class) return Class_Instance
   is
      Tmp : constant Scripting_Language_Array :=
        Scripting_Data (Get_Kernel (Script).Scripts).Scripting_Languages.all;
   begin
      if List.List /= null then
         for T in Tmp'Range loop
            if Tmp (T) = Scripting_Language (Script) then
               return List.List (T);
            end if;
         end loop;
      end if;
      return No_Class_Instance;
   end Get;

   ---------
   -- Set --
   ---------

   procedure Set
     (List   : in out Instance_List;
      Script : access Scripting_Language_Record'Class;
      Inst   : Class_Instance)
   is
      Tmp : constant Scripting_Language_Array :=
        Scripting_Data (Get_Kernel (Script).Scripts).Scripting_Languages.all;
   begin
      if List.List = null then
         List.List := new Instance_Array (Tmp'Range);
      end if;

      for T in Tmp'Range loop
         if Tmp (T) = Scripting_Language (Script) then
            List.List (T) := Inst;
            exit;
         end if;
      end loop;
   end Set;

   ----------
   -- Free --
   ----------

   procedure Free (List : in out Callback_Data_List) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Callback_Data_Array, Callback_Data_List);
   begin
      if List /= null then
         for L in List'Range loop
            if List (L) /= null then
               Free (List (L));
            end if;
         end loop;
         Unchecked_Free (List);
      end if;
   end Free;

   ----------
   -- Free --
   ----------

   procedure Free (List : in out Instance_List_Access) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Instance_List, Instance_List_Access);
   begin
      if List /= null then
         Free (List.all);
         Unchecked_Free (List);
      end if;
   end Free;

   ---------
   -- Get --
   ---------

   function Get
     (Kernel : access Kernel_Handle_Record'Class;
      List   : Callback_Data_List;
      Script : access Scripting_Language_Record'Class)
      return Callback_Data_Access
   is
      Tmp : constant Scripting_Language_Array :=
        Scripting_Data (Kernel.Scripts).Scripting_Languages.all;
   begin
      if List /= null then
         for T in Tmp'Range loop
            if Tmp (T) = Scripting_Language (Script) then
               return List (T);
            end if;
         end loop;
      end if;
      return null;
   end Get;

   ---------
   -- Set --
   ---------

   procedure Set
     (Kernel : access Kernel_Handle_Record'Class;
      List   : in out Callback_Data_List;
      Script : access Scripting_Language_Record'Class;
      Data   : Callback_Data_Access)
   is
      Tmp : constant Scripting_Language_Array :=
        Scripting_Data (Kernel.Scripts).Scripting_Languages.all;
   begin
      if List = null then
         List := new Callback_Data_Array (Tmp'Range);
      end if;

      for T in Tmp'Range loop
         if Tmp (T) = Scripting_Language (Script) then
            if List (T) /= null
              and then List (T) /= Data
            then
               Free (List (T));
            end if;

            List (T) := Data;
            exit;
         end if;
      end loop;
   end Set;

   ----------
   -- Free --
   ----------

   procedure Free (Class : in out Class_Type) is
   begin
      Free (Class.Name);
   end Free;

   ----------
   -- Free --
   ----------

   procedure Free (Data : in out Callback_Data_Access) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Callback_Data'Class, Callback_Data_Access);
   begin
      if Data /= null then
         Free (Data.all);
         Unchecked_Free (Data);
      end if;
   end Free;

   ---------------------------------
   -- Register_Scripting_Language --
   ---------------------------------

   procedure Register_Scripting_Language
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class;
      Script : access Scripting_Language_Record'Class)
   is
      Tmp : constant Scripting_Language_Array :=
        Scripting_Data (Kernel.Scripts).Scripting_Languages.all;
   begin
      Unchecked_Free (Scripting_Data (Kernel.Scripts).Scripting_Languages);
      Scripting_Data (Kernel.Scripts).Scripting_Languages :=
        new Scripting_Language_Array'
          (Tmp & Scripting_Language (Script));
   end Register_Scripting_Language;

   -------------------------------
   -- Lookup_Scripting_Language --
   -------------------------------

   function Lookup_Scripting_Language
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class;
      Name   : String) return Scripting_Language
   is
      Tmp : constant Scripting_Language_List :=
        Scripting_Data (Kernel.Scripts).Scripting_Languages;
   begin
      for T in Tmp'Range loop
         if Equal (Get_Name (Tmp (T)), Name, False) then
            return Tmp (T);
         end if;
      end loop;

      return null;
   end Lookup_Scripting_Language;

   -----------------------------
   -- Get_Scripting_Languages --
   -----------------------------

   function Get_Scripting_Languages
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Scripting_Language_Array is
   begin
      return Scripting_Data (Kernel.Scripts).Scripting_Languages.all;
   end Get_Scripting_Languages;

   --------------------
   -- Block_Commands --
   --------------------

   procedure Block_Commands
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class;
      Block  : Boolean)
   is
      Tmp : constant Scripting_Language_List :=
        Scripting_Data (Kernel.Scripts).Scripting_Languages;
   begin
      for T in Tmp'Range loop
         Block_Commands (Tmp (T), Block);
      end loop;
   end Block_Commands;

   ----------------------
   -- Register_Command --
   ----------------------

   procedure Register_Command
     (Kernel        : access GPS.Kernel.Kernel_Handle_Record'Class;
      Command       : String;
      Minimum_Args  : Natural := 0;
      Maximum_Args  : Natural := 0;
      Handler       : Module_Command_Function;
      Class         : Class_Type := No_Class;
      Static_Method : Boolean := False)
   is
      Tmp : constant Scripting_Language_List :=
        Scripting_Data (Kernel.Scripts).Scripting_Languages;
   begin
      Assert (Me,
              Command /= Constructor_Method or else Class /= No_Class,
              "Constructors can only be specified for classes");
      Assert (Me, not Static_Method or else Class /= No_Class,
              "Static method can only be created for classes");

      for T in Tmp'Range loop
         Register_Command
           (Tmp (T), Command,
            Minimum_Args, Maximum_Args, Handler, Class, Static_Method);
      end loop;
   end Register_Command;

   ---------------
   -- New_Class --
   ---------------

   function New_Class
     (Kernel      : access GPS.Kernel.Kernel_Handle_Record'Class;
      Name        : String;
      Base        : Class_Type := No_Class) return Class_Type
   is
      Tmp   : constant Scripting_Language_List :=
        Scripting_Data (Kernel.Scripts).Scripting_Languages;
      Class : Class_Type;

   begin
      Class := Get (Scripting_Data (Kernel.Scripts).Classes, Name);

      if Class = No_Class then
         for T in Tmp'Range loop
            Register_Class (Tmp (T), Name, Base);
         end loop;

         Class := Class_Type'(Name => new String'(Name));
         Set (Scripting_Data (Kernel.Scripts).Classes, Name, Class);
      end if;

      return Class;
   end New_Class;

   --------------
   -- Get_Name --
   --------------

   function Get_Name (Class : Class_Type) return String is
   begin
      if Class.Name = null then
         return "";
      else
         return Class.Name.all;
      end if;
   end Get_Name;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data
     (Instance : Class_Instance; Entity : Entity_Information)
   is
      Script : constant Scripting_Language := Get_Script (Instance);
      Class  : constant Class_Type := Get_Entity_Class (Get_Kernel (Script));
   begin
      if not Is_Subclass (Instance, Class) then
         raise Invalid_Data;
      end if;

      Ref (Entity);
      Set_Property
        (Instance, Entity_Class_Name,
         Scalar_Properties_Record'(Typ => Entities, Entity => Entity));
   end Set_Data;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data
     (Instance : Class_Instance;
      Location : File_Location_Info)
   is
      Script : constant Scripting_Language := Get_Script (Instance);
      Class  : constant Class_Type :=
        Get_File_Location_Class (Get_Kernel (Script));
   begin
      if not Is_Subclass (Instance, Class) then
         raise Invalid_Data;
      end if;

      Set_Property
        (Instance, File_Location_Class_Name,
         Scalar_Properties_Record'
           (Typ => File_Locations, Location => Location));
   end Set_Data;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Data : Callback_Data; N : Positive) return Entity_Information
   is
      Class : constant Class_Type := Get_Entity_Class (Get_Kernel (Data));
      Inst  : constant Class_Instance := Nth_Arg
        (Callback_Data'Class (Data), N, Class);
      D     : User_Data_List;
   begin
      if Inst = No_Class_Instance then
         return null;
      end if;

      D := Get_Data (Inst, Entity_Class_Name);
      if D = null then
         return null;
      else
         return Scalar_Properties (D.Prop).Entity;
      end if;
   end Get_Data;

   --------------
   -- Get_Data --
   --------------

   function Get_Data (Data : Callback_Data; N : Positive)
      return File_Location_Info
   is
      Class : constant Class_Type :=
        Get_File_Location_Class (Get_Kernel (Data));
      Inst  : constant Class_Instance :=
        Nth_Arg (Callback_Data'Class (Data), N, Class);
      D     : User_Data_List;
   begin
      if Inst /= No_Class_Instance then
         D := Get_Data (Inst, File_Location_Class_Name);
      end if;

      if D = null then
         return No_File_Location;
      else
         return Scalar_Properties (D.Prop).Location;
      end if;
   end Get_Data;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data (Instance : Class_Instance; File : Virtual_File) is
      Script : constant Scripting_Language := Get_Script (Instance);
      Kernel : constant Kernel_Handle := Get_Kernel (Script);
      Class  : constant Class_Type := Get_File_Class (Kernel);

   begin
      if not Is_Subclass (Instance, Class) then
         raise Invalid_Data;
      end if;

      Set_Property
        (Instance, File_Class_Name,
         Scalar_Properties_Record'(Typ => Files, File => File));
   end Set_Data;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Data : Callback_Data; N : Positive) return Virtual_File
   is
      Class : constant Class_Type := Get_File_Class (Get_Kernel (Data));
      Inst  : constant Class_Instance :=
        Nth_Arg (Callback_Data'Class (Data), N, Class);
   begin
      return Get_Data (Inst);
   end Get_Data;

   --------------
   -- Get_Data --
   --------------

   function Get_Data (Instance : Class_Instance) return Virtual_File is
      Data   : User_Data_List;
   begin
      if Instance /= No_Class_Instance then
         Data := Get_Data (Instance, File_Class_Name);
      end if;

      if Data = null then
         return VFS.No_File;
      else
         return Scalar_Properties (Data.Prop).File;
      end if;
   end Get_Data;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data (Instance : Class_Instance; Project  : Project_Type) is
      Script : constant Scripting_Language := Get_Script (Instance);
      Class  : constant Class_Type := Get_Project_Class (Get_Kernel (Script));
   begin
      if not Is_Subclass (Instance, Class) then
         raise Invalid_Data;
      end if;

      Set_Property
        (Instance, Project_Class_Name,
         Scalar_Properties_Record'(Typ => Projects, Project => Project));
   end Set_Data;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Data : Callback_Data; N : Positive) return Project_Type
   is
      Class : constant Class_Type := Get_Project_Class (Get_Kernel (Data));
      Inst  : constant Class_Instance := Nth_Arg
        (Callback_Data'Class (Data), N, Class);
      Value : constant User_Data_List := Get_Data (Inst, Project_Class_Name);
   begin
      if Value = null then
         return No_Project;
      else
         return Scalar_Properties (Value.Prop).Project;
      end if;
   end Get_Data;

   -----------------------------
   -- Default_Command_Handler --
   -----------------------------

   procedure Default_Command_Handler
     (Data    : in out Callback_Data'Class;
      Command : String)
   is
      Kernel : constant Kernel_Handle := Get_Kernel (Data);
   begin
      if Command = "get_system_dir" then
         Set_Return_Value (Data, Get_System_Dir (Kernel));

      elsif Command = "get_home_dir" then
         Set_Return_Value (Data, Get_Home_Dir (Kernel));

      elsif Command = "insmod" then
         Name_Parameters (Data, Insmod_Cmd_Parameters);

         declare
            Shared  : constant String := Nth_Arg (Data, 1);
            Module  : constant String := Nth_Arg (Data, 2);
            Success : Boolean;
         begin
            Dynamic_Register_Module (Kernel, Shared, Module, Success);

            if Success then
               Set_Return_Value (Data, -"Module successfully loaded.");
            else
               Set_Return_Value (Data, -"Couldn't load module.");
            end if;
         end;

      elsif Command = "lsmod" then
         declare
            use type Module_List.List_Node;
            Current : Module_List.List_Node;
            List    : constant Module_List.List := List_Of_Modules (Kernel);

         begin
            Current := Module_List.First (List);

            Set_Return_Value_As_List (Data);

            while Current /= Module_List.Null_Node loop
               Set_Return_Value
                 (Data,
                  Module_Name (Module_List.Data (Current)));
               Current := Module_List.Next (Current);
            end loop;
         end;

      elsif Command = "supported_languages" then
         declare
            Langs : Argument_List := Known_Languages
              (Get_Language_Handler (Kernel), Sorted => True);
         begin
            Set_Return_Value_As_List (Data);

            for L in Langs'Range loop
               Set_Return_Value (Data, Langs (L).all);
            end loop;

            Free (Langs);
         end;

      elsif Command = "set_busy" then
         Push_State (Kernel, Processing);

      elsif Command = "unset_busy" then
         Pop_State (Kernel);

      elsif Command = "parse_xml" then
         Name_Parameters (Data, Xml_Custom_Parameters);
         declare
            Err : constant String :=
              GPS.Kernel.Custom.Add_Customization_String
                (Kernel, Nth_Arg (Data, 1),
                 From_File  => "<inline>",
                 Start_Line => 1);
         begin
            if Err /= "" then
               Set_Error_Msg (Data, Err);
            end if;
         end;

      elsif Command = "execute_action" then
         Name_Parameters (Data, Exec_Action_Parameters);

         declare
            Action      : constant Action_Record_Access := Lookup_Action
              (Kernel, Nth_Arg (Data, 1));
            Context     : constant Selection_Context :=
              Get_Current_Context (Kernel);
            Custom      : Command_Access;
            Args        : String_List_Access;
            Synchronous : constant Boolean := True;
         begin
            if Action = null then
               Set_Error_Msg (Data, -"No such registered action");
            elsif Context = No_Context
              or else not Filter_Matches (Action.Filter, Context)
            then
               Set_Error_Msg (Data, -"Invalid context for the action");
            else
               Args := new String_List (1 .. Number_Of_Arguments (Data) - 1);
               for Index in 2 .. Number_Of_Arguments (Data) loop
                  Args (Index - 1) := new String'(Nth_Arg (Data, Index));
               end loop;

               Custom := Create_Proxy
                 (Command => Action.Command,
                  Context => (Event       => null,
                              Context     => No_Context,
                              Synchronous => Synchronous,
                              Dir         => null,
                              Args        => Args,
                              Label       => new String'(Nth_Arg (Data, 1))));

               Launch_Background_Command
                 (Kernel, Custom, Destroy_On_Exit => True,
                  Active   => Synchronous,
                  Show_Bar => True,
                  Queue_Id => "");
            end if;
         end;

      elsif Command = "scenario_variables" then
         declare
            Vars : constant Scenario_Variable_Array :=
              Scenario_Variables (Kernel);
         begin
            for V in Vars'Range loop
               Set_Return_Value (Data, Value_Of (Vars (V)));
               Set_Return_Value_Key
                 (Data, External_Reference_Of (Vars (V)));
            end loop;
         end;

      elsif Command = "set_scenario_variable" then
         Name_Parameters (Data, Set_Scenario_Parameters);
         declare
            Name  : constant String := Nth_Arg (Data, 1);
            Value : constant String := Nth_Arg (Data, 2);
         begin
            Prj.Ext.Add (Name, Value);
            Run_Hook (Kernel, Variable_Changed_Hook);
         end;

      elsif Command = "scenario_variables_cmd_line" then
         Name_Parameters (Data, Scenar_Var_Parameters);
         declare
            Prefix : constant String := Nth_Arg (Data, 1, "");
         begin
            Set_Return_Value
              (Data, Scenario_Variables_Cmd_Line (Kernel, Prefix));
         end;

      elsif Command = "scenario_variables_values" then
         declare
            Vars : constant Scenario_Variable_Array :=
              Scenario_Variables (Kernel);
         begin
            for V in Vars'Range loop
               declare
                  use String_List_Utils.String_List;

                  Name : constant String := External_Reference_Of (Vars (V));
                  Values : String_List_Utils.String_List.List :=
                    Enum_Values_Of (Vars (V), Get_Registry (Kernel).all);
                  Iter   : String_List_Utils.String_List.List_Node :=
                    First (Values);
               begin
                  while Iter /= String_List_Utils.String_List.Null_Node loop
                     Set_Return_Value
                       (Data, String_List_Utils.String_List.Data (Iter));
                     Set_Return_Value_Key (Data, Name, True);
                     Iter := Next (Iter);
                  end loop;

                  Free (Values);
               end;
            end loop;
         end;
      end if;
   end Default_Command_Handler;

   -------------------------------------
   -- Create_Location_Command_Handler --
   -------------------------------------

   procedure Create_Location_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Kernel   : constant Kernel_Handle := Get_Kernel (Data);
      Location : File_Location_Info;

   begin
      if Command = Constructor_Method then
         Name_Parameters (Data, Location_Cmd_Parameters);

         declare
            File : constant Class_Instance  :=
              Nth_Arg (Data, 2, Get_File_Class (Kernel));
            L    : constant Integer := Nth_Arg (Data, 3);
            C    : constant Integer := Nth_Arg (Data, 4);
            Instance : constant Class_Instance :=
              Nth_Arg (Data, 1, Get_File_Location_Class (Kernel));
         begin
            Set_Data (Instance, File_Location_Info'(File, L, C));
         end;

      elsif Command = "line" then
         Location := Get_Data (Data, 1);
         Set_Return_Value (Data, Get_Line (Location));

      elsif Command = "column" then
         Location := Get_Data (Data, 1);
         Set_Return_Value (Data, Get_Column (Location));

      elsif Command = "file" then
         Location := Get_Data (Data, 1);

         declare
            File : constant Class_Instance := Get_File (Location);
         begin
            Set_Return_Value (Data, File);
         end;
      end if;
   end Create_Location_Command_Handler;

   -----------------------------------
   -- Create_Entity_Command_Handler --
   -----------------------------------

   procedure Create_Entity_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Kernel   : constant Kernel_Handle := Get_Kernel (Data);
      Entity   : Entity_Information;

   begin
      if Command = Constructor_Method then
         Name_Parameters (Data, Entity_Cmd_Parameters);

         declare
            Name     : constant String  := Nth_Arg (Data, 2);
            File     : constant Class_Instance  :=
              Nth_Arg (Data, 3, Get_File_Class (Kernel),
                       Default    => No_Class_Instance,
                       Allow_Null => True);
            L        : Integer := Nth_Arg (Data, 4, Default => 1);
            C        : Integer := Nth_Arg (Data, 5, Default => 1);
            Status   : Find_Decl_Or_Body_Query_Status;
            F        : Virtual_File;
            Source   : Source_File;

         begin
            if File = No_Class_Instance then
               --  ??? MANU Don't know what Handler to pass here, since we do
               --  not have enough information to recognize the context.
               Source := Get_Predefined_File
                 (Get_Database (Kernel),
                  Get_LI_Handler_By_Name
                    (Get_Language_Handler (Kernel), "Ada"));
               L      := Predefined_Line;
               C      := Predefined_Column;
            else
               F := Get_Data (File);
               Source := Get_Or_Create
                 (Get_Database (Kernel), F,
                  Get_LI_Handler (Get_Database (Kernel), F));
            end if;

            Find_Declaration_Or_Overloaded
              (Kernel      => Kernel,
               File        => Source,
               Entity_Name => Name,
               Line        => L,
               Column      => C,
               Ask_If_Overloaded => False,
               Entity      => Entity,
               Status      => Status);

            if Status /= Success and then Status /= Fuzzy_Match then
               Set_Error_Msg (Data, -"Entity not found");
            else
               declare
                  Instance : constant Class_Instance :=
                    Nth_Arg (Data, 1, Get_Entity_Class (Kernel));
               begin
                  Set_Data (Instance, Entity);
               end;
            end if;
         end;

      elsif Command = "name" then
         Entity := Get_Data (Data, 1);
         Set_Return_Value (Data, Get_Name (Entity).all);

      elsif Command = "declaration" then
         declare
            Location : File_Location;
         begin
            Entity := Get_Data (Data, 1);
            Location := Get_Declaration_Of (Entity);

            Set_Return_Value
              (Data, Create_File_Location
                 (Get_Script (Data),
                  File   => Create_File
                    (Get_Script (Data), Get_Filename (Get_File (Location))),
                  Line   => Get_Line (Location),
                  Column => Get_Column (Location)));
         end;

      elsif Command = "body" then
         Name_Parameters (Data, Body_Cmd_Parameters);
         declare
            Location : File_Location := Standard.Entities.No_File_Location;
            Count    : Integer := Nth_Arg (Data, 2, 1);
         begin
            Entity := Get_Data (Data, 1);
            while Count > 0 loop
               Find_Next_Body
                 (Entity, Current_Location => Location, Location => Location,
                  No_Location_If_First => True);
               Count := Count - 1;
            end loop;

            if Location /= Standard.Entities.No_File_Location then
               Set_Return_Value
                 (Data, Create_File_Location
                    (Get_Script (Data),
                     File   => Create_File
                       (Get_Script (Data), Get_Filename (Get_File (Location))),
                     Line   => Get_Line (Location),
                     Column => Get_Column (Location)));

            else
               Set_Error_Msg (Data, -"Body not found for the entity");
            end if;
         end;
      end if;
   end Create_Entity_Command_Handler;

   ---------------------------------
   -- Create_File_Command_Handler --
   ---------------------------------

   procedure Create_File_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Kernel   : constant Kernel_Handle := Get_Kernel (Data);
      Info     : Virtual_File;
   begin
      if Command = Constructor_Method then
         Name_Parameters (Data, File_Cmd_Parameters);
         declare
            Instance : constant Class_Instance :=
              Nth_Arg (Data, 1, Get_File_Class (Kernel));
         begin
            Set_Data (Instance, Create (Nth_Arg (Data, 2), Kernel));
         end;

      elsif Command = "name" then
         Info := Get_Data (Data, 1);
         Set_Return_Value (Data, Full_Name (Info).all);

      elsif Command = "project" then
         Name_Parameters (Data, File_Project_Parameters);
         Info := Get_Data (Data, 1);
         Set_Return_Value
           (Data, Create_Project
            (Get_Script (Data),
             Get_Project_From_File
             (Registry         => Project_Registry (Get_Registry (Kernel).all),
              Source_Filename   => Info,
              Root_If_Not_Found => Nth_Arg (Data, 2, True))));

      elsif Command = "directory" then
         Info := Get_Data (Data, 1);
         Set_Return_Value (Data, Dir_Name (Info).all);

      elsif Command = "language" then
         Info := Get_Data (Data, 1);
         Set_Return_Value
           (Data, Get_Language_From_File
              (Get_Language_Handler (Kernel), Info));

      elsif Command = "other_file" then
         declare
            Other   : Virtual_File;
            Project : Project_Type;
         begin
            Info := Get_Data (Data, 1);

            Project := Get_Project_From_File
              (Project_Registry (Get_Registry (Kernel).all),
               Info,
               Root_If_Not_Found => True);
            Other := Create
              (Other_File_Base_Name (Project, Info), Project,
               Use_Object_Path => False);

            Set_Return_Value (Data, Create_File (Get_Script (Data), Other));
         end;
      end if;
   end Create_File_Command_Handler;

   ------------------------------------
   -- Create_Project_Command_Handler --
   ------------------------------------

   procedure Create_Project_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Kernel : constant Kernel_Handle := Get_Kernel (Data);
      Instance : Class_Instance;
      Project  : Project_Type;

   begin
      if Command = "load" then
         Name_Parameters (Data, Open_Cmd_Parameters);
         Load_Project (Kernel,
                       Create (Normalize_Pathname (Nth_Arg (Data, 1))),
                       No_Save => Nth_Arg (Data, 2, False));
         Set_Return_Value
           (Data, Create_Project (Get_Script (Data), Get_Project (Kernel)));

      elsif Command = "recompute" then
         Recompute_View (Get_Kernel (Data));

      elsif Command = "root" then
         Set_Return_Value
           (Data, Create_Project (Get_Script (Data), Get_Project (Kernel)));

      else
         if Command = Constructor_Method then
            Name_Parameters (Data, Project_Cmd_Parameters);
            Project  := Get_Project_From_Name
              (Project_Registry (Get_Registry (Kernel).all),
               Get_String (Nth_Arg (Data, 2)));

            if Project = No_Project then
               Set_Error_Msg (Data, -"No such project: " & Nth_Arg (Data, 2));
            else
               Instance := Nth_Arg (Data, 1, Get_Project_Class (Kernel));
               Set_Data (Instance, Project);
            end if;

         elsif Command = "name" then
            Project := Get_Data (Data, 1);
            Set_Return_Value (Data, Project_Name (Project));

         elsif Command = "file" then
            Project := Get_Data (Data, 1);
            Set_Return_Value
              (Data,
               Create_File (Get_Script (Data), Project_Path (Project)));

         elsif Command = "ancestor_deps" then
            declare
               Iter : Imported_Project_Iterator;
               P    : Project_Type;
            begin
               Project := Get_Data (Data, 1);
               Set_Return_Value_As_List (Data);
               Iter := Find_All_Projects_Importing
                 (Project, Include_Self => True);

               loop
                  P := Current (Iter);
                  exit when P = No_Project;
                  Set_Return_Value
                    (Data, Create_Project (Get_Script (Data), P));
                  Next (Iter);
               end loop;
            end;

         elsif Command = "dependencies" then
            Name_Parameters (Data, (1 => Recursive_Cst'Access));
            declare
               Recursive : constant Boolean := Nth_Arg (Data, 2, False);
               Iter : Imported_Project_Iterator;
               P    : Project_Type;
            begin
               Project := Get_Data (Data, 1);
               Set_Return_Value_As_List (Data);
               Iter := Start
                 (Project, Recursive => True, Direct_Only => not Recursive);

               loop
                  P := Current (Iter);
                  exit when P = No_Project;
                  Set_Return_Value
                    (Data, Create_Project (Get_Script (Data), P));
                  Next (Iter);
               end loop;
            end;

         end if;
      end if;
   end Create_Project_Command_Handler;

   ------------------------------------
   -- Entity_Context_Command_Handler --
   ------------------------------------

   procedure Entity_Context_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Entity : constant Selection_Context := Get_Data (Data, 1);
   begin
      if Command = "entity" then
         Set_Return_Value
           (Data, Create_Entity (Get_Script (Data), Get_Entity (Entity)));
      end if;
   end Entity_Context_Command_Handler;

   -----------------------------
   -- Context_Command_Handler --
   -----------------------------

   procedure Context_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Kernel   : constant Kernel_Handle := Get_Kernel (Data);
      Context  : Selection_Context;
      Object   : Glib.Object.GObject;
      Menu     : Gtk.Menu.Gtk_Menu;
      L, C     : Integer := -1;
      Inst     : Class_Instance;

      procedure Recursive_Analyze_Menu
        (Depth : Natural;
         Menu  : Gtk_Menu);
      --  Recursively set the menu content as command result.
      --  Depth is the current depth of the analyzed menu
      --  Menu is the menu that will be analyzed

      ----------------------------
      -- Recursive_Analyze_Menu --
      ----------------------------

      procedure Recursive_Analyze_Menu
        (Depth : Natural;
         Menu  : Gtk_Menu)
      is
         List      : Gtk.Widget.Widget_List.Glist;
         Menu_Item : Gtk_Menu_Item;
         Label     : Gtk.Label.Gtk_Label;
         Submenu   : Gtk_Menu;
         use type Widget_List.Glist;
      begin
         List := Get_Children (Menu);

         while List /= Widget_List.Null_List loop
            Menu_Item := Gtk_Menu_Item (Widget_List.Get_Data (List));
            if Menu_Item /= null then
               Label := Gtk_Label
                 (Gtk.Menu_Item.Get_Child (Menu_Item));
               if Label /= null then
                  Set_Return_Value (Data,
                                    Natural'Image (Depth) & " - " &
                                    Get_Text (Label));
               else
                  Set_Return_Value (Data,
                                    Natural'Image (Depth) & " - " &
                                    "<separator>");
               end if;
               Submenu := Gtk_Menu (Get_Submenu (Menu_Item));
               if Submenu /= null then
                  Recursive_Analyze_Menu (Depth + 1, Submenu);
               end if;
            end if;
            List := Widget_List.Next (List);
         end loop;
      end Recursive_Analyze_Menu;

   begin
      if Command = Constructor_Method then
         Set_Error_Msg (Data, -"Cannot create an instance of this class");

      elsif Command = "start_line" then
         Context := Get_Data (Data, 1);
         Get_Area (Context, L, C);
         Set_Return_Value (Data, L);

      elsif Command = "end_line" then
         Context := Get_Data (Data, 1);
         Get_Area (Context, L, C);
         Set_Return_Value (Data, C);

      elsif Command = "file" then
         Context := Get_Data (Data, 1);
         if Has_File_Information (Context) then
            Set_Return_Value
              (Data, Create_File (Get_Script (Data),
               File_Information (Context)));
         else
            Set_Error_Msg (Data, -"No file information stored in the context");
         end if;

      elsif Command = "location" then
         Context := Get_Data (Data, 1);
         if Has_Line_Information (Context) then
            L := Line_Information (Context);
         end if;

         if Has_Column_Information (Context) then
            C := Column_Information (Context);
         end if;

         if Has_File_Information (Context) then
            Set_Return_Value
              (Data,
               Create_File_Location
                 (Get_Script (Data),
                  (Create_File (Get_Script (Data),
                   File_Information (Context))),
                  L,
                  C));
         else
            Set_Error_Msg
              (Data, -"No file information stored in the context");
         end if;

      elsif Command = "project" then
         Context := Get_Data (Data, 1);
         if Has_Project_Information (Context) then
            Set_Return_Value
              (Data,
               Create_Project (Get_Script (Data),
                 Project_Information (Context)));
         elsif Has_File_Information (Context) then
            --  Since the editor doesn't provide the project, we emulate it
            --  here
            Set_Return_Value
              (Data,
               Create_Project
                 (Get_Script (Data),
                  Get_Project_From_File
                    (Project_Registry (Get_Registry (Kernel).all),
                     File_Information (Context),
                     Root_If_Not_Found => False)));
         else
            Set_Error_Msg (Data, -"No project stored in the context");
         end if;

      elsif Command = "directory" then
         Context := Get_Data (Data, 1);
         if Has_Directory_Information (Context) then
            Set_Return_Value (Data, Directory_Information (Context));
         else
            Set_Error_Msg (Data, -"No directory stored in the context");
         end if;

      elsif Command = "location" then
         Context := Get_Data (Data, 1);

         if Has_Line_Information (Context) then
            L := Line_Information (Context);
         end if;

         if Has_Column_Information (Context) then
            C := Column_Information (Context);
         end if;

         if Has_File_Information (Context) then
            Set_Return_Value
              (Data,
               Create_File_Location
                 (Get_Script (Data),
                  (Create_File (Get_Script (Data),
                   File_Information (Context))),
                  L,
                  C));
         else
            Set_Error_Msg
              (Data, -"No file information stored in the context");
         end if;

      elsif Command = "current_context"
        or else Command = "contextual_context"
      then
         if Command = "current_context" then
            Context := Get_Current_Context (Kernel);
         else
            Context := Kernel.Last_Context_For_Contextual;
         end if;

         Inst := Create_Context (Get_Script (Data), Context);
         if Inst = No_Class_Instance then
            Set_Error_Msg (Data, -"No context available");
         else
            Set_Return_Value (Data, Inst);
         end if;

      elsif Command = "contextual_menu" then
         Context := Get_Data (Data, 1);
         Object := GObject (Get_Current_Focus_Widget (Kernel));

         if Object /= null then
            Gtk.Menu.Gtk_New (Menu);
            GPS.Kernel.Modules.Create_Contextual_Menu
              (Kernel, Object, Context, Menu);
            if Menu /= null then
               Set_Return_Value_As_List (Data);
               Recursive_Analyze_Menu (1, Menu);
            else
               Set_Return_Value (Data, "<empty menu>");
            end if;
            Destroy (Menu);
         else
            Set_Error_Msg (Data, -"Seems like no window has focus...");
         end if;
      end if;
   end Context_Command_Handler;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class) is
   begin
      Kernel.Scripts := new Scripting_Data_Record;
   end Initialize;

   --------------
   -- Finalize --
   --------------

   procedure Finalize
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
   is
      List : Scripting_Language_List :=
        Scripting_Data (Kernel.Scripts).Scripting_Languages;
   begin
      for L in List'Range loop
         Destroy (List (L));
      end loop;

      Unchecked_Free (List);
      --  Various classes instances stored in the kernel are freed when this
      --  table is freed.
      Classes_Hash.String_Hash_Table.Reset
        (Scripting_Data (Kernel.Scripts).Classes);
   end Finalize;

   -------------
   -- Destroy --
   -------------

   procedure Destroy (Script : access Scripting_Language_Record) is
      pragma Unreferenced (Script);
   begin
      null;
   end Destroy;

   ----------------------
   -- On_Console_Input --
   ----------------------

   function On_Console_Input
     (Console : access Interactive_Console_Record'Class;
      Input   : String; User_Data : System.Address) return String
   is
      function Convert is new Ada.Unchecked_Conversion
        (System.Address, Subprogram_Type);
      On_Input : constant Subprogram_Type := Convert (User_Data);
      Instance : constant Class_Instance :=
        Get_Instance (Get_Script (On_Input.all), Console);
      C : Callback_Data'Class := Create (Get_Script (On_Input.all), 2);
      Tmp : Boolean;
      pragma Unreferenced (Tmp);
   begin
      Set_Nth_Arg (C, 1, Instance);
      Set_Nth_Arg (C, 2, Input);
      Tmp := Execute (On_Input, C);
      Free (C);
      return "";   --  ??? Should this be the output of the command
   end On_Console_Input;

   ------------------------
   -- On_Console_Destroy --
   ------------------------

   procedure On_Console_Destroy
     (Console    : access Gtk_Widget_Record'Class;
      Subprogram : Subprogram_Type)
   is
      Inst  : constant Class_Instance :=
        Get_Instance (Get_Script (Subprogram.all), Console);
      Script : constant Scripting_Language := Get_Script (Subprogram.all);
   begin
      if Script /= null then
         declare
            C : Callback_Data'Class := Create (Script, 1);
            Tmp : Boolean;
            pragma Unreferenced (Tmp);
         begin
            Set_Nth_Arg (C, 1, Inst);
            Tmp := Execute (Subprogram, C);
            Free (C);
         end;
      end if;
   end On_Console_Destroy;

   -----------------------------
   -- Console_Command_Handler --
   -----------------------------

   procedure Console_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Kernel        : constant Kernel_Handle := Get_Kernel (Data);
      Console_Class : constant Class_Type := New_Class (Kernel, "Console");
      Inst      : constant Class_Instance := Nth_Arg (Data, 1, Console_Class);
      Console   : Interactive_Console;
   begin
      if Command = Constructor_Method then
         Name_Parameters (Data, Console_Constructor_Args);
         declare
            Title      : constant String := Nth_Arg (Data, 2, "");
            Force      : constant Boolean := Nth_Arg (Data, 3, False);
            On_Input   : constant Subprogram_Type := Nth_Arg (Data, 4, null);
            On_Destroy : constant Subprogram_Type := Nth_Arg (Data, 5, null);
         begin
            Console := Create_Interactive_Console
              (Kernel              => Get_Kernel (Data),
               Title               => Title,
               History             => History_Key ("console_" & Title),
               Create_If_Not_Exist => Title /= "Python"
                 and then Title /= "Shell",
               Force_Create        => Force);
            Enable_Prompt_Display (Console, Enable => Title = "Python");
            --   ??? If the console was already associated with an instance,
            --  we would lose that original instance and all data the user
            --  might have stored in it.
            Set_Data (Inst, Widget => GObject (Console));

            if Console /= null then
               if On_Input /= null then
                  Set_Command_Handler
                    (Console, On_Console_Input'Access, On_Input.all'Address);
               end if;

               if On_Destroy /= null then
                  Subprogram_Callback.Connect
                    (Console, "destroy", On_Console_Destroy'Access,
                     User_Data => On_Destroy);
               end if;
            end if;
         end;

      elsif Command = "write" then
         Name_Parameters (Data, Console_Write_Args);
         Console := Interactive_Console (GObject'(Get_Data (Inst)));
         if Console /= null then
            Insert
              (Console,
               Text   => Nth_Arg (Data, 2),
               Add_LF => False);
         end if;

      elsif Command = "clear" then
         Console := Interactive_Console (GObject'(Get_Data (Inst)));
         if Console /= null then
            Clear (Console);
         end if;

      elsif Command = "flush" then
         null;
         --  Do nothing, only needed for compatibility with Python's
         --  stdout stream

      elsif Command = "isatty" then
         Set_Return_Value (Data, False);

      elsif Command = "read" then
         Console := Interactive_Console (GObject'(Get_Data (Inst)));
         if Console /= null then
            Set_Return_Value (Data, Read (Console, Whole_Line => False));
         else
            Set_Error_Msg (Data, -"Console was closed by user");
         end if;

      elsif Command = "readline" then
         Console := Interactive_Console (GObject'(Get_Data (Inst)));
         if Console /= null then
            Set_Return_Value (Data, Read (Console, Whole_Line => True));
         else
            Set_Error_Msg (Data, -"Console was closed by user");
         end if;
      end if;
   end Console_Command_Handler;

   --------------------
   -- Logger_Handler --
   --------------------

   procedure Logger_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Kernel        : constant Kernel_Handle := Get_Kernel (Data);
      Name_Cst            : aliased constant String := "name";
      Message_Cst         : aliased constant String := "message";
      Active_Cst          : aliased constant String := "active";
      Condition_Cst       : aliased constant String := "condition";
      Error_Message_Cst   : aliased constant String := "error_message";
      Success_Message_Cst : aliased constant String := "success_message";
      Logger_Class       : constant Class_Type :=
        New_Class (Kernel, Logger_Class_Name);
      Inst        : constant Class_Instance := Nth_Arg (Data, 1, Logger_Class);
      Handle      : Debug_Handle;
   begin
      if Command = Constructor_Method then
         Name_Parameters (Data, (1 => Name_Cst'Unchecked_Access));
         Set_Property
           (Inst, Logger_Class_Name, Scalar_Properties_Record'
              (Typ => Debug_Handles, Handle => Create (Nth_Arg (Data, 2))));

      elsif Command = "log" then
         Name_Parameters (Data, (1 => Message_Cst'Unchecked_Access));
         Handle :=
           Scalar_Properties (Get_Data (Inst, Logger_Class_Name).Prop).Handle;
         Trace (Handle, Nth_Arg (Data, 2));

      elsif Command = "set_active" then
         Name_Parameters (Data, (1 => Active_Cst'Unchecked_Access));
         Handle :=
           Scalar_Properties (Get_Data (Inst, Logger_Class_Name).Prop).Handle;
         Set_Active
           (Handle, Nth_Arg (Data, 2));

      elsif Command = "check" then
         Name_Parameters (Data, (1 => Condition_Cst'Unchecked_Access,
                                 2 => Error_Message_Cst'Unchecked_Access,
                                 3 => Success_Message_Cst'Unchecked_Access));
         begin
            Handle := Scalar_Properties
              (Get_Data (Inst, Logger_Class_Name).Prop).Handle;
            Assert (Handle,
                    Condition          => Nth_Arg (Data, 2),
                    Error_Message      => Nth_Arg (Data, 3),
                    Message_If_Success => Nth_Arg (Data, 4, ""));
         exception
            when System.Assertions.Assert_Failure =>
               Set_Error_Msg (Data, "Assertion error: " & Nth_Arg (Data, 3));
         end;
      end if;
   end Logger_Handler;

   --------------------------------------
   -- Register_Default_Script_Commands --
   --------------------------------------

   procedure Register_Default_Script_Commands
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
   is
      Console_Class : constant Class_Type :=
        New_Class (Kernel, "Console", Base => Get_GUI_Class (Kernel));
      Logger  : constant Class_Type := New_Class (Kernel, Logger_Class_Name);
   begin
      Register_Command
        (Kernel, Constructor_Method, 1, 1, Logger_Handler'Access, Logger);
      Register_Command
        (Kernel, "log", 1, 1, Logger_Handler'Access, Logger);
      Register_Command
        (Kernel, "set_active", 1, 1, Logger_Handler'Access, Logger);
      Register_Command
        (Kernel, "check", 2, 3, Logger_Handler'Access, Logger);

      Register_Command
        (Kernel, Constructor_Method,
         Minimum_Args => 0,
         Maximum_Args => 4,
         Class        => Console_Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Kernel, "write",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Class        => Console_Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Kernel, "clear",
         Class        => Console_Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Kernel, "flush",
         Class        => Console_Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Kernel, "isatty",
         Class        => Console_Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Kernel, "read",
         Class        => Console_Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Kernel, "readline",
         Class        => Console_Class,
         Handler      => Console_Command_Handler'Access);

      Register_Command
        (Kernel, "get_system_dir",
         Handler => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "get_home_dir",
         Handler => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "insmod",
         Minimum_Args => 2,
         Maximum_Args => 2,
         Handler      => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "lsmod",
         Handler => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "supported_languages",
         Handler => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "execute_action",
         Minimum_Args => 1,
         Maximum_Args => Integer'Last,
         Handler      => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "parse_xml",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "set_busy",
         Handler      => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "unset_busy",
         Handler      => Default_Command_Handler'Access);

      Register_Command
        (Kernel, "scenario_variables",
         Class         => Get_Project_Class (Kernel),
         Static_Method => True,
         Handler       => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "set_scenario_variable",
         Class         => Get_Project_Class (Kernel),
         Minimum_Args  => 2,
         Maximum_Args  => 2,
         Static_Method => True,
         Handler       => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "scenario_variables_cmd_line",
         Minimum_Args => 0,
         Maximum_Args => 1,
         Class         => Get_Project_Class (Kernel),
         Static_Method => True,
         Handler       => Default_Command_Handler'Access);
      Register_Command
        (Kernel, "scenario_variables_values",
         Minimum_Args => 0,
         Maximum_Args => 0,
         Class         => Get_Project_Class (Kernel),
         Static_Method => True,
         Handler       => Default_Command_Handler'Access);

      Register_Command
        (Kernel, Constructor_Method,
         Minimum_Args => 1,
         Maximum_Args => 1,
         Class        => Get_File_Class (Kernel),
         Handler      => Create_File_Command_Handler'Access);
      Register_Command
        (Kernel, "language",
         Class        => Get_File_Class (Kernel),
         Handler      => Create_File_Command_Handler'Access);
      Register_Command
        (Kernel, "name",
         Class        => Get_File_Class (Kernel),
         Handler      => Create_File_Command_Handler'Access);
      Register_Command
        (Kernel, "directory",
         Class        => Get_File_Class (Kernel),
         Handler      => Create_File_Command_Handler'Access);
      Register_Command
        (Kernel, "other_file",
         Class        => Get_File_Class (Kernel),
         Handler      => Create_File_Command_Handler'Access);
      Register_Command
        (Kernel, "project",
         Minimum_Args => 0,
         Maximum_Args => 1,
         Class        => Get_File_Class (Kernel),
         Handler      => Create_File_Command_Handler'Access);

      Register_Command
        (Kernel, Constructor_Method,
         Minimum_Args => 1,
         Maximum_Args => 4,
         Class        => Get_Entity_Class (Kernel),
         Handler      => Create_Entity_Command_Handler'Access);
      Register_Command
        (Kernel, "name",
         Class        => Get_Entity_Class (Kernel),
         Handler      => Create_Entity_Command_Handler'Access);
      Register_Command
        (Kernel, "declaration",
         Class        => Get_Entity_Class (Kernel),
         Handler      => Create_Entity_Command_Handler'Access);
      Register_Command
        (Kernel, "body",
         Minimum_Args => 0,
         Maximum_Args => 1,
         Class        => Get_Entity_Class (Kernel),
         Handler      => Create_Entity_Command_Handler'Access);

      Register_Command
        (Kernel, Constructor_Method,
         Minimum_Args => 3,
         Maximum_Args => 3,
         Class        => Get_File_Location_Class (Kernel),
         Handler      => Create_Location_Command_Handler'Access);
      Register_Command
        (Kernel, "line",
         Class         => Get_File_Location_Class (Kernel),
         Handler       => Create_Location_Command_Handler'Access);
      Register_Command
        (Kernel, "column",
         Class         => Get_File_Location_Class (Kernel),
         Handler       => Create_Location_Command_Handler'Access);
      Register_Command
        (Kernel, "file",
         Class        => Get_File_Location_Class (Kernel),
         Handler      => Create_Location_Command_Handler'Access);

      Register_Command
        (Kernel, Constructor_Method,
         Minimum_Args => 1,
         Maximum_Args => 1,
         Class        => Get_Project_Class (Kernel),
         Handler      => Create_Project_Command_Handler'Access);
      Register_Command
        (Kernel, "root",
         Class         => Get_Project_Class (Kernel),
         Static_Method => True,
         Handler       => Create_Project_Command_Handler'Access);
      Register_Command
        (Kernel, "recompute",
         Class         => Get_Project_Class (Kernel),
         Static_Method => True,
         Handler       => Create_Project_Command_Handler'Access);
      Register_Command
        (Kernel, "load",
         Minimum_Args  => 1,
         Maximum_Args  => 2,
         Class         => Get_Project_Class (Kernel),
         Static_Method => True,
         Handler       => Create_Project_Command_Handler'Access);
      Register_Command
        (Kernel, "name",
         Class        => Get_Project_Class (Kernel),
         Handler      => Create_Project_Command_Handler'Access);
      Register_Command
        (Kernel, "file",
         Class        => Get_Project_Class (Kernel),
         Handler      => Create_Project_Command_Handler'Access);
      Register_Command
        (Kernel, "ancestor_deps",
         Class        => Get_Project_Class (Kernel),
         Handler      => Create_Project_Command_Handler'Access);
      Register_Command
        (Kernel, "dependencies",
         Class        => Get_Project_Class (Kernel),
         Minimum_Args => 0,
         Maximum_Args => 1,
         Handler      => Create_Project_Command_Handler'Access);

      if Active (Testsuite_Handle) then
         Register_Command
           (Kernel, "contextual_menu",
            Class        => Get_Context_Class (Kernel),
            Handler      => Context_Command_Handler'Access);
      end if;

      Register_Command
        (Kernel, Constructor_Method,
         Class        => Get_File_Context_Class (Kernel),
         Handler      => Context_Command_Handler'Access);
      Register_Command
        (Kernel, "file",
         Class        => Get_File_Context_Class (Kernel),
         Handler      => Context_Command_Handler'Access);
      Register_Command
        (Kernel, "project",
         Class        => Get_File_Context_Class (Kernel),
         Handler      => Context_Command_Handler'Access);
      Register_Command
        (Kernel, "directory",
         Class        => Get_File_Context_Class (Kernel),
         Handler      => Context_Command_Handler'Access);
      Register_Command
        (Kernel, "location",
         Class        => Get_File_Context_Class (Kernel),
         Handler      => Context_Command_Handler'Access);

      Register_Command
        (Kernel, Constructor_Method,
         Class        => Get_Area_Context_Class (Kernel),
         Handler      => Context_Command_Handler'Access);
      Register_Command
        (Kernel, "start_line",
         Class        => Get_Area_Context_Class (Kernel),
         Handler      => Context_Command_Handler'Access);
      Register_Command
        (Kernel, "end_line",
         Class        => Get_Area_Context_Class (Kernel),
         Handler      => Context_Command_Handler'Access);

      Register_Command
        (Kernel, Constructor_Method,
         Class        => Get_Entity_Context_Class (Kernel),
         Handler      => Context_Command_Handler'Access);
      Register_Command
        (Kernel, "entity",
         Class        => Get_Entity_Context_Class (Kernel),
         Handler      => Entity_Context_Command_Handler'Access);

      Register_Command
        (Kernel, "current_context",
         Handler      => Context_Command_Handler'Access);
      Register_Command
        (Kernel, "contextual_context",
         Handler      => Context_Command_Handler'Access);

      Register_Command
        (Kernel, Constructor_Method,
         Class   => Get_GUI_Class (Kernel),
         Handler => GUI_Command_Handler'Access);
      Register_Command
        (Kernel, "set_sensitive",
         Maximum_Args => 1,
         Class        => Get_GUI_Class (Kernel),
         Handler      => GUI_Command_Handler'Access);
      Register_Command
        (Kernel, "is_sensitive",
         Maximum_Args => 0,
         Class        => Get_GUI_Class (Kernel),
         Handler      => GUI_Command_Handler'Access);
      Register_Command
        (Kernel, "destroy",
         Class        => Get_GUI_Class (Kernel),
         Handler      => GUI_Command_Handler'Access);
      Register_Command
        (Kernel, "hide",
         Class        => Get_GUI_Class (Kernel),
         Handler      => GUI_Command_Handler'Access);
      Register_Command
        (Kernel, "show",
         Class        => Get_GUI_Class (Kernel),
         Handler      => GUI_Command_Handler'Access);

      GPS.Kernel.Properties.Register_Script_Commands (Kernel);
      GPS.Kernel.Command_API.Register_Commands (Kernel);
   end Register_Default_Script_Commands;

   ----------------------
   -- Get_Entity_Class --
   ----------------------

   function Get_Entity_Class
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).Entity_Class = No_Class then
         Scripting_Data (Kernel.Scripts).Entity_Class := New_Class
           (Kernel, Entity_Class_Name);
      end if;

      return Scripting_Data (Kernel.Scripts).Entity_Class;
   end Get_Entity_Class;

   --------------------
   -- Get_File_Class --
   --------------------

   function Get_File_Class
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).File_Class = No_Class then
         Scripting_Data (Kernel.Scripts).File_Class := New_Class
           (Kernel, File_Class_Name);
      end if;

      return Scripting_Data (Kernel.Scripts).File_Class;
   end Get_File_Class;

   -----------------------
   -- Get_Project_Class --
   -----------------------

   function Get_Project_Class
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).Project_Class = No_Class then
         Scripting_Data (Kernel.Scripts).Project_Class := New_Class
           (Kernel, Project_Class_Name);
      end if;

      return Scripting_Data (Kernel.Scripts).Project_Class;
   end Get_Project_Class;

   -----------------------------
   -- Get_File_Location_Class --
   -----------------------------

   function Get_File_Location_Class
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).File_Location_Class = No_Class then
         Scripting_Data (Kernel.Scripts).File_Location_Class := New_Class
           (Kernel, File_Location_Class_Name);
      end if;

      return Scripting_Data (Kernel.Scripts).File_Location_Class;
   end Get_File_Location_Class;

   -------------------------------
   -- Execute_Command_With_Args --
   -------------------------------

   function Execute_Command_With_Args
     (Script             : access Scripting_Language_Record;
      Command            : String;
      Args               : GNAT.OS_Lib.Argument_List) return String
   is
      pragma Unreferenced (Script, Command, Args);
   begin
      raise Program_Error;
      return "";
   end Execute_Command_With_Args;

   -------------------------------
   -- Execute_GPS_Shell_Command --
   -------------------------------

   function Execute_GPS_Shell_Command
     (Kernel  : access GPS.Kernel.Kernel_Handle_Record'Class;
      Command : String) return String
   is
      Errors : aliased Boolean;
   begin
      return Execute_Command
        (Lookup_Scripting_Language (Kernel, GPS_Shell_Name),
         Command, null, True, True, Errors'Unchecked_Access);
   end Execute_GPS_Shell_Command;

   -------------------------------
   -- Execute_GPS_Shell_Command --
   -------------------------------

   procedure Execute_GPS_Shell_Command
     (Kernel  : access GPS.Kernel.Kernel_Handle_Record'Class;
      Command : String;
      Args    : GNAT.OS_Lib.Argument_List)
   is
      Output : constant String := Execute_Command_With_Args
        (Lookup_Scripting_Language (Kernel, GPS_Shell_Name),
         Command, Args);
      pragma Unreferenced (Output);
   begin
      null;
   end Execute_GPS_Shell_Command;

   -------------------------------
   -- Execute_GPS_Shell_Command --
   -------------------------------

   function Execute_GPS_Shell_Command
     (Kernel  : access GPS.Kernel.Kernel_Handle_Record'Class;
      Command : String;
      Args    : GNAT.OS_Lib.Argument_List) return String is
   begin
      return Execute_Command_With_Args
        (Lookup_Scripting_Language (Kernel, GPS_Shell_Name),
         Command, Args);
   end Execute_GPS_Shell_Command;

   -------------------------------
   -- Execute_GPS_Shell_Command --
   -------------------------------

   procedure Execute_GPS_Shell_Command
     (Kernel  : access GPS.Kernel.Kernel_Handle_Record'Class;
      Command : String)
   is
      Errors : aliased Boolean;
      Str : constant String := Execute_Command
        (Lookup_Scripting_Language (Kernel, GPS_Shell_Name),
         Command, null, True, True, Errors'Unchecked_Access);
      pragma Unreferenced (Str);
   begin
      null;
   end Execute_GPS_Shell_Command;

   ---------------------
   -- Execute_Command --
   ---------------------

   function Execute_Command
     (Script             : access Scripting_Language_Record;
      Command            : String;
      Console            : Interactive_Consoles.Interactive_Console := null;
      Hide_Output        : Boolean := False;
      Show_Command       : Boolean := True;
      Errors             : access Boolean) return String is
   begin
      Execute_Command
        (Scripting_Language (Script),
         Command, Console, Hide_Output, Show_Command, Errors.all);
      return "";
   end Execute_Command;

   -------------
   -- Nth_Arg --
   -------------

   function Nth_Arg
     (Data    : Callback_Data;
      N       : Positive;
      Default : Subprogram_Type) return Subprogram_Type is
   begin
      return Nth_Arg (Callback_Data'Class (Data), N);
   exception
      when No_Such_Parameter =>
         return Default;
   end Nth_Arg;

   -------------
   -- Nth_Arg --
   -------------

   function Nth_Arg
     (Data : Callback_Data; N : Positive; Default : String)
      return String is
   begin
      return Nth_Arg (Callback_Data'Class (Data), N);
   exception
      when No_Such_Parameter =>
         return Default;
   end Nth_Arg;

   -------------
   -- Nth_Arg --
   -------------

   function Nth_Arg
     (Data : Callback_Data; N : Positive; Default : Integer)
      return Integer is
   begin
      return Nth_Arg (Callback_Data'Class (Data), N);
   exception
      when No_Such_Parameter =>
         return Default;
   end Nth_Arg;

   -------------
   -- Nth_Arg --
   -------------

   function Nth_Arg
     (Data : Callback_Data; N : Positive; Default : Boolean)
      return Boolean is
   begin
      return Nth_Arg (Callback_Data'Class (Data), N);
   exception
      when No_Such_Parameter =>
         return Default;
   end Nth_Arg;

   -------------
   -- Nth_Arg --
   -------------

   function Nth_Arg
     (Data    : Callback_Data;
      N       : Positive;
      Class   : Class_Type;
      Default : Class_Instance;
      Allow_Null : Boolean := False)
      return Class_Instance is
   begin
      return Nth_Arg (Callback_Data'Class (Data), N, Class, Allow_Null);
   exception
      when No_Such_Parameter =>
         return Default;
   end Nth_Arg;

   ----------------
   -- Get_Kernel --
   ----------------

   function Get_Kernel (Data : Callback_Data)
      return GPS.Kernel.Kernel_Handle is
   begin
      return Get_Kernel (Get_Script (Callback_Data'Class (Data)));
   end Get_Kernel;

   -------------------
   -- Create_Entity --
   -------------------

   function Create_Entity
     (Script : access Scripting_Language_Record'Class;
      Entity : Entity_Information) return Class_Instance
   is
      Instance : Class_Instance;
   begin
      if Entity = null then
         return No_Class_Instance;
      else
         Instance := New_Instance
           (Script, Get_Entity_Class (Get_Kernel (Script)));
         Set_Data (Instance, Entity);
         return Instance;
      end if;
   end Create_Entity;

   -----------------
   -- Create_File --
   -----------------

   function Create_File
     (Script : access Scripting_Language_Record'Class;
      File   : Virtual_File) return Class_Instance
   is
      Instance : constant Class_Instance := New_Instance
        (Script, Get_File_Class (Get_Kernel (Script)));
   begin
      Set_Data (Instance, File);
      return Instance;
   end Create_File;

   --------------------
   -- Create_Project --
   --------------------

   function Create_Project
     (Script  : access Scripting_Language_Record'Class;
      Project : Project_Type) return Class_Instance
   is
      Instance : Class_Instance := No_Class_Instance;
   begin
      if Project /= No_Project then
         Instance := New_Instance
           (Script, Get_Project_Class (Get_Kernel (Script)));
         Set_Data (Instance, Project);
      end if;
      return Instance;
   end Create_Project;

   --------------------------
   -- Create_File_Location --
   --------------------------

   function Create_File_Location
     (Script : access Scripting_Language_Record'Class;
      File   : Class_Instance;
      Line   : Natural;
      Column : Natural) return Class_Instance
   is
      Instance : constant Class_Instance := New_Instance
        (Script, Get_File_Location_Class (Get_Kernel (Script)));
      Info     : constant File_Location_Info := (File, Line, Column);

   begin
      Set_Data (Instance, Info);
      return Instance;
   end Create_File_Location;

   --------------
   -- Get_File --
   --------------

   function Get_File (Location : File_Location_Info) return Class_Instance is
   begin
      return Location.File;
   end Get_File;

   --------------
   -- Get_Line --
   --------------

   function Get_Line (Location : File_Location_Info) return Integer is
   begin
      return Location.Line;
   end Get_Line;

   ----------------
   -- Get_Column --
   ----------------

   function Get_Column (Location : File_Location_Info) return Integer is
   begin
      return Location.Column;
   end Get_Column;

   -----------------------
   -- Get_Context_Class --
   -----------------------

   function Get_Context_Class
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).Context_Class = No_Class then
         Scripting_Data (Kernel.Scripts).Context_Class := New_Class
           (Kernel, Context_Class_Name);
      end if;

      return Scripting_Data (Kernel.Scripts).Context_Class;
   end Get_Context_Class;

   --------------------
   -- Get_Hook_Class --
   --------------------

   function Get_Hook_Class
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).Hook_Class = No_Class then
         Scripting_Data (Kernel.Scripts).Hook_Class := New_Class
           (Kernel, "Hook");
      end if;

      return Scripting_Data (Kernel.Scripts).Hook_Class;
   end Get_Hook_Class;

   ----------------------------
   -- Get_Area_Context_Class --
   ----------------------------

   function Get_Area_Context_Class
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).Area_Context_Class = No_Class then
         Scripting_Data (Kernel.Scripts).Area_Context_Class := New_Class
           (Kernel,
            "AreaContext",
            Base => Get_File_Context_Class (Kernel));
      end if;

      return Scripting_Data (Kernel.Scripts).Area_Context_Class;
   end Get_Area_Context_Class;

   --------------------
   -- Create_Context --
   --------------------

   function Create_Context
     (Script  : access Scripting_Language_Record'Class;
      Context : GPS.Kernel.Selection_Context) return Class_Instance is
   begin
      if Context = No_Context then
         Trace (Me, "Null context passed to Create_Context");
         return No_Class_Instance;

      elsif Has_Area_Information (Context) then
         return Get_Or_Create_Context
           (Script,
            Get_Area_Context_Class (Get_Kernel (Script)),
            Context);

      elsif Has_Entity_Name_Information (Context) then
         return Get_Or_Create_Context
           (Script,
            Get_Entity_Context_Class (Get_Kernel (Script)),
            Context);

      elsif Has_File_Information (Context) then
         return Get_Or_Create_Context
           (Script,
            Get_File_Context_Class (Get_Kernel (Script)),
            Context);

      else
         Trace (Me, "Context type is not supported by GPS");
         return Get_Or_Create_Context
           (Script,
            Get_Context_Class (Get_Kernel (Script)),
            Context);
      end if;
   end Create_Context;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Instance : Class_Instance) return GPS.Kernel.Selection_Context
   is
      Value : constant User_Data_List :=
        Get_Data (Instance, Context_Class_Name);
   begin
      if Value = null then
         return No_Context;
      else
         return Scalar_Properties (Value.Prop).Context;
      end if;
   end Get_Data;

   --------------
   -- Get_Data --
   --------------

   function Get_Data (Data : Callback_Data; N : Positive)
                      return GPS.Kernel.Selection_Context is
   begin
      return Get_Data
        (Nth_Arg (Callback_Data'Class (Data), N,
                  Get_Context_Class (Get_Kernel (Data))));
   end Get_Data;

   ----------------------------
   -- Get_File_Context_Class --
   ----------------------------

   function Get_File_Context_Class
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).File_Context_Class = No_Class then
         Scripting_Data (Kernel.Scripts).File_Context_Class := New_Class
           (Kernel,
            "FileContext",
            Base => Get_Context_Class (Kernel));
      end if;

      return Scripting_Data (Kernel.Scripts).File_Context_Class;
   end Get_File_Context_Class;

   ------------------------------
   -- Get_Entity_Context_Class --
   ------------------------------

   function Get_Entity_Context_Class
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).Entity_Context_Class = No_Class then
         Scripting_Data (Kernel.Scripts).Entity_Context_Class := New_Class
           (Kernel,
            "EntityContext",
            Base => Get_File_Context_Class (Kernel));
      end if;

      return Scripting_Data (Kernel.Scripts).Entity_Context_Class;
   end Get_Entity_Context_Class;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data
     (Instance : Class_Instance;
      Context  : Selection_Context)
   is
      Script : constant Scripting_Language := Get_Script (Instance);
      Class  : constant Class_Type :=
        Get_Context_Class (Get_Kernel (Script));
   begin
      if not Is_Subclass (Instance, Class) then
         raise Invalid_Data;
      end if;

      Set_Property
        (Instance, Context_Class_Name,
         Scalar_Properties_Record'(Typ => Contexts, Context => Context));
   end Set_Data;

   ---------------------------
   -- Get_Or_Create_Context --
   ---------------------------

   function Get_Or_Create_Context
     (Script : access Scripting_Language_Record'Class;
      Class  : Class_Type;
      Context : GPS.Kernel.Selection_Context)
      return Class_Instance
   is
      Instance : Class_Instance;
   begin
      if Context.Data.Data.Instances = null then
         Context.Data.Data.Instances := new Instance_List'
           (Instance_List_Base with List => null);
      end if;

      Instance := Get
        (Instance_List (Context.Data.Data.Instances.all), Script);
      if Instance = No_Class_Instance then
         Trace (Me, "Create a new instance for the current context");
         Instance := New_Instance (Script, Class);
         Set_Data (Instance, Context);
         Set (Instance_List (Context.Data.Data.Instances.all),
              Script, Instance);
      end if;

      return Instance;
   end Get_Or_Create_Context;

   ----------
   -- Free --
   ----------

   procedure Free (Subprogram : in out Subprogram_Type) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Subprogram_Record'Class, Subprogram_Type);
   begin
      if Subprogram /= null then
         Free (Subprogram.all);
         Unchecked_Free (Subprogram);
      end if;
   end Free;

   -------------------
   -- Get_GUI_Class --
   -------------------

   function Get_GUI_Class
     (Kernel : access Kernel_Handle_Record'Class) return Class_Type is
   begin
      if Scripting_Data (Kernel.Scripts).GUI_Class = No_Class then
         Scripting_Data (Kernel.Scripts).GUI_Class := New_Class
           (Kernel, GUI_Class_Name);
      end if;

      return Scripting_Data (Kernel.Scripts).GUI_Class;
   end Get_GUI_Class;

   -------------------------
   -- GUI_Command_Handler --
   -------------------------

   procedure GUI_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Class : constant Class_Type := Get_GUI_Class (Get_Kernel (Data));
      Inst  : constant Class_Instance := Nth_Arg (Data, 1, Class);
      W     : Gtk_Widget;
   begin
      if Command = Constructor_Method then
         Set_Error_Msg
           (Data, -("Cannot build instances of GPS.GUI, these are returned"
                    & " by other functions"));
      elsif Command = "set_sensitive" then
         Name_Parameters (Data, Set_Sensitive_Parameters);
         W := Gtk_Widget (GObject'(Get_Data (Inst, GUI_Class_Name)));
         if W /= null then
            Set_Sensitive (W, Nth_Arg (Data, 2, True));
         else
            Set_Error_Msg (Data, "Widget has been destroyed");
         end if;

      elsif Command = "is_sensitive" then
         W := Gtk_Widget (GObject'(Get_Data (Inst, GUI_Class_Name)));
         if W /= null then
            Set_Return_Value (Data, Gtk.Widget.Is_Sensitive (W));
         else
            Set_Error_Msg (Data, "Widget has been destroyed");
         end if;
      elsif Command = "destroy" then
         W := Gtk_Widget (GObject'(Get_Data (Inst, GUI_Class_Name)));
         if W /= null then
            Destroy (W);
         else
            Set_Error_Msg
              (Data,
               "Widget has already been destroyed, can't destroy it again");
         end if;

      elsif Command = "hide" then
         W := Gtk_Widget (GObject'(Get_Data (Inst, GUI_Class_Name)));
         if W /= null then
            Set_Child_Visible (W, False);
            Hide (W);
         else
            Set_Error_Msg (Data, "Widget has been destroyed, can't hide it");
         end if;

      elsif Command = "show" then
         W := Gtk_Widget (GObject'(Get_Data (Inst, GUI_Class_Name)));
         if W /= null then
            Set_Child_Visible (W, True);
            Show (W);
         else
            Set_Error_Msg (Data, "Widget has been destroyed, can't show it");
         end if;
      end if;
   end GUI_Command_Handler;

   ----------
   -- Free --
   ----------

   procedure Free_User_Data (Data : in out User_Data_List) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (User_Data, User_Data_List);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Instance_Property_Record'Class, Instance_Property);
   begin
      if Data /= null then
         if Data.Prop /= null then
            Destroy (Data.Prop.all);
            Unchecked_Free (Data.Prop);
         end if;
         Unchecked_Free (Data);
      end if;
   end Free_User_Data;

   -------------
   -- Destroy --
   -------------

   procedure Destroy (Prop : in out Scalar_Properties_Record) is
   begin
      case Prop.Typ is
         when Strings =>
            Free (Prop.Str);

         when Objects =>
            --  Nothing to do; the object holds a reference to the
            --  instance, the opposite is not true. The instance will
            --  never be destroyed while the object exists in this case.
            --
            --  We shouldn't be able to free Obj while the widget's user
            --  data still exists, since it holds a reference to the
            --  class_instance. Therefore Free should only be called when
            --  Obj has already been reset to null when
            --  On_Widget_Data_Destroyed has been called.

            if Prop.Obj /= null then
               Prop.Obj := null;
            end if;

         when Integers | Files | Projects | Debug_Handles | Contexts =>
            null;

         when Entities =>
            Unref (Prop.Entity);

         when File_Locations =>
            Prop.Location := No_File_Location;
            --  This might also destroy the class instance Data.Location.File
      end case;
   end Destroy;

   ------------
   -- Decref --
   ------------

   procedure Decref (Inst : access Class_Instance_Record) is
      Data : User_Data_List;
      Ptr  : Class_Instance_Record_Access;
   begin
      Inst.Refcount := Inst.Refcount - 1;
      if Inst.Refcount = 0 then
         if Active (Ref_Me) then
            Trace (Ref_Me, "Decref Destroying instance "
                   & Print_Refcount (Class_Instance_Record_Access (Inst)));
         end if;

         --  Free user data

         while Inst.User_Data /= null loop
            Data := Inst.User_Data.Next;
            Free_User_Data (Inst.User_Data);
            Inst.User_Data := Data;
         end loop;

         Ptr := Inst.all'Access;
         --  The above isn't dangereous: We know there are no more
         --  Class_Instance referencing this pointer, or we wouldn't be
         --  destroying it. As a result, it is safe to free the memory here

         Unchecked_Free (Ptr);
      elsif Active (Ref_Me) then
         Trace (Ref_Me, "After Decref "
                & Print_Refcount (Class_Instance_Record_Access (Inst)));
      end if;
   end Decref;

   ------------
   -- Incref --
   ------------

   procedure Incref (Inst : access Class_Instance_Record) is
   begin
      Inst.Refcount := Inst.Refcount + 1;
   end Incref;

   ------------
   -- Adjust --
   ------------

   procedure Adjust (CI : in out Class_Instance_Data) is
   begin
      Incref (CI.Data);
      if Active (Ref_Me) then
         Trace (Ref_Me, "After Adjust " & Print_Refcount (CI.Data));
      end if;
   end Adjust;

   --------------
   -- Finalize --
   --------------

   procedure Finalize (CI : in out Class_Instance_Data) is
   begin
      --  Data might be null in some rare cases. Most notably, it happens when
      --  GPS is being destroyed: the python module has already been destroyed,
      --  but we still have remaining CI finalized when GNAT finalizes
      --  everything before exit.

      if CI.Data /= null then
         if Active (Ref_Me) then
            Trace (Ref_Me, "Finalize " & Print_Refcount (CI.Data));
         end if;
         Decref (CI.Data);
      end if;
   end Finalize;

   ---------
   -- "=" --
   ---------

   function "=" (CI1, CI2 : Class_Instance_Data) return Boolean is
   begin
      return CI1.Data = CI2.Data;
   end "=";

   -------------
   -- Get_CIR --
   -------------

   function Get_CIR
     (Inst : Class_Instance) return Class_Instance_Record_Access is
   begin
      if Inst.Initialized then
         return Inst.Data.Data;
      else
         return null;
      end if;
   end Get_CIR;

   --------------------
   -- Print_Refcount --
   --------------------

   function Print_Refcount
     (Instance : access Class_Instance_Record) return String is
   begin
      return "CI.rc=" & Integer'Image (Instance.Refcount);
   end Print_Refcount;

   -------------------
   -- From_Instance --
   -------------------

   function From_Instance
     (Script : access Scripting_Language_Record'Class;
      Inst   : access Class_Instance_Record'Class) return Class_Instance
   is
      Result : Class_Instance (Initialized => True);
   begin
      --  Do not modify the refcount, it should have been initialized properly
      --  already.
      Inst.Script := Scripting_Language (Script);

      --  Do not use an aggregate to limit the number of calls to
      --  Adjust/Finalize
      Result.Data.Data := Class_Instance_Record_Access (Inst);
      Incref (Get_CIR (Result));
      if Active (Ref_Me) then
         Trace (Ref_Me, "After From_Instance "
                & Print_Refcount (Get_CIR (Result)));
      end if;
      return Result;
   end From_Instance;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Instance : Class_Instance; Name : String) return User_Data_List
   is
      D : User_Data_List := Instance.Data.Data.User_Data;
   begin
      while D /= null loop
         if D.Name = Name then
            return D;
         end if;
         D := D.Next;
      end loop;
      return null;
   end Get_Data;

   ------------------
   -- Set_Property --
   ------------------

   procedure Set_Property
     (Instance : Class_Instance;
      Name     : String;
      Property : Instance_Property_Record'Class)
   is
      D        : User_Data_List := Instance.Data.Data.User_Data;
      Previous : User_Data_List;
   begin
      while D /= null loop
         if D.Name = Name then
            if Previous = null then
               Instance.Data.Data.User_Data := D.Next;
            else
               Previous.Next := D.Next;
            end if;
            Free_User_Data (D);
            exit;
         end if;
         Previous := D;
         D := D.Next;
      end loop;

      Instance.Data.Data.User_Data := new User_Data'
        (Length => Name'Length,
         Name   => Name,
         Next   => Instance.Data.Data.User_Data,
         Prop   => new Instance_Property_Record'Class'(Property));
   end Set_Property;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data
     (Instance : Class_Instance; Name : Class_Type; Value : String)
   is
   begin
      Set_Property
        (Instance, Get_Name (Name),
         Scalar_Properties_Record'(Typ => Strings, Str => new String'(Value)));
   end Set_Data;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data
     (Instance : Class_Instance; Name : Class_Type; Value : Integer)
   is
   begin
      Set_Property
        (Instance, Get_Name (Name),
         Scalar_Properties_Record'(Typ => Integers, Int => Value));
   end Set_Data;

   ------------------------------
   -- On_Widget_Data_Destroyed --
   ------------------------------

   procedure On_Widget_Data_Destroyed (CIR : CIR_Data_Type) is
      Data : User_Data_List := CIR.CIR.User_Data;
   begin
      --  Warning: it is possible that the Ada handle to the widget has already
      --  been deallocated, through a call to Glib.Object.Free_Data. The order
      --  of calls between Free_Data and On_Widget_Data_Destroyed is undefined,
      --  since they are both associated with user data stored in the C widget.
      --  As a result, we shouldn't use the Ada handle here!

      while Data /= null loop
         if Data.Name = CIR.Property_Name then
            Scalar_Properties (Data.Prop).Obj := null;
            exit;
         end if;
         Data := Data.Next;
      end loop;

      Decref (CIR.CIR); --  Might free CIR, do not reuse afterward!
   end On_Widget_Data_Destroyed;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data
     (Instance : Class_Instance;
      Widget   : Glib.Object.GObject;
      Name     : String := GUI_Class_Name) is
   begin
      Set_Property
        (Instance, Name,
         Scalar_Properties_Record'(Typ => Objects, Obj => Widget));

      --  The widget will hold a reference to the Instance, so that the
      --  instance is not destroyed while the widget is in use
      Incref (Get_CIR (Instance));

      --  Use a name specific to the scripting language, so that the same
      --  widget can have corresponding instances in several languages
      CIR_User_Data.Set
        (Widget, CIR_Data_Type'
           (CIR           => Get_CIR (Instance),
            Length        => Name'Length,
            Property_Name => Name),
         "GPS-Instance-" & Get_Name (Instance.Data.Data.Script),
         On_Destroyed => On_Widget_Data_Destroyed'Access);
   end Set_Data;

   ------------------
   -- Get_Instance --
   ------------------

   function Get_Instance
     (Script : access Scripting_Language_Record'Class;
      Widget : access Glib.Object.GObject_Record'Class)
      return Class_Instance is
   begin
      return From_Instance
        (Script, CIR_User_Data.Get
           (Widget, "GPS-Instance-" & Get_Name (Script)).CIR);
   exception
      when Gtkada.Types.Data_Error =>
         return No_Class_Instance;
   end Get_Instance;

   ------------------
   -- Get_Property --
   ------------------

   function Get_Property
     (Instance : Class_Instance;
      Name     : String) return Instance_Property_Record'Class
   is
      D : constant User_Data_List := Get_Data (Instance, Name);
   begin
      if D = null then
         raise Invalid_Data;
      else
         return D.Prop.all;
      end if;
   end Get_Property;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Instance : Class_Instance; Name : Class_Type) return Integer
   is
      D : constant User_Data_List := Get_Data (Instance, Get_Name (Name));
   begin
      if D = null then
         return Integer'Last;
      else
         return Scalar_Properties (D.Prop).Int;
      end if;
   end Get_Data;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Instance : Class_Instance; Name : Class_Type) return String
   is
      D : constant User_Data_List := Get_Data (Instance, Get_Name (Name));
   begin
      if D = null then
         return "";
      else
         return Scalar_Properties (D.Prop).Str.all;
      end if;
   end Get_Data;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Instance : Class_Instance;
      Name     : String := GUI_Class_Name) return Glib.Object.GObject
   is
      D : constant User_Data_List := Get_Data (Instance, Name);
   begin
      if D = null then
         return null;
      else
         return Scalar_Properties (D.Prop).Obj;
      end if;
   end Get_Data;

   ----------------
   -- Get_Script --
   ----------------

   function Get_Script (Instance : Class_Instance) return Scripting_Language is
   begin
      return Instance.Data.Data.Script;
   end Get_Script;

   -----------------
   -- Is_Subclass --
   -----------------

   function Is_Subclass
     (Instance : Class_Instance; Base : Class_Type) return Boolean is
   begin
      return Is_Subclass (Get_CIR (Instance), Base);
   end Is_Subclass;

end GPS.Kernel.Scripts;
