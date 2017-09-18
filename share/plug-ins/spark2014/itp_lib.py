# TODO Remove unnecessary libs
import GPS
import sys
import os_utils
import os.path
import tool_output
import json
import re
from os import *
# Import graphics Gtk libraries for proof interactive elements
from gi.repository import Gtk, Gdk, GLib, Pango
import pygps
from modules import Module
from gps_utils.console_process import Console_Process
import fnmatch

debug_mode = False


def print_debug(s):
    if debug_mode:
        print(s)


def print_error(message, prompt=True):
    console = GPS.Console("ITP_interactive")
    console.write(message, mode="error")
    if prompt:
        console.write("\n> ")
    else:
        console.write("\n")


def print_message(message, prompt=True):
    console = GPS.Console("ITP_interactive")
    console.write(message, mode="text")
    if prompt:
        console.write("\n> ")
    else:
        console.write("\n")

green = Gdk.RGBA(0, 1, 0, 0.2)
red = Gdk.RGBA(1, 0, 0, 0.2)


# This function converts a string "Not proved" etc into a color for the
# background of the goal tree.
def create_color(s):
    if s == "Proved":
        return green
    elif s == "Invalid":
        return red
    elif s == "Not Proved":
        return red
    elif s == "Obsolete":
        return red
    elif s == "Valid":
        return green
    elif s == "Not Valid":
        return red
    elif s == "Not Installed":
        return red
    else:
        return red


# This functions takes a Json object and a proof tree and treat it as a
# notification on the proof tree. It makes the appropriate update to the tree
# model.
# TODO add exceptions
def parse_notif(j, tree, proof_task):
    print_debug(j)
    # TODO rewrite this
    abs_tree = tree
    tree = tree.tree
    try:
        notif_type = j["notification"]
    except:
        print_debug("This is a valid json string but an invalid notification")
    if notif_type == "New_node":
        node_id = j["node_ID"]
        parent_id = j["parent_ID"]
        node_type = j["node_type"]
        name = j["name"]
        detached = j["detached"]
        tree.add_iter(node_id, parent_id, name, node_type, "Invalid")
        if not parent_id in tree.node_id_to_row_ref:
            # If the parent cannot be found then it is a root.
            tree.roots.append(node_id)
        print_debug("New_node")
    elif notif_type == "Node_change":
        node_id = j["node_ID"]
        update = j["update"]
        if update["update_info"] == "Proved":
            if update["proved"]:
                tree.update_iter(node_id, 4, "Proved")
                if node_id in tree.roots and tree.roots_is_ok():
                    yes_no_text = "All proved. Do you want to exit ?"
                    if GPS.MDI.yes_no_dialog(yes_no_text):
                        abs_tree.exit()
            else:
                tree.update_iter(node_id, 4, "Not Proved")
        elif update["update_info"] == "Proof_status_change":
            proof_attempt = update["proof_attempt"]
            obsolete = update["obsolete"]
            limit = update["limit"]
            if obsolete:
                tree.update_iter(node_id, 4, "Obsolete")
            else:
                proof_attempt_result = proof_attempt["proof_attempt"]
                if proof_attempt_result == "Done":
                    prover_result = proof_attempt["prover_result"]
                    pr_answer = prover_result["pr_answer"]
                    if pr_answer == "Valid":
                        tree.update_iter(node_id, 4, "Valid")
                    else:
                        tree.update_iter(node_id, 4, "Not Valid")
                elif proof_attempt_result == "Uninstalled":
                    tree.update_iter(node_id, 4, "Not Installed")
                else:  # In this case it is necessary just a string
                    tree.update_iter(node_id, 4, "proof_attempt")
        else:
            print_debug("TODO")
        abs_tree.get_next_id(str(node_id))
        print_debug("Node_change")
    elif notif_type == "Remove":
        node_id = j["node_ID"]
        tree.remove_iter(node_id)
        print_debug("Remove")
    elif notif_type == "Next_Unproven_Node_Id":
        from_node = j["node_ID1"]
        to_node = j["node_ID2"]
        tree.node_jump_select(from_node, to_node)
    elif notif_type == "Initialized":
        print_message("Initialization done")
    elif notif_type == "Saved":
        print_message("Session saved")
        if abs_tree.save_and_exit:
            abs_tree.kill()
    elif notif_type == "Message":
        parse_message(j)
    elif notif_type == "Dead":
        print_message("ITP server encountered a fatal error, please report !")
    elif notif_type == "Task":
        proof_task.set_read_only(read_only=False)
        proof_task.delete()
        proof_task.insert(j["task"])
        proof_task.save(interactive=False)
        proof_task.set_read_only(read_only=True)
        proof_task.current_view().goto(proof_task.end_of_buffer())
        GPS.Console()
        print_debug(notif_type)
    elif notif_type == "File_contents":
        print_debug(notif_type)
    else:
        print_debug("TODO Else")


