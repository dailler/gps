-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                      Copyright (C) 2001-2002                      --
--                            ACT-Europe                             --
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

with Gdk.Color;
with Glib.Properties;
with Glib;
with Pango.Font;
with Default_Preferences; use Default_Preferences;

package Glide_Kernel.Preferences is

   procedure Free_Preferences
     (Kernel    : access Kernel_Handle_Record'Class);
   --  Free the memory used by the preferences tree. Note that you should no
   --  longer call Get_Pref after calling this subprogram.

   procedure Load_Preferences
     (Kernel    : access Kernel_Handle_Record'Class;
      File_Name : String);
   --  Load the preferences from the specified file.
   --  No query is allowed before loading the preferences

   procedure Save_Preferences
     (Kernel    : access Kernel_Handle_Record'Class;
      File_Name : String);
   --  Save the preferences in the specified file.
   --  Note that only the preferences that have been modified by the user are
   --  saved.

   procedure Set_Default_Preferences
     (Kernel : access Kernel_Handle_Record'Class);
   --  Reset the preferences to their default value.

   function Get_Pref
     (Kernel : access Kernel_Handle_Record'Class;
      Pref   : Glib.Properties.Property_Int) return Glib.Gint;
   function Get_Pref
     (Kernel : access Kernel_Handle_Record'Class;
      Pref   : Glib.Properties.Property_Uint) return Glib.Guint;
   function Get_Pref
     (Kernel : access Kernel_Handle_Record'Class;
      Pref   : Glib.Properties.Property_Boolean) return Boolean;
   function Get_Pref
     (Kernel : access Kernel_Handle_Record'Class;
      Pref   : Glib.Properties.Property_String) return String;
   function Get_Pref
     (Kernel : access Kernel_Handle_Record'Class;
      Pref   : Property_Color) return Gdk.Color.Gdk_Color;
   function Get_Pref
     (Kernel : access Kernel_Handle_Record'Class;
      Pref   : Property_Font) return Pango.Font.Pango_Font_Description;
   --  Return the value for a specific property.
   --  The colors and fonts have already been allocated when they are returned.

   -----------------------
   -- List of constants --
   -----------------------
   --  Below is the list of all the preference settings that can be set.
   --  The type of the constant gives the type of the value associated with the
   --  preference.

   -------------
   -- General --
   -------------

   Default_Widget_Width : constant Glib.Properties.Property_Int :=
     Register_Property ("General:Default_Widget_Width", 400);
   --  Default width for the widgets put in the MDI

   Default_Widget_Height : constant Glib.Properties.Property_Int :=
     Register_Property ("General:Default_Widget_Height", 400);
   --  Default height for the widgets put in the MDI

   Animated_Image : constant Glib.Properties.Property_String :=
     Register_Property ("General:Animated_Image", "gps-animation.gif");
   --  Animated image used to inform the user about a command in process.

   Splash_Screen : constant Glib.Properties.Property_String :=
     Register_Property ("General:Splash_Screen", "gps-splash.jpg");
   --  Splash screen displayed (if found) when starting GPS.

   Tmp_Dir : constant Glib.Properties.Property_String :=
     Register_Property ("General:Tmp_Dir", "/tmp");
   --  Directory used to create temporary files

   -------------
   -- Console --
   -------------

   Highlight_File : constant Property_Color :=
     Register_Property ("Console:Highlight_File", "#FF0000");
   --  Color used to highlight a file in the console

   Highlight_Error : constant Property_Color :=
     Register_Property ("Console:Highlight_Error", "#FF0000");
   --  Color used to highlight an error in the console

   ----------------
   -- Diff_Utils --
   ----------------

   Diff_Cmd : constant Glib.Properties.Property_String :=
     Register_Property ("Diff_Utils:Diff", "diff");
   --  Command used to compute differences between two files.
   --  ??? not used

   Patch_Cmd : constant Glib.Properties.Property_String :=
     Register_Property ("Diff_Utils:Patch", "patch");
   --  Command used to apply a patch.
   --  ??? not used

   --------------
   -- Explorer --
   --------------

   Absolute_Directories : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Explorer:Absolute_Directories", False);
   --  True if directories should be displayed as absolute names,
   --  False if they should be relative to the current directory set by the
   --  user.

   Show_Directories : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Explorer:Show_Directories", True);
   --  Whether directories should be displayed in the tree.
   --  If False, only the projects are shown.

   -------------------
   -- Source Editor --
   -------------------

   Default_Keyword_Color : constant Property_Color :=
     Register_Property ("Src_Editor:Keyword_Color", "");
   --  Color for highlighting keywords

   Default_Comment_Color : constant Property_Color :=
     Register_Property ("Src_Editor:Comment_Color", "blue");
   --  Color for highlighting comments

   Default_String_Color : constant Property_Color :=
     Register_Property ("Src_Editor:String_Color", "brown");
   --  Color for highlighting strings

   Default_Character_Color : constant Property_Color :=
     Register_Property ("Src_Editor:Character_Color", "brown");
   --  Color for highlighting characters

   Default_HL_Line_Color   : constant Property_Color :=
     Register_Property ("Src_Editor:Highlight_Line_Color", "green");
   --  Color for highlighting lines

   Default_HL_Region_Color : constant Property_Color :=
     Register_Property ("Src_Editor:Highlight_Region_Color", "cyan");
   --  Color for highlighting regions

   Automatic_Indentation : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Src_Editor:Automatic_Indentation", True);
   --  Whether the editor should indent automatically the source

   Strip_Blanks : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Src_Editor:Strip_Blanks", True);
   --  Whether the editor should remove trailing blanks when saving a file

   Default_Source_Editor_Font : constant Property_Font :=
     Register_Property ("Src_Editor:Default_Font", "Courier 10");
   --  The font used in the source editor.

   Display_Tooltip : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Src_Editor:Display_Tooltip", True);
   --  Whether tooltips should be displayed automatically in the source
   --  editor.

   Periodic_Save : constant Glib.Properties.Property_Int :=
     Register_Property ("Src_Editor:Periodic_Save", 60);
   --  The period (in seconds) after which a source editor is automatically
   --  saved. 0 if none.

   Tab_Width : constant Glib.Properties.Property_Int :=
     Register_Property ("Src_Editor:Tab_Width", 8);
   --  The width of a tabulation character, in characters.

   ---------------------
   -- External editor --
   ---------------------

   Default_External_Editor : constant Glib.Properties.Property_String :=
     Register_Property ("External_Editor:Default_Editor", "");
   --  The default external editor to use. It should be a value from
   --  External_Editor_Module.Supported_Clients, or the empty string, in which
   --  case GPS will automatically select the first available client

   Always_Use_External_Editor : constant Glib.Properties.Property_Boolean :=
     Register_Property ("External_Editor:Always_Use_External_Editor", False);
   --  True if all editions should be done with the external editor. This will
   --  deactivate completely the internal editor. On the other hand, if this is
   --  False, then the external editor will need to be explicitely selected by
   --  the user.

   --------------------
   -- Project Editor --
   --------------------

   Default_Switches_Color : constant Property_Color :=
     Register_Property ("Prj_Editor:Default_Switches_Color", "#777777");
   --  Color to use when displaying switches that are not file specific, but
   --  set at the project or package level.

   Switches_Editor_Title_Font : constant Glib.Properties.Property_String :=
     Register_Property ("Prj_Editor:Title_Font", "helvetica bold oblique 14");
   --  Font to use for the switches editor dialog

   Variable_Ref_Background : constant Property_Color :=
     Register_Property ("Prj_Editor:Var_Ref_Bg", "#AAAAAA");
   --  Color to use for the background of variable references in the value
   --  editor

   Invalid_Variable_Ref_Background : constant Property_Color :=
     Register_Property ("Prj_Editor:Invalid_Var_Ref_Bg", "#AA0000");
   --  Color to use for the foreground of invalid variable references.

   File_View_Shows_Only_Project : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Prj_Editor:File_View_Shows_Only_Project", False);

   -------------
   -- Wizards --
   -------------

   Wizard_Toc_Highlight_Color : constant Property_Color :=
     Register_Property ("Wizard:Toc_Highlight_Color", "yellow");
   --  Color to use to highlight strings in the TOC.

   Wizard_Title_Font : constant Glib.Properties.Property_String :=
     Register_Property ("Wizard:Title_Font", "helvetica bold oblique 10");
   --  Font to use for the title of the pages in the wizard

   --------------
   -- Browsers --
   --------------

   Browsers_Link_Font : constant Property_Font :=
     Register_Property ("Browsers:Link_Font", "Helvetica 10");
   --  Font used to draw the links in the items

   Browsers_Link_Color : constant Property_Color :=
     Register_Property ("Browsers:Link_Color", "#0000FF");
   --  Color used to draw the links in the items

   Selected_Link_Color : constant Property_Color :=
     Register_Property ("Browsers:Selected_Link_Color", "#FF0000");
   --  Color to use links whose ends are selected.

   Selected_Item_Color : constant Property_Color :=
     Register_Property ("Browsers:Selected_Item_Color", "#888888");
   --  Color to use to draw the selected item.

   Parent_Linked_Item_Color : constant Property_Color :=
     Register_Property ("Browsers:Linked_Item_Color", "#AAAAAA");
   Child_Linked_Item_Color : constant Property_Color :=
     Register_Property ("Browsers:Child_Linked_Item_Color", "#DDDDDD");
   --  Color to use to draw the items that are linked to the selected item.

   Browsers_Vertical_Layout : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Browsers:Vertical_Layout", True);
   --  Whether the layout of the graph should be vertical or horizontal

   ---------
   -- VCS --
   ---------

   VCS_Commit_File_Check : constant Glib.Properties.Property_String :=
     Register_Property ("VCS:Commit_File_Check", "");
   --  A script that will be called with one source file as argument
   --  before VCS Commit operations.

   VCS_Commit_Log_Check : constant Glib.Properties.Property_String :=
     Register_Property ("VCS:Commit_Log_Check", "");
   --  A script that will be called with one log file as argument before
   --  VCS Commit operations.

   ---------
   -- CVS --
   ---------

   CVS_Command : constant Glib.Properties.Property_String :=
     Register_Property ("CVS:Command", "cvs");
   --  General CVS command

   --------------
   -- Debugger --
   --------------

   --  General

   Break_On_Exception : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Debugger:Break_On_Exception", False);
   --  Break on exceptions.

   --  Assembly Window

   Asm_Highlight_Color : constant Property_Color :=
     Register_Property ("Debugger:Asm_Highlight_Color", "#FF0000");
   --  Color to use to highlight the assembly code for the current line
   --  (default is red).

   Assembly_Range_Size : constant Glib.Properties.Property_String :=
     Register_Property ("Debugger:Assembly_Range_Size", "200");
   --  Size of the range to display when initially displaying the
   --  assembly window.
   --  If this size is "0", then the whole function is displayed, but this
   --  can potentially take a very long time on slow machines or big
   --  functions.

   --  Data Window

   Xref_Color : constant Property_Color :=
     Register_Property ("Debugger:Xref_Color", "#0000FF");
   --  Color to use for the items that are clickable (blue).

   Title_Color : constant Property_Color :=
     Register_Property ("Debugger:Title_Color", "#BEBEBE");
   --  Color to use for the background of the title (grey).

   Change_Color : constant Property_Color :=
     Register_Property ("Debugger:Change_Color", "#FF0000");
   --  Color used to highlight fields that have changed since the last
   --  update (default is red).

   Selection_Color : constant Property_Color :=
     Register_Property ("Debugger:Selection_Color", "#000000");
   --  Color used to handle item selections.

   Thaw_Bg_Color : constant Property_Color :=
     Register_Property ("Debugger:Thaw_Bg_Color", "#FFFFFF");
   --  Color used for auto-refreshed items (white)

   Freeze_Bg_Color : constant Property_Color :=
     Register_Property ("Debugger:Freeze_Bg_Color", "#AAAAAA");
   --  Color used for frozen items (light grey)

   Debugger_Data_Title_Font : constant Glib.Properties.Property_String :=
     Register_Property ("Debugger:Data_Title_Font", "helvetica bold 10");
   --  Font used for the name of the item.

   Value_Font : constant Glib.Properties.Property_String :=
     Register_Property ("Debugger:Data_Value_Font", "helvetica 10");
   --  Font used to display the value of the item.

   Command_Font : constant Glib.Properties.Property_String :=
     Register_Property ("Debugger:Data_Command_Font", "courier 10");
   --  Font used to display the value for the commands
   --    graph print `...`  or graph display `...`

   Type_Font : constant Glib.Properties.Property_String :=
     Register_Property ("Debugger:Data_Type_Font", "helvetica oblique 10");
   --  Font used to display the type of the item.

   Hide_Big_Items : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Debugger:Hide_Big_Items", True);
   --  If True, items higher than a given limit will start in a hidden
   --  state.

   Big_Item_Height : constant Glib.Properties.Property_Int :=
     Register_Property ("Debugger:Big_Items_Height", 150);
   --  Items taller than this value will start hidden.

   Default_Detect_Aliases : constant Glib.Properties.Property_Boolean :=
     Register_Property ("Debugger:Default_Detect_Aliased", True);
   --  If True, do not create new items when a matching item is already
   --  present in the canvas.

   --  Command Window

   Debugger_Highlight_Color : constant Property_Color :=
     Register_Property ("Debugger:Command_Highlight_Color", "#0000FF");
   --  Color used for highlighting in the debugger window (blue).

   Debugger_Command_Font : constant Glib.Properties.Property_String :=
     Register_Property ("Debugger:Command_Font", "courier 12");
   --  Font used in the debugger text window.

   --  Memory Window

   Memory_View_Font : constant Glib.Properties.Property_String :=
     Register_Property ("Debugger:Memory_View_Font", "courier 12");
   --  Font use in the memory view window.

   Memory_View_Color : constant Property_Color :=
     Register_Property ("Debugger:Memory_View_Color", "#333399");
   --  Color used by default in the memory view window.

   Memory_Highlighted_Color : constant Property_Color :=
     Register_Property ("Debugger:Memory_Highlighted_Color", "#DDDDDD");
   --  Color used for highlighted items in the memory view.

   Memory_Selected_Color : constant Property_Color :=
     Register_Property ("Debugger:Memory_Selected_Color", "#00009C");
   --  Color used for selected items in the memory view.

   Memory_Modified_Color : constant Property_Color :=
     Register_Property ("Debugger:Memory_Modified_Color", "#FF0000");
   --  Color used for modified items in the memory view.

   -------------
   -- Helpers --
   -------------

   List_Processes : constant Glib.Properties.Property_String :=
     Register_Property ("Helpers:List_Processes", "ps x");
   --  Command to use to list processes running on the machine

   Remote_Protocol : constant Glib.Properties.Property_String :=
     Register_Property ("Helpers:Remote_Protocol", "rsh");
   --  How to run a process on a remote machine ?

   Remote_Copy : constant Glib.Properties.Property_String :=
     Register_Property ("Helpers:Remote_Copy", "rcp");
   --  Program used to copy a file from a remote host.

end Glide_Kernel.Preferences;
