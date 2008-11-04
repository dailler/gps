-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                   Copyright (C) 2008, AdaCore                     --
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

with GPS.Kernel.Standard_Hooks;

package Code_Coverage.Gcov is

   type Gcov_Line_Coverage_Status is
     (No_Code,
      Not_Covered,
      Covered,
      Undetermined);

   type Gcov_Line_Coverage is new Code_Analysis.Line_Coverage with record
      Status : Gcov_Line_Coverage_Status := Undetermined;
   end record;

   overriding function Is_Valid (Self : Gcov_Line_Coverage) return Boolean;

   overriding function Line_Coverage_Info
     (Coverage : Gcov_Line_Coverage;
      Bin_Mode : Boolean := False)
      return GPS.Kernel.Standard_Hooks.Line_Information_Record;

   procedure Add_File_Info
     (File_Node     : Code_Analysis.File_Access;
      File_Contents : String_Access);
   --  Parse the File_Contents and fill the File_Node with gcov info
   --  And set Line_Count and Covered_Lines

end Code_Coverage.Gcov;
