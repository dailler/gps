-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2001-2002                       --
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

with Ada.Text_IO;               use Ada.Text_IO;
with GNAT.OS_Lib;               use GNAT.OS_Lib;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with Ada.Strings.Unbounded;     use Ada.Strings.Unbounded;
with Ada.Characters.Handling;   use Ada.Characters.Handling;
with Language.Ada;              use Language.Ada;
with Doc_Types;                 use Doc_Types;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with OS_Utils;                  use OS_Utils;

package body Work_On_Source is

   --  package GOL renames GNAT.OS_Lib;
   --  package ASU renames Ada.Strings.Unbounded;
   package TSFL renames Type_Source_File_List;
   package TEL renames Type_Entity_List;

   --------------------
   -- Process_Source --
   --------------------

   procedure Process_Source
     (Doc_File          : File_Type;
      First_File        : Boolean;
      Last_File         : Boolean;
      Next_Package      : GNAT.OS_Lib.String_Access;
      Prev_Package      : GNAT.OS_Lib.String_Access;
      Source_File_List  : in out Type_Source_File_List.List;
      Source_Filename   : String;
      Package_Name      : String;
      Def_In_Line       : Integer;
      Entity_List       : in out Type_Entity_List.List;
      Process_Body_File : Boolean;
      Options           : All_Options) is

      File_Text         : GNAT.OS_Lib.String_Access;
      Parsed_List       : Construct_List;

   begin

      --  parse the source file and create the Parsed_List
      File_Text := Read_File (Source_Filename);

      if not Options.Doc_One_File or First_File then
         Process_Open_File (Doc_File,
                            Package_Name,
                            Source_File_List,
                            Options);
      end if;

      Process_Header (Doc_File,
                      Package_Name,
                      Next_Package,
                      Prev_Package,
                      Def_In_Line,
                      Source_Filename,
                      Process_Body_File,
                      Options);

      --  different ways of process for .ads and .adb files
      if File_Extension (File_Name (Source_Filename)) = ".ads" then

         Parse_Constructs (Ada_Lang,
                           File_Text.all,
                           Parsed_List);

         Sort_List_Name (Entity_List);

         --  the order of the following procedure calls can't be changed
         --  without changing the order in texi_output: Doc_TEXI_Subtitle

         Process_Package_Description (Doc_File,
                                      Source_Filename,
                                      Package_Name,
                                      File_Text.all,
                                      Options);
         Process_With_Clause (Doc_File,
                              Entity_List,
                              Source_Filename,
                              Package_Name,
                              Parsed_List,
                              File_Text,
                              Options);
         Process_Packages     (Doc_File,
                               Entity_List,
                               Source_Filename,
                               Package_Name,
                               Parsed_List,
                               File_Text,
                               Options);
         Process_Vars        (Doc_File,
                              Entity_List,
                              Source_Filename,
                              Package_Name,
                              Parsed_List,
                              File_Text,
                              Options);
         Process_Exceptions  (Doc_File,
                              Entity_List,
                              Source_Filename,
                              Package_Name,
                              Parsed_List,
                              File_Text,
                              Options);
         Process_Types       (Doc_File,
                              Entity_List,
                              Source_Filename,
                              Package_Name,
                              Parsed_List,
                              File_Text,
                              Options);
         Process_Subprograms (Doc_File,
                              Entity_List,
                              Source_Filename,
                              Process_Body_File,
                              Package_Name,
                              Parsed_List,
                              File_Text,
                              Options);
         Free (Parsed_List);

      else
         Process_One_Body_File (Doc_File,
                                Source_Filename,
                                Entity_List,
                                File_Text,
                                Options);
      end if;
      Process_Footer (Doc_File,
                     Source_Filename,
                     Options);
      if not Options.Doc_One_File or Last_File then
         Process_Close_File (Doc_File, Options);
      end if;

      Free (File_Text);
   end Process_Source;

   -----------------------
   -- Process_Open_File --
   -----------------------

   procedure Process_Open_File
     (Doc_File         : File_Type;
      Package_File     : String;
      Source_File_List : in out Type_Source_File_List.List;
      Options          : All_Options) is

      Data_Open   : Doc_Info (Info_Type => Open_Info);

   begin
      Data_Open := Doc_Info'(Open_Info,
                             Open_Title => new String'("Docgen documentation"),
                             Open_File  => new String'(Package_File),
                             Open_Package_List => Source_File_List);

      Options.Doc_Subprogram (Doc_File, Data_Open);

      Free (Data_Open.Open_Title);
   end Process_Open_File;

   ------------------------
   -- Process_Close_File --
   ------------------------

   procedure Process_Close_File
     (Doc_File      : File_Type;
      Options       : All_Options) is

      Data_Close    : Doc_Info (Info_Type => Close_Info);
   begin
      Data_Close := Doc_Info'(Close_Info,
                              Close_Title => new String'("End documentation"));

      Options.Doc_Subprogram (Doc_File, Data_Close);

      Free (Data_Close.Close_Title);
   end Process_Close_File;

   ---------------------------
   -- Process_One_Body_File --
   ---------------------------

   procedure Process_One_Body_File
     (Doc_File           : File_Type;
      Source_File        : String;
      Entity_List        : Type_Entity_List.List;
      File_Text          : GNAT.OS_Lib.String_Access;
      Options            : All_Options)
   is
      Data_Line          : Doc_Info (Info_Type => Body_Line_Info);
   begin
      --  initialise the Doc_Info data
      Data_Line := Doc_Info'(Body_Line_Info,
                             Body_Text      => File_Text,
                             Body_File      =>
                             new String'(Source_File),
                             Body_Entity_List => Entity_List);

      --  call the documentation procedure
      Options.Doc_Subprogram (Doc_File, Data_Line);

      Free (Data_Line.Body_Text);
      Free (Data_Line.Body_File);
   end Process_One_Body_File;

   ------------------------
   -- Process_Unit_Index --
   ------------------------

   procedure Process_Unit_Index
     (Source_File_List : Type_Source_File_List.List;
      Options          : All_Options) is

      Source_Filename  : GOL.String_Access;
      Package_Name     : GOL.String_Access;
      Source_File_Node : Type_Source_File_List.List_Node;

      Index_File       : File_Type;

      Data_Package     : Doc_Info (Info_Type => Unit_Index_Info);
      Data_Item        : Doc_Info (Info_Type => Index_Item_Info);
      Data_End         : Doc_Info (Info_Type => End_Of_Index_Info);


      package TSFL renames Type_Source_File_List;

      One_Ready        : Integer;
      --  how many files already examined BEFORE the loop

   begin

      Create (Index_File,
              Out_File,
              Options.Doc_Directory.all
              & "index_unit" & Options.Doc_Suffix.all);

      if not TSFL.Is_Empty (Source_File_List) then
         One_Ready := 0;
         Source_File_Node := TSFL.First (Source_File_List);
         Source_Filename  := TSFL.Data (Source_File_Node).File_Name;

         --  if first file .adb, take the next one, which must be .ads
         if File_Extension (File_Name (Source_Filename.all)) = ".adb" then
            Source_File_Node := TSFL.Next (Source_File_Node);
            Source_Filename := TSFL.Data (Source_File_Node).File_Name;
            One_Ready := 1;
         end if;

         Data_Package := Doc_Info'(Unit_Index_Info,
                                   Doc_Directory =>
                                   new String'(Options.Doc_Directory.all),
                                   First_File =>
                                   new String'(Base_Name (
                                   Get_Doc_File_Name
                                                 (Source_Filename.all,
                                                  Options.Doc_Directory.all,
                                                  Options.Doc_Suffix.all))));
         --  create the upper part of the unit index
         Options.Doc_Subprogram (Index_File, Data_Package);
         for J in 1 .. Type_Source_File_List.Length (Source_File_List) -
           One_Ready loop
            Source_Filename := TSFL.Data (Source_File_Node).File_Name;

            --  add unit, but only if from a spec file
            if File_Extension (File_Name (Source_Filename.all)) = ".ads" then
               Package_Name    := TSFL.Data (Source_File_Node).Package_Name;
               Data_Item :=
                 Doc_Info'(Index_Item_Info,
                           Item_Name => Package_Name,
                           Item_File =>
                           new String'(File_Name (Source_Filename.all)),
                           Item_Line =>
                             TSFL.Data (Source_File_Node).Def_In_Line,
                           Item_Doc_File =>
                           new String'(Base_Name
                                         (Get_Doc_File_Name
                                            (Source_Filename.all,
                                             Options.Doc_Directory.all,
                                             Options.Doc_Suffix.all))));
               Options.Doc_Subprogram (Index_File, Data_Item);
            end if;

            Source_File_Node := TSFL.Next (Source_File_Node);
         end loop;
      end if;

      Data_End := Doc_Info'(End_Of_Index_Info,
                            End_index_Title => new String'("End of Index"));
      Options.Doc_Subprogram (Index_File, Data_End);

      Free (Data_Package.First_File);
      Free (Data_Package.Doc_Directory);
      Free (Data_Item.Item_File);
      Free (Data_Item.Item_Doc_File);
      Free (Data_End.End_Index_Title);

      Close (Index_File);
   end Process_Unit_Index;

   ------------------------------
   -- Process_Subprogram_Index --
   ------------------------------

   procedure Process_Subprogram_Index
     (Subprogram_Index_List : Type_Entity_List.List;
      Options          : All_Options) is

      Source_Filename       : GOL.String_Access;
      Subprogram_Index_Node : Type_Entity_List.List_Node;

      Index_File       : File_Type;

      Data_Subprogram  : Doc_Info (Info_Type => Subprogram_Index_Info);
      Data_Item        : Doc_Info (Info_Type => Index_Item_Info);
      Data_End         : Doc_Info (Info_Type => End_Of_Index_Info);

   begin
      Create (Index_File,
              Out_File,
              Options.Doc_Directory.all
              & "index_sub" & Options.Doc_Suffix.all);

      Data_Subprogram := Doc_Info'(Subprogram_Index_Info,
                                   First_Dummy => null);
      Options.Doc_Subprogram (Index_File, Data_Subprogram);

      if not TEL.Is_Empty (Subprogram_Index_List) then
         Subprogram_Index_Node := TEL.First (Subprogram_Index_List);
         for J in 1 .. Type_Entity_List.Length (Subprogram_Index_List) loop

               --  only if NOT a subprogram from a standard package!
            if Index (To_Unbounded_String
                        (TEL.Data
                           (Subprogram_Index_Node).Name.all), ".") > 0 then

               Source_Filename := TEL.Data (Subprogram_Index_Node).File_Name;

               Data_Item := Doc_Info'(Index_Item_Info,
                                      Item_Name =>
                                        TEL.Data
                                          (Subprogram_Index_Node).Short_Name,
                                      Item_File =>
                                      new String'(File_Name
                                                    (Source_Filename.all)),
                                      Item_Line =>
                                        TEL.Data (Subprogram_Index_Node).Line,
                                      Item_Doc_File => new String'
                                        (Base_Name
                                           (Get_Doc_File_Name
                                              (Source_Filename.all,
                                               Options.Doc_Directory.all,
                                               Options.Doc_Suffix.all))));
               Options.Doc_Subprogram (Index_File, Data_Item);
            end if;
            Subprogram_Index_Node := TEL.Next (Subprogram_Index_Node);
         end loop;

      end if;

      Data_End := Doc_Info'(End_Of_Index_Info,
                            End_Index_Title => new String'("End of Index"));
      Options.Doc_Subprogram (Index_File, Data_End);

      Free (Data_Item.Item_File);
      Free (Data_Item.Item_Doc_File);
      Free (Data_End.End_Index_Title);

      Close (Index_File);
   end Process_Subprogram_Index;

   ------------------------
   -- Process_Type_Index --
   ------------------------

   procedure Process_Type_Index
     (Type_Index_List : Type_Entity_List.List;
      Options          : All_Options) is

      Source_Filename  : GOL.String_Access;
      Type_Index_Node  : Type_Entity_List.List_Node;

      Index_File       : File_Type;

      Data_Type        : Doc_Info (Info_Type => Type_Index_Info);
      Data_Item        : Doc_Info (Info_Type => Index_Item_Info);
      Data_End         : Doc_Info (Info_Type => End_Of_Index_Info);

   begin

      Create (Index_File,
              Out_File,
              Options.Doc_Directory.all
              & "index_type" & Options.Doc_Suffix.all);
      Data_Type := Doc_Info'(Type_Index_Info,
                             Second_Dummy => null);
      Options.Doc_Subprogram (Index_File, Data_Type);


      if not TEL.Is_Empty (Type_Index_List) then
         Type_Index_Node := TEL.First (Type_Index_List);
         for J in 1 .. Type_Entity_List.Length (Type_Index_List) loop

               Source_Filename := TEL.Data (Type_Index_Node).File_Name;

               Data_Item := Doc_Info'(Index_Item_Info,
                                      Item_Name =>
                                        TEL.Data (Type_Index_Node).Short_Name,
                                      Item_File =>
                                      new String'(File_Name
                                                    (Source_Filename.all)),
                                      Item_Line =>
                                        TEL.Data (Type_Index_Node).Line,
                                      Item_Doc_File => new String'
                                        (Base_Name
                                           (Get_Doc_File_Name
                                              (Source_Filename.all,
                                               Options.Doc_Directory.all,
                                               Options.Doc_Suffix.all))));
               Options.Doc_Subprogram (Index_File, Data_Item);

               Type_Index_Node := TEL.Next (Type_Index_Node);
         end loop;

      end if;

      Data_End := Doc_Info'(End_Of_Index_Info,
                            End_Index_Title => new String'("End of Index"));
      Options.Doc_Subprogram (Index_File, Data_End);

      Free (Data_Item.Item_File);
      Free (Data_Item.Item_Doc_File);
      Free (Data_End.End_Index_Title);

      Close (Index_File);
   end Process_Type_Index;

   --------------------
   -- Process_Header --
   --------------------

   procedure Process_Header
     (Doc_File           : File_Type;
      Package_Name       : String;
      Next_Package       : GNAT.OS_Lib.String_Access;
      Prev_Package       : GNAT.OS_Lib.String_Access;
      Def_In_Line        : Integer;
      Package_File       : String;
      Process_Body_File  : Boolean;
      Options            : All_Options) is

      Data_Header   : Doc_Info (Info_Type => Header_Info);

   begin

      Data_Header := Doc_Info'(Header_Info,
                               Header_Package => new String'(Package_Name),
                               Header_File  => new String'(Package_File),
                               Header_Line  => Def_In_Line,
                               Header_Link  => Process_Body_File,
                               Header_Package_Next => Next_Package,
                               Header_Package_Prev => Prev_Package);
      Options.Doc_Subprogram (Doc_File, Data_Header);

      Free (Data_Header.Header_Package);
      Free (Data_Header.Header_File);
   end Process_Header;


   --------------------
   -- Process_Footer --
   --------------------

   procedure Process_Footer
     (Doc_File      : File_Type;
      Package_File  : String;
      Options       : All_Options) is

      Data_Footer   : Doc_Info (Info_Type => Footer_Info);

   begin
      Data_Footer := Doc_Info'(Footer_Info,
                               Footer_Title => new String'("Docgen"),
                               Footer_File  => new String'(Package_File));
      Options.Doc_Subprogram (Doc_File, Data_Footer);

      Free (Data_Footer.Footer_Title);
      Free (Data_Footer.Footer_File);
   end Process_Footer;

   ---------------------------------
   -- Process_Package_Description --
   ---------------------------------

   procedure Process_Package_Description
     (Doc_File        : File_Type;
      Source_Filename : String;
      Package_Name    : String;
      Text            : String;
      Options         : All_Options) is

      Data_Subtitle    : Doc_Info (Info_Type => Subtitle_Info);
      Data_Package     : Doc_Info (Info_Type => Package_Desc_Info);

      Description_Found, Start_Found : Boolean;
      Line                           : Natural;
      Max_Lines                      : constant Natural :=
        Count_Lines (Text);
      Description                    : GNAT.OS_Lib.String_Access;

   begin
      --  tries to find the first line of the description of the package
      --  if something else is found than a comment line => no description
      Description_Found := False;
      Start_Found       := False;
      Line              := 1;
      while not Start_Found and Line < Max_Lines + 1 loop
         if Line_Is_Comment (Get_Line_From_String (Text, Line)) then
            Description_Found := True;
            Start_Found       := True;
         elsif not Line_Is_Empty
           (Get_Line_From_String (Text, Line)) then
            Start_Found       := True;
         else
            Line := Line + 1;
         end if;
      end loop;

      --  if package description found
      if Description_Found then

         Data_Subtitle := Doc_Info'(Subtitle_Info,
                                    Subtitle_Name =>
                                    new String'("Description"),
                                    Subtitle_Kind => Package_Desc_Info,
                                    Subtitle_Package =>
                                    new String'(Package_Name));


         Options.Doc_Subprogram (Doc_File, Data_Subtitle);

         Description := new String'(Extract_Comment (Source_Filename,
                                                      Line,
                                                      0,
                                                      True,
                                                      Options));
         Data_Package := Doc_Info'(Package_Desc_Info,
                                   Package_Desc_Description
                                     => Description);
         Options.Doc_Subprogram (Doc_File, Data_Package);
      end if;
   end Process_Package_Description;

   --------------------------
   -- Process_With_Clauses --
   --------------------------

   procedure Process_With_Clause
     (Doc_File        : File_Type;
      Entity_List     : in out Type_Entity_List.List;
      Source_Filename : String;
      Package_Name    : String;
      Parsed_List     : Construct_List;
      File_Text       : GNAT.OS_Lib.String_Access;
      Options         : All_Options) is

      Data_Subtitle   : Doc_Info (Info_Type => Subtitle_Info);
      Data_With       : Doc_Info (Info_Type => With_Info);

      Old_Line, New_Line : GNAT.OS_Lib.String_Access;
      Parse_Node         : Construct_Access;
      Parsed_List_End    : Boolean;
   begin
      New_Line        := new String'("  ");
      Parse_Node      := Parsed_List.First;
      Parsed_List_End := False;

      --  exception if no paresed entities found: later

      while not Parsed_List_End loop

         if Parse_Node.Category = Cat_With then
            Old_Line := New_Line;
            New_Line := new String '(New_Line.all & ASCII.LF &
                                     File_Text.all
                                       (Parse_Node.Sloc_Start.Index ..
                                          Parse_Node.Sloc_End.Index));
            Free (Old_Line);
         end if;

         if Parse_Node = Parsed_List.Last then
            Parsed_List_End := True;
         else
            Parse_Node := Parse_Node.Next;
         end if;
      end loop;

      if New_Line.all'Length > 0 then

         Data_Subtitle := Doc_Info'(Subtitle_Info,
                                    Subtitle_Name =>
                                    new String'("Dependencies"),
                                    Subtitle_Kind => With_Info,
                                    Subtitle_Package =>
                                    new String'(Package_Name));
         Options.Doc_Subprogram (Doc_File, Data_Subtitle);
      end if;
      Data_With := Doc_Info'(With_Info,
                             With_List  => Entity_List,
                             With_File  => new String '(Source_Filename),
                             With_Header => New_Line);
      Options.Doc_Subprogram (Doc_File, Data_With);

      Free (Data_Subtitle.Subtitle_Name);
      Free (Data_Subtitle.Subtitle_Package);
      Free (New_Line);
   end Process_With_Clause;

   ----------------------
   -- Process_Packages --
   ----------------------

   procedure Process_Packages
     (Doc_File        : File_Type;
      Entity_List     : in out Type_Entity_List.List;
      Source_Filename : String;
      Package_Name    : String;
      Parsed_List     : Construct_List;
      File_Text       : GNAT.OS_Lib.String_Access;
      Options         : All_Options) is

      Entity_Node     : Type_Entity_List.List_Node;
      Description     : GNAT.OS_Lib.String_Access;
      Header          : GNAT.OS_Lib.String_Access;
      Data_Subtitle   : Doc_Info (Info_Type => Subtitle_Info);
      Data_Package    : Doc_Info (Info_Type => Package_Info);

      First_Already_Set : Boolean;
   begin

      if not TEL.Is_Empty (Entity_List) then
         First_Already_Set := False;
         Data_Subtitle := Doc_Info'(Subtitle_Info,
                                    Subtitle_Name =>
                                    new String'("Packages"),
                                    Subtitle_Kind => Package_Info,
                                    Subtitle_Package =>
                                      new String '(Package_Name));
         Entity_Node := TEL.First (Entity_List);
         for J in 1 .. TEL.Length (Entity_List) loop

               --  check if the entity is a variable
            if TEL.Data (Entity_Node).Kind = Package_Entity
            --  but NOT the package itself
              and not (To_Lower (TEL.Data (Entity_Node).Short_Name.all) =
                       To_Lower (Package_Name))
            --  check if defined in this file, the others used only for bodys!
            and TEL.Data (Entity_Node).File_Name.all = Source_Filename
            then

               --  check if the subtitle has been set already.
               --  Can't be set before the "if"
               if not First_Already_Set then
                  Options.Doc_Subprogram (Doc_File, Data_Subtitle);
                  First_Already_Set := True;
               end if;

               Header :=
                 Get_Whole_Header (File_Text.all,
                                   Parsed_List,
                                   TEL.Data (Entity_Node).Short_Name.all,
                                   TEL.Data (Entity_Node).Line);

               Description := new String'
                 (Extract_Comment (TEL.Data (Entity_Node).File_Name.all,
                                   TEL.Data (Entity_Node).Line,
                                   Count_Lines (Header.all),
                                   False,
                                   Options));
               Data_Package := Doc_Info'(Package_Info,
                                         Package_Entity      =>
                                           TEL.Data (Entity_Node),
                                         Package_Description => Description,
                                         Package_List        => Entity_List,
                                         Package_Header => Header);
               Options.Doc_Subprogram (Doc_File, Data_Package);
            end if;
            Entity_Node := TEL.Next (Entity_Node);
            Free (Description);
            Free (Header);
            Free (Data_Package.Package_Header);
         end loop;
         Free (Data_Subtitle.Subtitle_Name);
         Free (Data_Subtitle.Subtitle_Package);
      end if;
   end Process_Packages;

   ------------------
   -- Process_Vars --
   ------------------

   procedure Process_Vars
     (Doc_File        : File_Type;
      Entity_List     : in out Type_Entity_List.List;
      Source_Filename : String;
      Package_Name    : String;
      Parsed_List     : Construct_List;
      File_Text       : GNAT.OS_Lib.String_Access;
      Options         : All_Options) is

      Entity_Node     : Type_Entity_List.List_Node;
      Description     : GNAT.OS_Lib.String_Access;
      Header          : GNAT.OS_Lib.String_Access;
      Data_Subtitle   : Doc_Info (Info_Type => Subtitle_Info);
      Data_Var        : Doc_Info (Info_Type => Var_Info);

      First_Already_Set : Boolean;
   begin

      if not TEL.Is_Empty (Entity_List) then
         First_Already_Set := False;
         Data_Subtitle := Doc_Info'(Subtitle_Info,
                                    Subtitle_Name =>
                                    new String'
                                      ("Constants and Named Numbers"),
                                    Subtitle_Kind => Var_Info,
                                    Subtitle_Package =>
                                      new String '(Package_Name));
         Entity_Node := TEL.First (Entity_List);
         for J in 1 .. TEL.Length (Entity_List) loop

            --  check if the entity is a variable
            if TEL.Data (Entity_Node).Kind = Var_Entity
            --  check if defined in this file, the others used only for bodys!
            and TEL.Data (Entity_Node).File_Name.all = Source_Filename
            then

               --  check if the subtitle "Constand and Named Numbers:"
               --  has been set already.
               --  Can't be set before the "if"
               if not First_Already_Set then
                  Options.Doc_Subprogram (Doc_File, Data_Subtitle);
                  First_Already_Set := True;
               end if;

               Header :=
                 Get_Whole_Header (File_Text.all,
                                   Parsed_List,
                                   TEL.Data (Entity_Node).Short_Name.all,
                                   TEL.Data (Entity_Node).Line);

               Description := new String'
                 (Extract_Comment (TEL.Data (Entity_Node).File_Name.all,
                                   TEL.Data (Entity_Node).Line,
                                   Count_Lines (Header.all),
                                   False,
                                   Options));

               Data_Var := Doc_Info'(Var_Info,
                                     Var_Entity      => TEL.Data (Entity_Node),
                                     Var_Description => Description,
                                     Var_List        => Entity_List,
                                     Var_Header     => Header);
               Options.Doc_Subprogram (Doc_File, Data_Var);
            end if;
            Entity_Node := TEL.Next (Entity_Node);
            Free (Description);
            Free (Header);
            Free (Data_Var.Var_Header);
         end loop;
         Free (Data_Subtitle.Subtitle_Name);
         Free (Data_Subtitle.Subtitle_Package);
      end if;
   end Process_Vars;

   ------------------------
   -- Process_Exceptions --
   ------------------------

   procedure Process_Exceptions
     (Doc_File        : File_Type;
      Entity_List     : in out Type_Entity_List.List;
      Source_Filename : String;
      Package_Name    : String;
      Parsed_List     : Construct_List;
      File_Text       : GNAT.OS_Lib.String_Access;
      Options         : All_Options) is

      Entity_Node     : Type_Entity_List.List_Node;
      Description     : GNAT.OS_Lib.String_Access;
      Header          : GNAT.OS_Lib.String_Access;
      Data_Subtitle   : Doc_Info (Info_Type => Subtitle_Info);
      Data_Exception  : Doc_Info (Info_Type => Exception_Info);

      First_Already_Set : Boolean;
   begin

      if not TEL.Is_Empty (Entity_List) then
         First_Already_Set := False;
         Data_Subtitle := Doc_Info'(Subtitle_Info,
                                    Subtitle_Name =>
                                    new String'("Exceptions"),
                                    Subtitle_Kind => Exception_Info,
                                    Subtitle_Package =>
                                      new String'(Package_Name));
         Entity_Node := TEL.First (Entity_List);
         for J in 1 .. TEL.Length (Entity_List) loop

            --  if not a renamed exception...!  ***change this later!!!***

               --  check if the entity is a exception
            if TEL.Data (Entity_Node).Kind = Exception_Entity
            --  check if defined in this file, the others used only for bodys!
            and TEL.Data (Entity_Node).File_Name.all = Source_Filename
            then

               --  check if the subtitle "Exceptions:" has been set already.
               --  Can't be set before the "if"
               if not First_Already_Set then
                  Options.Doc_Subprogram (Doc_File, Data_Subtitle);
                  First_Already_Set := True;
               end if;

               Header :=
                 Get_Whole_Header (File_Text.all,
                                   Parsed_List,
                                   TEL.Data (Entity_Node).Short_Name.all,
                                   TEL.Data (Entity_Node).Line);

               Description := new String'
                 (Extract_Comment (TEL.Data (Entity_Node).File_Name.all,
                                   TEL.Data (Entity_Node).Line,
                                   Count_Lines (Header.all),
                                   False,
                                   Options));

               Data_Exception := Doc_Info'(Exception_Info,
                                           Exception_Entity      =>
                                             TEL.Data (Entity_Node),
                                           Exception_Description =>
                                             Description,
                                           Exception_List        =>
                                             Entity_List,
                                           Exception_Header   =>
                                             Header);
               Options.Doc_Subprogram (Doc_File, Data_Exception);
            end if;
            Entity_Node := TEL.Next (Entity_Node);
            Free (Description);
            Free (Header);
            Free (Data_Exception.Exception_Header);
         end loop;
         Free (Data_Subtitle.Subtitle_Name);
         Free (Data_Subtitle.Subtitle_Package);
      end if;
   end Process_Exceptions;

   -------------------
   -- Process_Types --
   -------------------

   procedure Process_Types
     (Doc_File        : File_Type;
      Entity_List     : in out Type_Entity_List.List;
      Source_Filename : String;
      Package_Name    : String;
      Parsed_List     : Construct_List;
      File_Text       : GNAT.OS_Lib.String_Access;
      Options         : All_Options) is

      Entity_Node     : Type_Entity_List.List_Node;
      Description     : GNAT.OS_Lib.String_Access;
      Header          : GNAT.OS_Lib.String_Access;
      Data_Subtitle   : Doc_Info (Info_Type => Subtitle_Info);
      Data_Type       : Doc_Info (Info_Type => Type_Info);

      First_Already_Set : Boolean;

   begin

      if not TEL.Is_Empty (Entity_List) then
         First_Already_Set := False;
         Data_Subtitle := Doc_Info'(Subtitle_Info,
                                  Subtitle_Name =>
                                  new String'("Types"),
                                   Subtitle_Kind => Type_Info,
                                   Subtitle_Package =>
                                     new String'(Package_Name));
         Entity_Node := TEL.First (Entity_List);

         for J in 1 .. TEL.Length (Entity_List) loop

            --  check if the entity is a type
            if TEL.Data (Entity_Node).Kind = Type_Entity
            --  check if defined in this file (the rest of entities
            --  only for the body documentation)
              and TEL.Data (Entity_Node).File_Name.all = Source_Filename
            then

               --  check if still the subtitle "Types:" has to be set.
               --  Can't be set before the "if"
               if not First_Already_Set then
                  Options.Doc_Subprogram (Doc_File, Data_Subtitle);
                  First_Already_Set := True;
               end if;

               Header :=
                 Get_Whole_Header (File_Text.all,
                                   Parsed_List,
                                   TEL.Data (Entity_Node).Short_Name.all,
                                   TEL.Data (Entity_Node).Line);

               Description := new String'
                 (Extract_Comment (TEL.Data (Entity_Node).File_Name.all,
                                   TEL.Data (Entity_Node).Line,
                                   Count_Lines (Header.all),
                                   False,
                                   Options));

               Data_Type := Doc_Info'(Type_Info,
                                      Type_Entity      =>
                                        TEL.Data (Entity_Node),
                                      Type_Description => Description,
                                      Type_List        => Entity_List,
                                      Type_Header => Header);
               Options.Doc_Subprogram (Doc_File, Data_Type);

            end if;
            Entity_Node := TEL.Next (Entity_Node);
            Free (Description);
            Free (Header);
            Free (Data_Type.Type_Header);
         end loop;
      end if;
      Free (Data_Subtitle.Subtitle_Name);
      Free (Data_Subtitle.Subtitle_Package);
   end Process_Types;

   -------------------------
   -- Process_Subprograms --
   -------------------------

   procedure Process_Subprograms
     (Doc_File           : File_Type;
      Entity_List        : in out Type_Entity_List.List;
      Source_Filename    : String;
      Process_Body_File  : Boolean;
      Package_Name       : String;
      Parsed_List        : Construct_List;
      File_Text          : GNAT.OS_Lib.String_Access;
      Options            : All_Options) is

      Entity_Node             : Type_Entity_List.List_Node;
      Description             : GNAT.OS_Lib.String_Access;
      Header                  : GNAT.OS_Lib.String_Access;
      Data_Subtitle           : Doc_Info (Info_Type => Subtitle_Info);
      Data_Subprogram         : Doc_Info (Info_Type => Subprogram_Info);

      First_Already_Set : Boolean;

   begin
      if not TEL.Is_Empty (Entity_List) then
         First_Already_Set := False;
         Data_Subtitle := Doc_Info'(Subtitle_Info,
                                  Subtitle_Name =>
                                  new String'("Subprograms"),
                                    Subtitle_Kind => Subprogram_Info,
                                    Subtitle_Package =>
                                      new String'(Package_Name));
         Entity_Node := TEL.First (Entity_List);
         for J in 1 .. TEL.Length (Entity_List) loop

            --  check if the entity is a procedure or a function
            if (TEL.Data (Entity_Node).Kind = Procedure_Entity or
                TEL.Data (Entity_Node).Kind = Function_Entity)
            --  check if defined in this file (the rest of
            --  entities only for the body documentation)
            and TEL.Data (Entity_Node).File_Name.all = Source_Filename
            then

               --  check if still the subtitle "Subprograms:"
               --  has to be set. Can be set before the "if"
               if not First_Already_Set then
                  Options.Doc_Subprogram (Doc_File, Data_Subtitle);
                  First_Already_Set := True;
               end if;

               Header :=
                 Get_Whole_Header (File_Text.all,
                                   Parsed_List,
                                   TEL.Data (Entity_Node).Short_Name.all,
                                   TEL.Data (Entity_Node).Line);

               Description := new String'
                 (Extract_Comment (TEL.Data (Entity_Node).File_Name.all,
                                   TEL.Data (Entity_Node).Line,
                                   Count_Lines (Header.all),
                                   False,
                                   Options));

               Data_Subprogram := Doc_Info'(Subprogram_Info,
                                            Subprogram_Entity      =>
                                              TEL.Data (Entity_Node),
                                            Subprogram_Description =>
                                              Description,
                                            Subprogram_Link        =>
                                              Process_Body_File,
                                            Subprogram_List        =>
                                              Entity_List,
                                            Subprogram_Header =>
                                            Header);
               Options.Doc_Subprogram (Doc_File, Data_Subprogram);
            end if;
            Entity_Node := TEL.Next (Entity_Node);
            Free (Description);
            Free (Header);
            Free (Data_Subprogram.Subprogram_Header);
         end loop;
      end if;
      Free (Data_Subtitle.Subtitle_Name);
      Free (Data_Subtitle.Subtitle_Package);
   end Process_Subprograms;

   ------------------
   --  Go_To_Line  --   !!! needed?
   ------------------

   procedure Go_To_Line
     (File : File_Type;
      Line : Natural) is
      Dummy : String (1 .. Max_Line_Length);
      Last  : Natural;
   begin
      for J in 1 .. Line loop
         Get_Line (File, Dummy, Last);
      end loop;
      --  how convert Natural->Count in order to use Skip?
   end Go_To_Line;

   --------------------------
   --  Get_Line_From_File  --   !!!needed?
   --------------------------

   function Get_Line_From_File
     (File_Name : String;
      Line      : Natural) return String
   is
      File        : File_Type;
      Text        : String (1 .. Max_Line_Length);
      Last        : Natural;
   begin
      Text := (1 .. Max_Line_Length => ' ');
      Open (File, In_File, File_Name);
      Go_To_Line (File, Line - 1);
      Ada.Text_IO.Get_Line (File, Text, Last);
      Close (File);
      return Text (1 .. Last);
   end Get_Line_From_File;

   ---------------------
   -- Line_Is_Comment --
   ---------------------

   function Line_Is_Comment
     (Line : String) return Boolean is
   begin
      if Line'Length > 5 then
         for J in 1 .. Line'Last - 3 loop
            if Line (J) = '-' and Line (J + 1) = '-' then
               return True;
            elsif Line (J) /= ' '
              and Line (J) /= ASCII.HT
              and Line (J) /= ASCII.LF
              and Line (J) /= ASCII.CR
            then return False;
            end if;
         end loop;
      end if;
      return False;
   end Line_Is_Comment;

   -------------------
   -- Line_Is_Empty --
   -------------------

   function Line_Is_Empty
     (Line : String) return Boolean is
   begin
      for J in 1 .. Line'Last loop
         if    Line (J) /= ' '
           and Line (J) /= ASCII.HT
           and Line (J) /= ASCII.LF
           and Line (J) /= ASCII.CR
         then
            return False;
         end if;
      end loop;
      return True;
   end Line_Is_Empty;

   --------------------------
   -- Is_Ignorable_Comment --
   --------------------------

   function Is_Ignorable_Comment
     (Comment_Line : String) return Boolean is
   begin
      if Comment_Line'Length > 5 then
         for J in 1 .. Comment_Line'Last - 3 loop
            if Comment_Line (J) = '-' and Comment_Line (J + 1) = '-' then
               if Comment_Line (J + 2) = '!' then
                  return True;
               else
                  return False;
               end if;
            end if;
         end loop;
      end if;
      return False;
   end Is_Ignorable_Comment;

   -----------------
   -- Kill_Prefix --
   -----------------

   function Kill_Prefix
     (Comment_Line : String) return String is
      J : Natural;
   begin
      J := 1;
      while (Comment_Line (J) /= '-' and Comment_Line (J + 1) /= '-') loop
         J := J + 1;
      end loop;
      return Comment_Line (J + 3 .. Comment_Line'Last);
   end Kill_Prefix;

   -----------------------
   --  Extract_Comment  --
   -----------------------

   function Extract_Comment
     (File_Name           : String;
      Line                : Natural;
      Header_Lines        : Natural;
      Package_Description : Boolean;
      Options             : All_Options) return String is

      New_Line, Old_Line : ASU.Unbounded_String;
      J                  : Natural;
      Char_Between       : Character;

   begin
      Old_Line := ASU.To_Unbounded_String ("");
      --  create one line or keep the formatting (for package description)
      if Package_Description then
         Char_Between := ASCII.LF;
      else
         Char_Between := ' ';
      end if;

      --  the comments under the header of the entity
      if Options.Comments_Under or Package_Description then
         J := Line + Header_Lines;
         --  the comments above the header of the entity
      else
         J := Line - 1;
      end if;

      New_Line := ASU.To_Unbounded_String (Get_Line_From_File (File_Name, J));
      while Line_Is_Comment (ASU.To_String (New_Line)) loop
         if Options.Comments_Under or Package_Description then
            J := J + 1;
            if not (Options.Ignorable_Comments and
                      Is_Ignorable_Comment (ASU.To_String (New_Line))) then
               if Package_Description then
                  Old_Line := Old_Line & Char_Between &
                    ASU.To_String (New_Line);
               else
                  Old_Line := Old_Line & Char_Between &
                    Kill_Prefix (ASU.To_String (New_Line));
               end if;
            end if;
         else
            J := J - 1;
            if not (Options.Ignorable_Comments and
                      Is_Ignorable_Comment (ASU.To_String (New_Line))) then
               if Package_Description then
                  Old_Line := ASU.To_String (New_Line) &
                    Char_Between & Old_Line;
               else
                  Old_Line := (Kill_Prefix (ASU.To_String (New_Line))) &
                    Char_Between & Old_Line;
               end if;
            end if;
         end if;
         New_Line := ASU.To_Unbounded_String
           (Get_Line_From_File (File_Name, J));
      end loop;
      return ASU.To_String (Old_Line);
   end Extract_Comment;

   -------------------------
   --  Exception_Renames  --   !!! needed?
   -------------------------

   function Exception_Renames
     (File_Name : String;
      Line      : Natural)
     return Unbounded_String is

      File        : File_Type;
      Last        : Natural;
      Text        : Unbounded_String;
      Result_Text : Unbounded_String;
      New_Line    : String (1 .. Max_Line_Length);

   begin
      Open (File, In_File, File_Name);

      Go_To_Line (File, Line - 1);
      Ada.Text_IO.Get_Line (File, New_Line, Last);
      Text := To_Unbounded_String (New_Line);

      if Index (Text, "renames") > 0 then
         Result_Text := To_Unbounded_String
           (" " &New_Line (Index (Text, "renames") .. Last - 1));
      else
         Result_Text := To_Unbounded_String ("");
      end if;

      Close (File);
      return Result_Text;
   end Exception_Renames;

   -----------------------
   -- Get_Doc_File_Name --
   -----------------------

   function Get_Doc_File_Name
     (Source_Filename : String;
      Source_Path     : String;
      Doc_Suffix      : String) return String is
      --  returns the complete name of the doc file

      Doc_File : ASU.Unbounded_String;
   begin
      Doc_File := ASU.To_Unbounded_String (Base_Name (Source_Filename));
      return Source_Path &
             (ASU.To_String (ASU.Replace_Slice
                                 (Doc_File,
                                  ASU.Index (Doc_File, "."),
                                ASU.Index (Doc_File, "."), "_")))
              & Doc_Suffix;
   end Get_Doc_File_Name;

   --------------------------
   -- Get_Line_From_String --
   --------------------------

   function Get_Line_From_String
     (Text    : String;
      Line_Nr : Natural) return String is
      Lines, Index_Start, Index_End : Natural;
   begin
      Lines       := 1;
      Index_Start := 1;
      if Line_Nr > 1 then
         while Index_Start < Text'Length and Lines < Line_Nr loop
            if Text (Index_Start) = ASCII.LF then
               Lines := Lines + 1;
            end if;
            Index_Start := Index_Start + 1;
         end loop;
      end if;
      Index_End := Index_Start + 1;
      while Index_End < Text'Length and Text (Index_End) /=  ASCII.LF loop
         Index_End := Index_End + 1;
      end loop;
      return Text (Index_Start .. Index_End);
   end Get_Line_From_String;

   ------------------------
   --  Get_Whole_Header  --
   ------------------------

   function Get_Whole_Header
     (File_Text   : String;
      Parsed_List : Construct_List;
      Entity_Name : String;
      Entity_Line : Natural) return GNAT.OS_Lib.String_Access is

      Parse_Node         : Construct_Access;
      Parsed_List_End    : Boolean;
      Result             : GNAT.OS_Lib.String_Access;
   begin
      Parse_Node      := Parsed_List.First;
      Parsed_List_End := False;

      --  exception if no paresed entities found: later

      while not Parsed_List_End loop
         if To_Lower (Parse_Node.Name.all) =
           To_Lower (Entity_Name) and
           Parse_Node.Sloc_Start.Line = Entity_Line then
            Result := new String (1 .. Parse_Node.Sloc_End.Index -
                                    Parse_Node.Sloc_Start.Index + 1);
            Result.all := File_Text (Parse_Node.Sloc_Start.Index ..
                                             Parse_Node.Sloc_End.Index);
            return Result;
         end if;
         if Parse_Node = Parsed_List.Last then
            Parsed_List_End := True;
         else
            Parse_Node := Parse_Node.Next;
         end if;
      end loop;
      return new String'("No Entity found by parser!");
   end Get_Whole_Header;

end Work_On_Source;