def parse_message(j):
    notif_type = j["notification"]
    message = j["message"]
    message_type = message["mess_notif"]
    if message_type == "Proof_error":
        print_error(message["error"])
    elif message_type == "Transf_error":
        tr_name = message["tr_name"]
        arg = message["failing_arg"]
        loc = message["loc"]
        msg = message["error"]
        doc = message["doc"]
        if arg == "":
            print_error(msg + "\nTranformation failed: \n" + tr_name + "\n\n", prompt=False)
            print_message(doc)
        else:
            print_error(tr_name + "\nTransformation failed. \nOn argument: \n" + arg + " \n" + msg + "\n\n", prompt=False)
            print_message(doc)
    elif message_type == "Strat_error":
        print_error(message["error"])
    elif message_type == "Replay_Info":
        print_message(message["replay_info"])
    elif message_type == "Query_Info":
        print_message(message["qinfo"])
    elif message_type == "Query_Error":
        print_error(message["qerror"])
    elif message_type == "Help":
        print_message(message["qhelp"])
    elif message_type == "Information":
        print_message(message["information"])
    elif message_type == "Task_Monitor":
        print_debug(notif_type)
    elif message_type == "Parse_Or_Type_Error":
        print_error(message["error"])
    elif message_type == "Error":
        print_error(message["error"])
    elif message_type == "Open_File_Error":
        print_error(message["open_error"])
    elif message_type == "File_Saved":
        print_message(message["information"])
    else:
        print_debug("TODO")

# Returns the biggest int res such that res < last and s[first:res] finish with
# sep.
def find_last (s, sep, first, last):
    res = s.find(sep, first, last)
    if res == -1 or res == first:
        return(first)
    else:
        return (find_last(s, sep, (res + len(sep)), last))

