-----------------------------------------------------------------------
--                   GVD - The GNU Visual Debugger                   --
--                                                                   --
--                      Copyright (C) 2000-2003                      --
--                              ACT-Europe                           --
--                                                                   --
-- GVD is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with GNAT.Regpat; use GNAT.Regpat;
with Pixmaps_IDE; use Pixmaps_IDE;
with Language.C;  use Language.C;

package body Language.Cpp is

   Keywords_List : constant Pattern_Matcher := Compile
     ("^(" & C_Keywords_Regexp &
      "|a(bstract|sm)|bool|c(atch|lass|onst_cast)|d(elete|ynamic_cast)|" &
      "explicit|f(alse|inal|riend)|interface|mutable|n(amespace|ew)|operator" &
      "p(r(ivate|otected)|ublic)|reinterpret_cast|s(tatic_cast|ynchronized)|" &
      "t(emplate|h(is|hrow)|r(ue|y)|ype(id|name))|using|virtual|wchar_t"
      & ")\W");

   Classes_RE : aliased Pattern_Matcher :=
     Compile ("^\s*(class|struct)\s+([\w_]+)\s*(:[^{]+)?\{", Multiple_Lines);

   Methods_RE : aliased Pattern_Matcher :=
     Compile                  --  Based on Language.C.Subprogram_RE
       ("^(\w+\s+)?"
        & "([\w_*]+\s+)?"
        & "([\w_*]+\s+)?"
        & "([*&]+\s*)?"
        & "([\w_*]+(::[\w_*]+)+)\s*"  -- method name
        & "\([^(]",
        Multiple_Lines);

   function Make_Entry_Class
     (Str      : String;
      Matched  : Match_Array) return String;
   --  Function used to create an entry in the explorer, for classes.
   --  See the description of Explorer_Categories for more information.

   Cpp_Explorer_Categories : constant Explorer_Categories (1 .. 2) :=
     (1 => (Category       => Cat_Class,
            Regexp         => Classes_RE'Access,
            Position_Index => 2,
            Icon           => package_xpm'Access,
            Make_Entry     => Make_Entry_Class'Access),
      2 => (Category       => Cat_Method,
            Regexp         => Methods_RE'Access,
            Position_Index => 5,
            Icon           => subprogram_xpm'Access,
            Make_Entry     => null));

   ----------------------
   -- Make_Entry_Class --
   ----------------------

   function Make_Entry_Class
     (Str      : String;
      Matched  : Match_Array) return String is
   begin
      return Str (Matched (1).First .. Matched (1).Last)
        & " " & Str (Matched (2).First .. Matched (2).Last);
   end Make_Entry_Class;

   ----------------------
   -- Explorer_Regexps --
   ----------------------

   function Explorer_Regexps
     (Lang : access Cpp_Language) return Explorer_Categories is
   begin
      return Explorer_Regexps (C_Language (Lang.all)'Access)
        & Cpp_Explorer_Categories;
   end Explorer_Regexps;

   --------------
   -- Keywords --
   --------------

   function Keywords
     (Lang : access Cpp_Language) return GNAT.Regpat.Pattern_Matcher
   is
      pragma Unreferenced (Lang);
   begin
      return Keywords_List;
   end Keywords;

   --------------------------
   -- Get_Language_Context --
   --------------------------

   function Get_Language_Context
     (Lang : access Cpp_Language) return Language_Context
   is
      pragma Unreferenced (Lang);
   begin
      return
        (Comment_Start_Length          => 2,
         Comment_End_Length            => 2,
         New_Line_Comment_Start_Length => 2,
         Comment_Start                 => "/*",
         Comment_End                   => "*/",
         New_Line_Comment_Start        => "//",
         String_Delimiter              => '"',
         Quote_Character               => '\',
         Constant_Character            => ''',
         Can_Indent                    => True,
         Syntax_Highlighting           => True,
         Case_Sensitive                => True);
   end Get_Language_Context;

   --------------------
   -- Parse_Entities --
   --------------------

   procedure Parse_Entities
     (Lang     : access Cpp_Language;
      Buffer   : String;
      Callback : Entity_Callback)
   is
      pragma Unreferenced (Lang);
      pragma Suppress (All_Checks);
      --  See comment in Language.C.Parse_Entities

      Ignored     : Natural;
      No_Contents : Boolean;

   begin
      Analyze_C_Source
        (Buffer        => Buffer,
         Indent        => Ignored,
         Indent_Params => Default_Indent_Parameters,
         No_Contents   => No_Contents,
         Callback      => Callback,
         Enable_Cpp    => True);
   end Parse_Entities;

end Language.Cpp;
