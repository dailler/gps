-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2003                            --
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

with Gtk.Text_Buffer;   use Gtk.Text_Buffer;
with Gtk.Text_Iter;     use Gtk.Text_Iter;
with Gtk.Text_Mark;     use Gtk.Text_Mark;
with Gtk.Text_Tag;      use Gtk.Text_Tag;
with Gtk.Text_Tag_Table; use Gtk.Text_Tag_Table;
with Gtk.Text_View;     use Gtk.Text_View;
with Gtk.Main;          use Gtk.Main;
with Gtk.Handlers;      use Gtk.Handlers;
with Gtk.Widget;        use Gtk.Widget;
with Gdk.Event;         use Gdk.Event;
with Gdk.Types;         use Gdk.Types;
with Gdk.Types.Keysyms; use Gdk.Types.Keysyms;
with Glib;              use Glib;
with Glib.Properties;   use Glib.Properties;
with Histories;         use Histories;

with GNAT.OS_Lib;     use GNAT.OS_Lib;
with System;

package body Python.GUI is

   Trace_Count : Natural := 0;

   Trace_Threshold : constant Natural := 5000;
   --  How many traces event should we wait before checking the queue of gdk
   --  events ?

   Python_Key : constant History_Key := "python_console";

   package Interpreter_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk_Widget_Record, Boolean, Python_Interpreter);

   procedure Display_Prompt
     (Interpreter : access Python_Interpreter_Record'Class);
   --  Display the prompt in the shell window

   function Key_Press_Handler
     (Object : access Gtk_Widget_Record'Class;
      Event  : Gdk_Event;
      Interpreter : Python_Interpreter) return Boolean;
   --  Handle for "key_press" in the interpreter

   function Trace
     (User_Arg : PyObject;
      Frame    : System.Address;
      Why      : Why_Trace_Func;
      Obj      : PyObject) return Integer;
   pragma Convention (C, Trace);
   --  Suprogram called for each python instruction execution. It periodically
   --  checks the event queue, so that the interpreter can be interrupted.

   function Signal (Num : Integer; Handler : System.Address)
      return System.Address;
   pragma Import (C, Signal, "signal");

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Interpreter : access Python_Interpreter_Record'Class;
      History     : Histories.History)
   is
      Setup_Cmd : constant String :=
        "import sys, StringIO" & ASCII.LF &
        "sys.stdout=sys._capture=StringIO.StringIO()" & ASCII.LF &
        "sys.stderr=sys._capture_err=StringIO.StringIO()" & ASCII.LF;
      Main_Module : PyObject;
      Sigint      : constant Integer := 2;
      Old_Handler : System.Address;
      Prompt      : PyObject;

   begin
      --  Prevent python's standard Ctrl-C handling, to leave it to the calling
      --  application.
      Old_Handler := Signal (Sigint, System.Null_Address);
      Py_Initialize;
      Old_Handler := Signal (Sigint, Old_Handler);

      Interpreter.History := History;

      --  We need to set the program name, or some import commands will raise
      --  errors
      Py_SetProgramName ("Python_Interpreter");

      if not PyRun_SimpleString (Setup_Cmd) then
         raise Interpreter_Error;
      end if;

      Interpreter.Capture     := PySys_GetObject ("_capture");
      Interpreter.Capture_Err := PySys_GetObject ("_capture_err");

      if Interpreter.Capture = null or else Interpreter.Capture_Err = null then
         raise Interpreter_Error;
      end if;

      Main_Module := PyImport_AddModule ("__main__");
      if Main_Module = null then
         raise Interpreter_Error;
      end if;
      Interpreter.Globals := PyModule_GetDict (Main_Module);

      Prompt := PySys_GetObject ("ps1");
      if Prompt = null then
         Prompt := PyString_FromString (">>> ");
         PySys_SetObject ("ps1", Prompt);
         Py_DECREF (Prompt);
      end if;

      Prompt := PySys_GetObject ("ps2");
      if Prompt = null then
         Prompt := PyString_FromString ("... ");
         PySys_SetObject ("ps2", Prompt);
         Py_DECREF (Prompt);
      end if;

      Interpreter.Buffer := new String'("");

      PyEval_SetTrace (Trace'Access, null);
   end Initialize;

   -----------------
   -- Set_Console --
   -----------------

   procedure Set_Console
     (Interpreter : access Python_Interpreter_Record'Class;
      Console     : access Gtk.Text_View.Gtk_Text_View_Record'Class) is
   begin
      Interpreter.Console := Gtk_Text_View (Console);

      if Interpreter.Uneditable /= null then
         Unref (Interpreter.Uneditable);
      end if;

      if Interpreter.Console /= null then
         --  Disconnect previous key_press_event signal
         Disconnect (Interpreter.Console, Interpreter.Key_Press_Id);
      end if;

      Gtk_New (Interpreter.Uneditable);
      Set_Property (Interpreter.Uneditable, Editable_Property, False);
      Add (Get_Tag_Table (Get_Buffer (Console)), Interpreter.Uneditable);
      --  ??? Never unref-ed

      Interpreter.Key_Press_Id := Interpreter_Callback.Connect
        (Console, "key_press_event",
         Interpreter_Callback.To_Marshaller (Key_Press_Handler'Access),
         Python_Interpreter (Interpreter));

      Display_Prompt (Interpreter);
   end Set_Console;

   -----------
   -- Trace --
   -----------

   function Trace
     (User_Arg : PyObject;
      Frame    : System.Address;
      Why      : Why_Trace_Func;
      Obj      : PyObject) return Integer
   is
      Dead : Boolean;
      pragma Unreferenced (Dead, Obj, Frame, Why, User_Arg);
   begin
      Trace_Count := Trace_Count + 1;
      if Trace_Count = Trace_Threshold then
         while Gtk.Main.Events_Pending loop
            Dead := Gtk.Main.Main_Iteration;
         end loop;
         Trace_Count := 0;
      end if;
      return 0;
   end Trace;

   -----------------
   -- Run_Command --
   -----------------

   procedure Run_Command
     (Interpreter : access Python_Interpreter_Record'Class;
      Command     : String;
      Hide_Output : Boolean := False)
   is
      Obj            : PyObject;
      Code           : PyCodeObject;
      Result, Stream : PyObject;
      Iter           : Gtk_Text_Iter;
      Buffer         : constant Gtk_Text_Buffer :=
        Get_Buffer (Interpreter.Console);
      Tmp            : String_Access;
      Indented_Input : constant Boolean := Command'Length > 0
        and then (Command (Command'First) = ASCII.HT
                  or else Command (Command'First) = ' ');
      Cmd : constant String := Interpreter.Buffer.all & Command & ASCII.LF;
   begin
      if Cmd = "" & ASCII.LF then
         if not Hide_Output then
            Display_Prompt (Interpreter);
         end if;
         return;
      end if;

      Get_End_Iter (Buffer, Iter);
      Code := Py_CompileString (Cmd, "<stdin>", Py_Single_Input);

      --  If code compiled just fine
      if Code /= null and then not Indented_Input then
         Obj := PyEval_EvalCode
           (Code, Interpreter.Globals, Interpreter.Globals);
         Py_DECREF (PyObject (Code));

         if Obj = null then
            PyErr_Print;
            Stream := Interpreter.Capture_Err;
         else
            Py_DECREF (Obj);
            Stream := Interpreter.Capture;
         end if;

         Interpreter.Use_Secondary_Prompt := False;
         Result := PyObject_CallMethod (Stream, "getvalue");
         if not Hide_Output then
            Insert (Buffer, Iter, PyString_AsString (Result));
         end if;
         Free (Interpreter.Buffer);
         Interpreter.Buffer := new String'("");

      --  Do we have compilation error because input was incomplete ?

      elsif not Hide_Output then
         Interpreter.Use_Secondary_Prompt := Indented_Input;

         if not Interpreter.Use_Secondary_Prompt then
            PyErr_Print;
            Stream := Interpreter.Capture_Err;
            Result := PyObject_CallMethod (Stream, "getvalue");

            declare
               Str : constant String := PyString_AsString (Result);
               Eof : constant String :=
                 "unexpected EOF while parsing" & ASCII.LF;
            begin
               Interpreter.Use_Secondary_Prompt := Str'Length > Eof'Length
                 and then Str (Str'Last - Eof'Length + 1 .. Str'Last) = Eof;
            end;
         else
            Stream := null;
         end if;

         if Interpreter.Use_Secondary_Prompt then
            Tmp := Interpreter.Buffer;
            Interpreter.Buffer := new String'
              (Interpreter.Buffer.all & Command & ASCII.LF);
            Free (Tmp);
         else
            Insert (Buffer, Iter, PyString_AsString (Result));
            Free (Interpreter.Buffer);
            Interpreter.Buffer := new String'("");
         end if;
      end if;

      if Stream /= null then
         Py_DECREF (Result);

         Result := PyObject_CallMethod (Stream, "seek", 0);
         Py_DECREF (Result);
         Result := PyObject_CallMethod (Stream, "truncate");
         Py_DECREF (Result);
      end if;

      if not Hide_Output then
         Display_Prompt (Interpreter);
      end if;
   end Run_Command;

   --------------------
   -- Display_Prompt --
   --------------------

   procedure Display_Prompt
     (Interpreter : access Python_Interpreter_Record'Class)
   is
      Buffer : constant Gtk_Text_Buffer := Get_Buffer (Interpreter.Console);
      Iter, First_Iter : Gtk_Text_Iter;
      Ps     : PyObject;
   begin
      Get_End_Iter (Buffer, Iter);
      if Interpreter.Use_Secondary_Prompt then
         Ps := PySys_GetObject ("ps2");
      else
         Ps := PySys_GetObject ("ps1");
      end if;

      Insert (Buffer, Iter, PyString_AsString (Ps));

      Get_End_Iter (Buffer, Iter);

      if Interpreter.Prompt_End_Mark = null then
         Interpreter.Prompt_End_Mark := Create_Mark (Buffer, "", Iter);
      else
         Move_Mark (Buffer, Interpreter.Prompt_End_Mark, Iter);
      end if;

      Get_Start_Iter (Buffer, First_Iter);
      Apply_Tag (Buffer, Interpreter.Uneditable, First_Iter, Iter);

      Place_Cursor (Buffer, Iter);
      Scroll_Mark_Onscreen (Interpreter.Console, Get_Insert (Buffer));
   end Display_Prompt;

   -----------------------
   -- Key_Press_Handler --
   -----------------------

   function Key_Press_Handler
     (Object      : access Gtk_Widget_Record'Class;
      Event       : Gdk_Event;
      Interpreter : Python_Interpreter) return Boolean
   is
      pragma Unreferenced (Object);
      Buffer    : constant Gtk_Text_Buffer := Get_Buffer (Interpreter.Console);
      Key       : constant Gdk_Key_Type    := Get_Key_Val (Event);
      Iter, Prompt_End : Gtk_Text_Iter;
      Success : Boolean;
   begin
      case Key is
         when GDK_Up | GDK_Down =>
            declare
               Hist : constant String_List_Access := Get_History
                 (Interpreter.History.all, Python_Key);
            begin
               if Hist /= null then
                  if Key = GDK_Up
                    and then
                    Interpreter.History_Position + Hist'First < Hist'Last
                  then
                     Interpreter.History_Position :=
                       Interpreter.History_Position + 1;

                  elsif Key = GDK_Down
                    and then Interpreter.History_Position /= -1
                  then
                     Interpreter.History_Position :=
                       Interpreter.History_Position - 1;
                  end if;
               end if;

               Get_Iter_At_Mark
                 (Buffer, Prompt_End, Interpreter.Prompt_End_Mark);
               Get_End_Iter (Buffer, Iter);
               Delete (Buffer, Prompt_End, Iter);
               if Interpreter.History_Position /= -1 then
                  Insert
                    (Buffer, Prompt_End,
                     Hist (Hist'First + Interpreter.History_Position).all);
               end if;

               Get_End_Iter (Buffer, Iter);
               Place_Cursor (Buffer, Iter);
            end;

            return True;

         when GDK_Left =>
            --  Refuse if before prompt
            Get_Iter_At_Mark
              (Buffer, Prompt_End, Interpreter.Prompt_End_Mark);
            Get_Iter_At_Mark (Buffer, Iter, Get_Insert (Buffer));
            return Compare (Prompt_End, Iter) > -1;

         when GDK_Return | GDK_KP_Enter =>
            Get_End_Iter (Buffer, Iter);
            Insert (Buffer, Iter, ASCII.LF & "");
            Backward_Char (Iter, Success);

            Get_Iter_At_Mark (Buffer, Prompt_End, Interpreter.Prompt_End_Mark);
            Add_To_History
              (Interpreter.History.all, Python_Key,
               Get_Slice (Buffer, Prompt_End, Iter));
            Interpreter.History_Position := -1;

            Run_Command (Interpreter, Get_Slice (Buffer, Prompt_End, Iter));
            return True;

         when GDK_LC_c =>
            if Get_State (Event) = Control_Mask then
               PyErr_SetInterrupt;
               return True;
            end if;

         when others =>
            null;
      end case;
      return False;
   end Key_Press_Handler;

end Python.GUI;