class Tree:

    def __init__(self):
        # Create a tree that can be appended anywhere
        self.box = Gtk.VBox()
        scroll = Gtk.ScrolledWindow()
        # This tree contains too much information including debug information.
        # A node is (node_ID, parent_ID, name, node_type, color).
        self.model = Gtk.TreeStore(str, str, str, str, str, Gdk.RGBA)
        # Create the view as a function of the model
        self.view = Gtk.TreeView(self.model)
        self.view.set_headers_visible(True)

        # Adding the tree to the scrollbar
        scroll.add(self.view)
        self.box.pack_start(scroll, True, True, 0)

        # TODO to be found: correct groups ???
        GPS.MDI.add(self.box, "Proof Tree", "Proof Tree", group=101, position=4)

        # roots is a list of nodes that does not have parents. When they are
        # all proved, we know the check is proved.
        self.roots = []

        cell = Gtk.CellRendererText(xalign=0)
        col2 = Gtk.TreeViewColumn("Name")
        col2.pack_start(cell, True)
        col2.add_attribute(cell, "text", 2)
        col2.add_attribute(cell, "background_rgba", 5)
        col2.set_expand(True)
        self.view.append_column(col2)

        # Populate with columns we want
        if debug_mode:
            # Node_ID
            cell = Gtk.CellRendererText(xalign=0)
            self.close_col = Gtk.TreeViewColumn("ID")
            self.close_col.pack_start(cell, True)
            self.close_col.add_attribute(cell, "text", 0)
            self.close_col.add_attribute(cell, "background_rgba", 5)
            self.view.append_column(self.close_col)

        if debug_mode:
            # Node parent
            cell = Gtk.CellRendererText(xalign=0)
            col = Gtk.TreeViewColumn("parent")
            col.pack_start(cell, True)
            col.add_attribute(cell, "text", 1)
            col.set_expand(True)
            col.add_attribute(cell, "background_rgba", 5)
            self.view.append_column(col)

        # Node color (proved or not ?)
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn("Status")
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 4)
        col.add_attribute(cell, "background_rgba", 5)
        col.set_expand(True)
        self.view.append_column(col)

        # We have a dictionnary from node_id to row_references because we want
        # an "efficient" way to get/remove/etc a particular row and we are not
        # going to go through the whole tree each time: O(n) vs O (ln n)
        # TODO find something that do exactly this in Gtk ??? (does not exist ?)
        self.node_id_to_row_ref = {}

    def exit(self):
        self.box.destroy()

    def get_iter(self, node):
        try:
            row = self.node_id_to_row_ref[node]
            path = row.get_path()
            return (self.model.get_iter(path))
        except:
            if debug_mode:
                print ("get_iter error: node does not exists %d", node)
            return None

    # Associate the corresponding row of an iter to its node in
    # node_id_to_row_ref.
    def set_iter(self, new_iter, node):
        path = self.model.get_path(new_iter)
        row = Gtk.TreeRowReference.new(self.model, path)
        self.node_id_to_row_ref[node] = row

    def add_iter(self, node, parent, name, node_type, proved):
        if parent == 0: # TODO parent doit etre envoye avec le bon numero de parent... ie 0 si c'est la node sur laquelle le focus est ?
            parent_iter = self.model.get_iter_first()
        else:
            parent_iter = self.get_iter(parent)
            if parent_iter is None:
                if debug_mode:
                    print ("add_iter ?error?: parent does not exists %d", parent)

        # Append as a child of parent_iter. parent_iter can be None (toplevel iter)
        new_iter = self.model.append(parent_iter)
        color = create_color(proved)
        self.model[new_iter] = [str(node), str(parent), name, node_type, proved, color]
        self.set_iter(new_iter, node)
        # ??? We currently always expand the tree. We may not want to do that in
        # the future.
        self.view.expand_all()

    def update_iter(self, node_id, field, value):
        row = self.node_id_to_row_ref[node_id]
        path = row.get_path()
        iter = self.model.get_iter(path)
        if field == 4:
            color = create_color(value)
            self.model[iter][5] = color
        self.model[iter][field] = value

    def remove_iter(self, node_id):
        row = self.node_id_to_row_ref[node_id]
        path = row.get_path()
        iter = self.model.get_iter(path)
        self.model.remove(iter)
        del self.node_id_to_row_ref[node_id]

    #  Automatically jumps from from_node to to_node if from_node is selected
    def node_jump_select(self, from_node, to_node):
        tree_selection = self.view.get_selection()
        try:
            if not tree_selection.count_selected_rows() == 0 and not from_node is None:
                from_node_row = self.node_id_to_row_ref[from_node]
                from_node_path = from_node_row.get_path()
                from_node_iter = self.model.get_iter(from_node_path)
                # ??? ad hoc way to get the parent node. This should be changed
                parent = int(self.model[from_node_iter][1])
                # The root node is never printed in the tree
                if parent == 0:
                    parent = from_node
                parent_row = self.node_id_to_row_ref[parent]
                parent_path = parent_row.get_path()
                if (tree_selection.path_is_selected(from_node_path) or
                    tree_selection.path_is_selected(parent_path)):
                    tree_selection.unselect_all()
                    to_node_row = self.node_id_to_row_ref[to_node]
                    to_node_path = to_node_row.get_path()
                    to_node_iter = self.model.get_iter(to_node_path)
                    tree_selection.select_path(to_node_path)
            else:
                to_node_row = self.node_id_to_row_ref[to_node]
                to_node_path = to_node_row.get_path()
                to_node_iter = self.model.get_iter(to_node_path)
                tree_selection.select_path(to_node_path)
        except:
            # The node we are jumping to does not exists
            print_debug ("Error in jumping: the node : " + str(to_node) + " probably does not exists")

    # Checks if all the roots are proved. If so, the check is proved and we can
    # exit.
    def roots_is_ok(self):
        b = True
        for node_id in self.roots:
            row = self.node_id_to_row_ref[node_id]
            path = row.get_path()
            iter = self.model.get_iter(path)
            b = b and self.model[iter][4] == "Proved"
        return(b)

