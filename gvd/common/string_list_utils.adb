-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                      Copyright (C) 2001-2002                      --
--                            ACT-Europe                             --
--                                                                   --
-- GPS is free  software; you can  redistribute it and/or modify  it --
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

package body String_List_Utils is

   use String_List;

   ----------------------
   -- Copy_String_List --
   ----------------------

   function Copy_String_List
     (S : in String_List.List) return String_List.List
   is
      Result : String_List.List;
      Temp   : List_Node := First (S);

   begin
      while Temp /= Null_Node loop
         Append (Result, Data (Temp));
         Temp := Next (Temp);
      end loop;

      return Result;
   end Copy_String_List;

   -----------------
   -- String_Free --
   -----------------

   procedure String_Free (S : in out String) is
      pragma Unreferenced (S);
   begin
      null;
   end String_Free;

   ----------------------
   -- Remove_From_List --
   ----------------------

   procedure Remove_From_List
     (L               : in out String_List.List;
      S               : String;
      All_Occurrences : Boolean := True)
   is
      Node      : List_Node;
      Prev_Node : List_Node := Null_Node;
   begin
      Node := First (L);

      while Node /= Null_Node loop
         if Data (Node) = S then
            Remove_Nodes (L, Prev_Node, Node);

            if not All_Occurrences then
               return;
            end if;

            if Prev_Node = Null_Node then
               Node := First (L);
            else
               Node := Prev_Node;
            end if;

            if Node = Null_Node then
               return;
            end if;
         end if;

         Prev_Node := Node;
         Node := Next (Node);
      end loop;
   end Remove_From_List;

   ----------------
   -- Is_In_List --
   ----------------

   function Is_In_List
     (L : String_List.List;
      S : String)
     return Boolean
   is
      Node : List_Node := First (L);
   begin
      while Node /= Null_Node loop
         if S = Data (Node) then
            return True;
         end if;

         Node := Next (Node);
      end loop;

      return False;
   end Is_In_List;

end String_List_Utils;
