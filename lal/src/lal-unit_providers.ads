------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                       Copyright (C) 2017, AdaCore                        --
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
--  This package provides access to compilation units of GPS environment.

with GPS.Core_Kernels;
with Libadalang.Analysis;

package LAL.Unit_Providers is

   type Unit_Provider is
     new Libadalang.Analysis.Unit_Provider_Interface with private;

   procedure Initialize
     (Self   : in out Unit_Provider'Class;
      Kernel : GPS.Core_Kernels.Core_Kernel);

private

   type Unit_Provider is
     new Libadalang.Analysis.Unit_Provider_Interface with
   record
       Kernel : GPS.Core_Kernels.Core_Kernel;
   end record;

   overriding function Get_Unit
     (Provider    : Unit_Provider;
      Context     : Libadalang.Analysis.Analysis_Context;
      Node        : Libadalang.Analysis.Ada_Node;
      Kind        : Libadalang.Analysis.Unit_Kind;
      Charset     : String := "";
      Reparse     : Boolean := False;
      With_Trivia : Boolean := False) return Libadalang.Analysis.Analysis_Unit;

   overriding function Get_Unit
     (Provider    : Unit_Provider;
      Context     : Libadalang.Analysis.Analysis_Context;
      Name        : Wide_Wide_String;
      Kind        : Libadalang.Analysis.Unit_Kind;
      Charset     : String := "";
      Reparse     : Boolean := False;
      With_Trivia : Boolean := False) return Libadalang.Analysis.Analysis_Unit;

end LAL.Unit_Providers;