class Tree_with_process:
    def __init__(self):
        # init local variables
        self.save_and_exit = False
        # send_queue and size_queue are used for request sent by the IDE to ITP
        # server.
        self.send_queue = ""
        self.size_queue = 0
        self.checking_notification = False
        print_debug("ITP launched")

    def start(self, command, mlw_file_name):
        self.file_name = mlw_file_name
        # init local variables
        self.save_and_exit = False

        # init the tree
        self.tree = Tree()
        self.process = GPS.Process(command, regexp=">>>>", on_match=self.check_notifications)
        self.console = GPS.Console("ITP_interactive", on_input=self.interactive_console_input)
        self.console.write("> ")
        # Back to the Messages console
        GPS.Console()

        # Query task each time something is clicked
        tree_selection = self.tree.view.get_selection()
        tree_selection.set_select_function(self.select_function)

        # Define a proof task
        proof_task_file = GPS.File("Proof Task", local=True)
        self.proof_task = GPS.EditorBuffer.get(proof_task_file, force=True, open=True)
        self.proof_task.set_read_only()
        # ??? should prefer using group and position. Currently, this works.
        GPS.execute_action(action="Split horizontally")

        # Initialize the Timeout for sending requests to ITP server. 300
        # milliseconds is arbitrary. It looks like it works and it should be ok
        # for interactivity.
        GPS.Timeout(300, self.actual_send)

    def kill(self):
        a = GPS.Console("ITP_interactive")
        # Any closing destroying can fail so try are needed to avoid killing
        # nothing when the first exiting function fail.
        try:
            a.destroy()
        except:
            print ("Cannot close console")
        try:
            self.proof_task.close()  # TODO force ???
        except:
            print ("Cannot close proof_task")
        try:
            self.tree.exit()
        except:
            print ("Cannot close tree")
        try:
            self.process.kill()
        except:
            print ("Cannot kill why3_server process")

    def exit(self):
        if GPS.MDI.yes_no_dialog("Do you want to save session before exit?"):
            self.send_request(0, "Save")
            self.save_and_exit = True
        else:
            self.kill()

    def check_notifications(self, unused, delimiter, notification):
        self.checking_notification = True
        print_debug(notification)
        try:
            # Remove remaining stderr output (stderr and stdout are mixed) by
            # looking for the beginning of the notification (begins with {).
            i = notification.find("{")
            p = json.loads(notification[i:])
            parse_notif(p, self, self.proof_task)
        except (ValueError):
            print ("Bad Json value")
            print (notification)
        except (KeyError):
            print ("Bad Json key")
            print (notification)
        except (TypeError):
            print ("Bad type")
            print (notification)
        self.checking_notification = False

    def select_function(self, select, model, path, currently_selected):
        if not currently_selected:
            tree_iter = model.get_iter(path)
            self.get_task(model[tree_iter][0])
            return True
        else:
            return True

    def interactive_console_input(self, console, command):
        tree_selection = self.tree.view.get_selection()
        tree_selection.selected_foreach(lambda tree_model, tree_path, tree_iter: self.send_request(tree_model[tree_iter][0], command))

    # This function actually send data and is also put into a Timeout call
    def actual_send(self, useless_timeout):
        print_debug ("sent")
        # TODO this should not be necessary to prevent deadlock with our own
        # code here. This looks really bad.
        if not self.size_queue == 0 and not self.checking_notification:
            # We send only complete request and less than 4080 char
            n = find_last(self.send_queue, ">>>>", 0, 4080)
            if n == -1 or n == 0 or n == None:
                self.send_queue = ""
                self.size_queue = 0
            else:
                self.process.send(self.send_queue[0:n])
                self.send_queue = self.send_queue[n:]
                self.size_queue = len(self.send_queue)


    # This is used as a wrapper (for debug) that actually create the message.
    # The function really sending this is called actual_send. 2 functions are
    # necessary because we want to send several messages at once. We also want
    # to send messages regularly: this is easier to have the simplest function
    # in a timeout.
    def send(self, s):
        if debug_mode:
            print_message(s)
        self.send_queue = self.send_queue + s + ">>>>"
        self.size_queue = self.size_queue + len(s) + 4
        # From different documentation, it can be assumed that pipes have a size
        # of at least 4096 (on all platforms). So, our heuristic is to check at
        # 3800 if it is worth sending before the timeout automatically does it.
        if self.size_queue > 3800:
            self.actual_send(0)

    def command_request(self, command, node_id):
        # This is an ad hoc function that allows save, remove node, and classic
        # command from the commandline.
        print_message("")
        if command == "Save":
            # touch source file so that gnatprove believes that gnat2why should
            # be called again. Otherwise, we change the session and the change
            # cannot be seen in gnatprove because it does not recompile.
            if os.path.exists(self.file_name):
                # Set the modification time as now.
                os.utime(self.file_name, None)
            return "{\"ide_request\": \"Save_req\" " + " }"
        elif command == "Remove":
            return ("{\"ide_request\": \"Remove_subtree\", \"node_ID\":" +
                    str(node_id) + " }")
        else:
            return ("{\"ide_request\": \"Command_req\", \"node_ID\":" +
                    str(node_id) + ", \"command\" : " + json.dumps(command) + " }")

    def send_request(self, node_id, command):
        request = self.command_request(command, node_id)
        print_debug(request)
        self.send(request)

    # Specific get_task function to get a task from the itp_server.
    def get_task(self, node_id):
        request = "{\"ide_request\": \"Get_task\", \"node_ID\":" + str(node_id) + ", \"do_intros\": true, \"loc\": false}"
        self.send(request)

    def get_next_id(self, modified_id):
        self.send("{\"ide_request\": \"Get_first_unproven_node\", \"node_ID\":" + modified_id + "}")
