-----------------------------------------------------------------------
--                          G L I D E  I I                           --
--                                                                   --
--                        Copyright (C) 2001-2002                    --
--                            ACT-Europe                             --
--                                                                   --
-- GLIDE is free software; you can redistribute it and/or modify  it --
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

--  This package provides the low-level implementation of the queries that need
--  information from the compiler (like dependencies, cross-references,...
--
--  You shouldn't use this package directly, but instead call the higher-level
--  routines in glide_kernel.*.
--
--  One general note on the design of this package: this package must be
--  independant of the kernel (e.g take explicit an source_path, instead of a
--  handle to the kernel), so that it can eventually be integrated directly
--  into the sources of Gnat and its tools.

with Traces;
with Unchecked_Deallocation;
with Language_Handlers;
with Prj.Tree;
with Prj_API;
with Basic_Types;
with String_Hash;

package Src_Info.Queries is

   -------------------------
   --  Entity information --
   -------------------------
   --  This type groups information about entities that allow an exact
   --  identification of that entity, including handling of overriding
   --  subprograms,... This information has a life-cycle independent from the
   --  tree itself, and thus can be kept independently in a browser.

   type Entity_Information is private;
   No_Entity_Information : constant Entity_Information;

   procedure Destroy (Entity : in out Entity_Information);
   --  Free the memory associated with the entity;

   function Get_Name (Entity : Entity_Information) return String;
   --  Return the name of the entity associated with Node.

   function Get_Declaration_Line_Of
     (Entity : Entity_Information) return Positive;
   function Get_Declaration_Column_Of
     (Entity : Entity_Information) return Natural;
   function Get_Declaration_File_Of
     (Entity : Entity_Information) return String;
   --  Return the location of the declaration for Entity. Note that this
   --  location remains valid only until the source file are changed. It is not
   --  magically updated when the source file is changed.

   function Copy (Entity : Entity_Information) return Entity_Information;
   --  Return a copy of Entity. The result must be explicitely destroyed.

   --------------------------------------
   -- Goto Declaration<->Body requests --
   --------------------------------------

   type Find_Decl_Or_Body_Query_Status is
     (Entity_Not_Found,
      Internal_Error,
      No_Body_Entity_Found,
      Success);
   --  The status returned by the Find_Declaration_Or_Body routine.

   procedure Find_Declaration_Or_Body
     (Lib_Info      : LI_File_Ptr;
      File_Name     : String;
      Entity_Name   : String;
      Line          : Positive;
      Column        : Positive;
      Entity        : out Entity_Information;
      Location      : out File_Location;
      Status        : out Find_Decl_Or_Body_Query_Status);
   --  Find the location of the declaration for the entity referenced in file
   --  File_Name, at the given location.
   --  On exit, Entity is set to the declaration of the entity.
   --  Location is set to the location where the cursor should be moved (the
   --  next body reference, or the declaration, for instance).
   --
   --  If no entity could be found, Status is set to a value other than
   --  Success. In that case, Entity and Location are irrelevant.
   --
   --  The memory occupied by Entity must be freed by the caller.
   --
   --  Note: Location has a short term life: it can no longer be used once you
   --  reparse Lib_Info, or update its contents.

   ---------------------------
   -- Spec <-> Body queries --
   ---------------------------

   function Get_Other_File_Of
     (Lib_Info : LI_File_Ptr; Source_Filename : String) return String;
   --  Return the name of the spec or body for Source_Filename.
   --  If Source_Filename is a separate, then the spec of the unit is returned.
   --  The empty string is returned if there is no other file (for instance, a
   --  body without a spec).
   --  Only the short path name is returned.
   --
   --  This method is based on LI files.

   ----------------
   -- References --
   ----------------

   type Entity_Reference_Iterator is private;
   type Entity_Reference_Iterator_Access is access Entity_Reference_Iterator;

   procedure Find_All_References
     (Root_Project : Prj.Tree.Project_Node_Id;
      Lang_Handler : Language_Handlers.Language_Handler;
      Entity       : Entity_Information;
      List         : in out LI_File_List;
      Iterator     : out Entity_Reference_Iterator;
      Project      : Prj.Project_Id := Prj.No_Project;
      LI_Once      : Boolean := False);
   --  Find all the references to the entity described in Decl.
   --  Root_Project should be the root project under which we are looking.
   --  Source files that don't belong to Root_Project or one of its imported
   --  project will not be searched.
   --  Project is the project to which the file where the declaration is found
   --  belongs. It can optionally be left to Empty_Node if this is not known,
   --  but the search will take a little bit longer.
   --  Note also that the declaration itself is not returned.
   --
   --  if LI_Once is True, then a single reference will be returned for each LI
   --  file. This can be used for instance if you are only looking for matching
   --  LI files.
   --
   --  You must destroy the iterator when you are done with it, to avoid memory
   --  leaks.

   procedure Next
     (Lang_Handler : Language_Handlers.Language_Handler;
      Iterator : in out Entity_Reference_Iterator;
      List     : in out LI_File_List);
   --  Get the next reference to the entity

   function Get (Iterator : Entity_Reference_Iterator) return E_Reference;
   --  Return the reference currently pointed to. No_Reference is returned if
   --  there are no more reference.

   function Get_LI (Iterator : Entity_Reference_Iterator) return LI_File_Ptr;
   --  Return the current LI file

   procedure Destroy (Iterator : in out Entity_Reference_Iterator);
   procedure Destroy (Iterator : in out Entity_Reference_Iterator_Access);
   --  Free the memory occupied by the iterator.

   ---------------------------
   -- Dependencies requests --
   ---------------------------

   type Dependency is private;
   --  This type contains the following information:
   --    - Information on the file on which we depend
   --    - Information on the dependency itself: whether it comes from the spec
   --      and/or from the body, or is implicit.
   --  In the context of Ada, explicit dependencies represent "with" statements

   type Dependency_Node;
   type Dependency_List is access Dependency_Node;
   type Dependency_Node is record
      Value : Dependency;
      Next  : Dependency_List;
   end record;
   --  A list of dependencies.

   procedure Destroy (Dep  : in out Dependency);
   procedure Destroy (List : in out Dependency_List);
   --  Destroy the given list, and deallocates all the memory associated.
   --  Has no effect if List is null.

   function File_Information (Dep : Dependency) return Internal_File;
   --  Return the information on the file that Dep depends on.
   --  You mustn't free the returned value, since it points to internal
   --  data. However, you must keep a copy if you intend to store it somewhere.

   function Dependency_Information (Dep : Dependency) return Dependency_Info;
   --  Return the information on the dependency itself. This doesn't contain
   --  information about the files.

   type Dependencies_Query_Status is
     (Failure,
      Internal_Error,
      Success);
   --  The status returned by the Find_Dependencies routine.

   procedure Find_Dependencies
     (Lib_Info        : LI_File_Ptr;
      Source_Filename : String;
      Dependencies    : out Dependency_List;
      Status          : out Dependencies_Query_Status);
   --  Return the list of units on which the units associated to the given
   --  LI_File depend. Note that the dependencies.
   --  Note that only the direct dependencies for Source_Filename are returned
   --  (or the implicit dependencies). If Source_Filename is a spec, then the
   --  files imported from the body are not returned.
   --
   --  The list returned by this procedure should be deallocated after use.

   type Dependency_Iterator is private;
   type Dependency_Iterator_Access is access Dependency_Iterator;

   procedure Find_Ancestor_Dependencies
     (Root_Project    : Prj.Tree.Project_Node_Id;
      Lang_Handler    : Language_Handlers.Language_Handler;
      Source_Filename : String;
      List            : in out LI_File_List;
      Iterator        : out Dependency_Iterator;
      Project         : Prj.Project_Id := Prj.No_Project;
      Include_Self    : Boolean := False;
      Predefined_Source_Path : String := "";
      Predefined_Object_Path : String := "");
   --  Prepare Iterator to return the list of all files that import
   --  one of the files associated with the Unit of Source_Filename (that is it
   --  will return files that depend either on the spec or the body of
   --  Source_Filename).
   --  Root_Project should be the root project under which we are looking.
   --  Source files that don't belong to Root_Project or one of its imported
   --  project will not be searched.
   --  Project is the project to which the file where the declaration is found
   --  belongs. It can optionally be left to Empty_Node if this is not known,
   --  but the search will take a little bit longer.
   --
   --  If Include_Self is true, then the LI file for Source_Filename will also
   --  be returned. Note, in this case the Dependency returned by Get is pretty
   --  much irrelevant, and shouldn't be used.
   --
   --  You must destroy the iterator when you are done with it, to avoid memory
   --  leaks.

   procedure Next
     (Lang_Handler : Language_Handlers.Language_Handler;
      Iterator : in out Dependency_Iterator;
      List     : in out LI_File_List);
   --  Get the next reference to the entity

   function Get (Iterator : Dependency_Iterator) return Dependency;
   --  Return the file pointed to. You must free the returned value.

   function Get (Iterator : Dependency_Iterator) return LI_File_Ptr;
   --  Return the LI for the file that contains the dependency. Note that this
   --  is not the LI file for Dependency, as returned by Get.

   procedure Destroy (Iterator : in out Dependency_Iterator);
   procedure Destroy (Iterator : in out Dependency_Iterator_Access);
   --  Free the memory occupied by the iterator.

   ----------------
   -- Scope tree --
   ----------------
   --  A scope tree is the base structure for the call graph and the type
   --  browser.
   --  Such a tree is generated from an LI structure, and becomes obsolete as
   --  soon as that structure is scanned again (since we keep pointers to the
   --  internal nodes of the structure

   type Scope_Tree is private;
   Null_Scope_Tree : constant Scope_Tree;

   type Scope_Tree_Node is private;
   Null_Scope_Tree_Node : constant Scope_Tree_Node;

   function Create_Tree (Lib_Info : LI_File_Ptr) return Scope_Tree;
   --  Create a new scope tree from an already parsed Library information.
   --  Note that the resulting tree needs to be freed whenever Lib_Info
   --  changes, since the tree points to internal nodes of Lib_Info.

   procedure Free (Tree : in out Scope_Tree);
   --  Free the memory occupied by Tree.

   procedure Trace_Dump
     (Handler              : Traces.Debug_Handle;
      Tree                 : Scope_Tree;
      Node                 : Scope_Tree_Node := Null_Scope_Tree_Node;
      Subprograms_Pkg_Only : Boolean := True);
   --  Dump the contentns of the tree to standard_output.

   function Find_Entity_Scope
     (Tree : Scope_Tree; Entity : Entity_Information) return Scope_Tree_Node;
   --  Return the declaration node for the entity Name that is referenced
   --  at position Line, Column.

   type Node_Callback is access procedure (Node : Scope_Tree_Node);
   --  Called for each node matching a given criteria.

   procedure Find_Entity_References
     (Tree : Scope_Tree;
      Entity : Entity_Information;
      Callback : Node_Callback);
   --  Search all the references to the entity Decl in the tree

   function Get_Parent (Node : Scope_Tree_Node) return Scope_Tree_Node;
   --  Return the parent of Node, or Null_Scope_Tree_Node if there is no
   --  parent.

   function Is_Subprogram (Node : Scope_Tree_Node) return Boolean;
   --  Return True if Node is associated with a subprogram (either its
   --  declaration or a call to it).

   function Get_Entity (Node : Scope_Tree_Node) return Entity_Information;
   --  Return the information for the entity defined in Node.
   --  You must call Destroy on the returned information.

   --------------------------
   -- Scope tree iterators --
   --------------------------

   type Scope_Tree_Node_Iterator is private;

   function Start (Node : Scope_Tree_Node) return Scope_Tree_Node_Iterator;
   --  Return the first child of Node

   procedure Next (Iter : in out Scope_Tree_Node_Iterator);
   --  Move to the next sibling of Iter

   function Get (Iter : Scope_Tree_Node_Iterator) return Scope_Tree_Node;
   --  Return the node pointed to by Iter, or null if Iter is invalid.

private

   type Dependency is record
      File  : Src_Info.Internal_File;
      Dep   : Src_Info.Dependency_Info;
   end record;

   type Scope_Type is (Declaration, Reference);
   --  The type for the elements in the scope: these are either a
   --  declaration, with subranges or subdeclarations, or a reference to
   --  another entity.

   type Entity_Information is record
      Name        : String_Access;
      Decl_Line   : Positive;
      Decl_Column : Natural;
      Decl_File   : String_Access;
   end record;

   No_Entity_Information : constant Entity_Information :=
     (null, 1, 0, null);

   type Scope_Node;
   type Scope_List is access Scope_Node;
   type Scope_Node (Typ : Scope_Type) is record
      Sibling : Scope_List;
      Parent  : Scope_List;
      --  Pointer to the next item at the same level.

      Decl : E_Declaration_Access;
      --  The declaration of the entity

      case Typ is
         when Declaration =>
            Start_Of_Scope : File_Location;
            Contents : Scope_List;

         when Reference =>
            Ref : E_Reference_Access;
      end case;
   end record;

   type Scope_List_Array is array (Natural range <>) of Scope_List;
   type Scope_List_Array_Access is access Scope_List_Array;
   procedure Free is new Unchecked_Deallocation
     (Scope_List_Array, Scope_List_Array_Access);

   type Scope_Tree is record
      Lib_Info    : LI_File_Ptr;
      LI_Filename : String_Access;
      Time_Stamp  : Timestamp;
      --  For efficiency, we keep an access to the LI file that was used to
      --  create the tree. However, we also keep the file name itself, so that
      --  we can check whether the LI file was updated, and the tree is no
      --  longer valid.

      Body_Tree : Scope_List;
      Spec_Tree : Scope_List;
      Separate_Trees : Scope_List_Array_Access;
      --  The information for the source files associated with Lib_Info.
   end record;
   --  This tree represents the global scope information for the files
   --  associated with Lib_Info (spec, body and separate).

   type Scope_Tree_Node is new Scope_List;
   type Scope_Tree_Node_Iterator is new Scope_List;

   Null_Scope_Tree_Node : constant Scope_Tree_Node := null;

   Null_Scope_Tree : constant Scope_Tree :=
     (Lib_Info       => null,
      LI_Filename    => null,
      Time_Stamp     => 0,
      Body_Tree      => null,
      Spec_Tree      => null,
      Separate_Trees => null);

   package Name_Htable is new String_Hash (Boolean, False);

   type Dependency_Iterator is record
      Decl_LI : LI_File_Ptr;
      --  The file we are looking for.

      Source_Filename : String_Access;
      --  Name of the source file that we are examining.

      Importing : Prj_API.Project_Id_Array_Access;
      --  List of projects to check

      Current_Project : Natural;
      --  The current project in the list above

      Examined     : Name_Htable.String_Hash_Table.HTable;
      --  List of source files in the current project that have already been
      --  examined.

      Source_Files : Basic_Types.String_Array_Access;
      --  The list of source files in the current project

      Current_File : Natural;
      --  The current source file

      Current_Decl : Dependency_File_Info_List;
      --  The current declaration

      Include_Self : Boolean;
      --  Whether we should return the LI file for Decl_LI

      LI : LI_File_Ptr;
   end record;

   type Entity_Reference_Iterator is record
      Entity    : Entity_Information;
      Decl_Iter : Dependency_Iterator;

      References : E_Reference_List;
      --  The current list of references we are processing.

      LI_Once : Boolean;
      --  True if we should return only one reference per LI file

      Part : Unit_Part;
      Current_Separate : File_Info_Ptr_List;
      --  If the LI file we are examining is the file in which the entity was
      --  declared, we need to examine the body, spec, and separates, and part
      --  indicates which part we are examining
   end record;

   pragma Inline (File_Information);
   pragma Inline (Dependency_Information);
end Src_Info.Queries;
