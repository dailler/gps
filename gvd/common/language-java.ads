-----------------------------------------------------------------------
--                 Odd - The Other Display Debugger                  --
--                                                                   --
--                         Copyright (C) 2000                        --
--                 Emmanuel Briot and Arnaud Charlet                 --
--                                                                   --
-- Odd is free  software;  you can redistribute it and/or modify  it --
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

package Language.Debugger.Java is

   type Java_Language is abstract new Language_Debugger with private;

   function Is_Simple_Type (Lang : Java_Language; Str : String) return Boolean;
   --  Return True if Str is a simple type, like integer, ...

   procedure Looking_At (Lang    : Java_Language;
                         Buffer  : String;
                         Entity  : out Language_Entity;
                         To_Skip : out Positive);

private

   type Java_Language is abstract new Language_Debugger with null record;

end Language.Debugger.Java;
