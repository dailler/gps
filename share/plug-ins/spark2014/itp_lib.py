import GPS, sys
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


def print_error(message):
    console = GPS.Console("ITP_interactive")
    console.write(message, mode="error")
    console.write("\n> ")


def print_message(message):
    console = GPS.Console("ITP_interactive")
    console.write(message, mode="text")
    console.write("\n> ")

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
        if abs_tree.first_node <= 0:
            abs_tree.first_node = node_id
        print_debug("New_node")
    elif notif_type == "Node_change":
        node_id = j["node_ID"]
        update = j["update"]
        if update["update_info"] == "Proved":
            if update["proved"]:
                tree.update_iter(node_id, 4, "Proved")
                if node_id == abs_tree.first_node:
                    if GPS.MDI.yes_no_dialog("All proved. Do you want to exit ?"):
                        abs_tree.exit()
            else:
                tree.update_iter(node_id, 4, "Not Proved")  # TODO
        elif update["update_info"] == "Proof_status_change":
            proof_attempt = update["proof_attempt"]
            obsolete = update["obsolete"]
            limit = update["limit"]
            if obsolete:
                tree.update_iter(node_id, 4, "Obsolete")  # TODO
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
        GPS.Console()
        print_debug(notif_type)
    elif notif_type == "File_contents":
        print_debug(notif_type)
    else:
        print_debug("TODO Else")

    # TODO next_unproven_node_ID is called too many times... Find a way to solve this
    if not (notif_type == "Next_Unproven_Node_Id" or notif_type == "Task" or abs_tree.save_and_exit):
        abs_tree.get_next_id()


def parse_message(j):
    notif_type = j["notification"]
    message = j["message"]
    message_type = message["mess_notif"]
    if message_type == "Proof_error":
        print_error(message["error"])
    elif message_type == "Transf_error":
        print_error(message["error"])
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
        print_debug(notif_type)  # TODO This can be displayed in GPS
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


class Tree:

    def __init__(self):
        # Create a tree that can be appended anywhere
        self.box = Gtk.VBox()
        scroll = Gtk.ScrolledWindow()
        # TODO decide which data we want in this tree
        self.model = Gtk.TreeStore(str, str, str, str, str, Gdk.RGBA)
        # Create the view as a function of the model
        self.view = Gtk.TreeView(self.model)
        self.view.set_headers_visible(True)

        # Adding the tree to the scrollbar
        scroll.add(self.view)
        self.box.pack_start(scroll, True, True, 0)

        # TODO by default append this box to the GPS.MDI
        GPS.MDI.add(self.box, "Proof Tree", "Proof Tree", group=101, position=4) # TODO find the correct groups

        cell = Gtk.CellRendererText(xalign=0)
        col2 = Gtk.TreeViewColumn("Name")
        col2.pack_start(cell, True)
        col2.add_attribute(cell, "text", 2)
        # TODO test
        col2.add_attribute(cell, "background_rgba", 5)
        col2.set_expand(True)
        self.view.append_column(col2)

        # Populate with columns we want
        if debug_mode:
            cell = Gtk.CellRendererText(xalign=0)
            self.close_col = Gtk.TreeViewColumn("ID")
            self.close_col.pack_start(cell, True)
            self.close_col.add_attribute(cell, "text", 0)
            self.close_col.add_attribute(cell, "background_rgba", 5)
            self.view.append_column(self.close_col)

        # TODO ???
        if debug_mode:
            cell = Gtk.CellRendererText(xalign=0)
            col = Gtk.TreeViewColumn("parent")
            col.pack_start(cell, True)
            col.add_attribute(cell, "text", 1)
            col.set_expand(True)
            col.add_attribute(cell, "background_rgba", 5)
            self.view.append_column(col)

        # TODO ???
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn("Status")
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 4)
        col.add_attribute(cell, "background_rgba", 5)
        col.set_expand(True)
        self.view.append_column(col)

        # TODO reinitialize the map from node_id to row_ref
        # We have a dictionnary from node_id to row_references because we want
        # an "efficient" way to get/remove/etc a particular row and we are not
        # going to go through the whole tree each time: O(n) vs O (ln n)
        # TODO find something that do exactly this in Gtk).
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

    #  Associate the corresponding row of an iter to its node in node_id_to_row_ref
    def set_iter(self, new_iter, node):
        path = self.model.get_path(new_iter)
        row = Gtk.TreeRowReference.new(self.model, path)
        self.node_id_to_row_ref[node] = row

    def add_iter(self, node, parent, name, node_type, proved):
        if parent == 0:
            parent_iter = self.model.get_iter_first()
        else:
            parent_iter = self.get_iter(parent)
            if parent_iter is None:
                if debug_mode:
                    print ("add_iter error: parent does not exists %d", parent)
                parent_iter = self.model.get_iter_first()

        # Append as a child of parent_iter
        new_iter = self.model.append(parent_iter)
        color = create_color(proved)
        self.model[new_iter] = [str(node), str(parent), name, node_type, proved, color]
        self.set_iter(new_iter, node)
        # TODO expand all at the end ???
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
        self.node_id_to_row_ref.remove(node_id)

    #  Automatically jumps from from_node to to_node if from_node is selected
    def node_jump_select(self, from_node, to_node):
        tree_selection = self.view.get_selection()
        from_node_row = self.node_id_to_row_ref[from_node]
        from_node_path = from_node_row.get_path()
        from_node_iter = self.model.get_iter(from_node_path)
        if (tree_selection.path_is_selected(from_node_path)):
            tree_selection.unselect_all()
            to_node_row = self.node_id_to_row_ref[to_node]
            to_node_path = to_node_row.get_path()
            to_node_iter = self.model.get_iter(to_node_path)
            tree_selection.select_path(to_node_path)


class Tree_with_process:
    def __init__(self):
        # init local variables
        self.save_and_exit = False
        print_debug("ITP launched")

    def start(self, command):
        # init local variables
        self.save_and_exit = False
        # We need to know the first_node returned by itp_server so that when
        # it is proved, we can send a message to the user.
        self.first_node = -1

        # init the tree
        self.tree = Tree()
        self.process = GPS.Process(command, regexp=">>>>", on_match=self.check_notifications)
        self.console = GPS.Console("ITP_interactive", on_input=self.interactive_console_input)
        self.console.write("> ")
        # Back to the Messages console
        GPS.Console()

        # Query task each time something is clicked
        # TODO see if it is more efficient to save task in GPS
        tree_selection = self.tree.view.get_selection()
        tree_selection.set_select_function(self.select_function)

        # Define a proof task
        proof_task_file = GPS.File("Proof Task", local=True)
        self.proof_task = GPS.EditorBuffer.get(proof_task_file, force=True, open=True)
        self.proof_task.set_read_only()
        # TODO should prefer using group and position
        GPS.execute_action(action="Split horizontally")

    def kill(self):
        a = GPS.Console("ITP_interactive")
        # Any closing destroying can fail so try are needed to avoid killing
        # nothing when the first exiting function fail.
        try:
            a.destroy()
        except:
            print ("Cannot close console")
        try:
            self.proof_task.close()  # TODO force ?
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
        print_debug(notification)
        try:
            # Remove remaining stderr output (stderr and stdout are mixed) by
            # looking for the beginning of the notification (begins with {).
            i = notification.find("{")
            p = json.loads(notification[i:])
            parse_notif(p, self, self.proof_task)
        except (ValueError):
            print ("Bad Json value")
        except (KeyError):
            print ("Bad Json key")
        except (TypeError):
            print ("Bad type")

    def select_function(self, select, model, path, currently_selected):
        tree_iter = model.get_iter(path)
        self.get_task(model[tree_iter][0])
        return True

    def interactive_console_input(self, console, command):
        # TODO
        tree_selection = self.tree.view.get_selection()
        node_id = 0
        tree_selection.selected_foreach(lambda tree_model, tree_path, tree_iter: self.send_request(tree_model[tree_iter][0], command))
        print_debug(node_id)

    # This is used as a wrapper (for debug) that actually sends the message
    def send(self, s):
        if debug_mode:
            print_message(s)
        self.process.send(s)

    def command_request(self, command, node_id):
        # TODO if remove do something els if save also do something else
        # TODO very ad hoc
        print_message("")
        if command == "Save":
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

    # TODO this is also a send_request
    def get_task(self, node_id):
        request = "{\"ide_request\": \"Get_task\", \"node_ID\":" + str(node_id) + ", \"do_intros\": false}"
        self.send(request)

    def get_next_id(self):
        selection = self.tree.view.get_selection()
        model, paths = selection.get_selected_rows()
        print_debug(paths)
        if len(paths) == 1:
            for i in paths:
                cur_iter = model.get_iter(i)
                it = model[cur_iter][0]
                self.send("{\"ide_request\": \"Get_first_unproven_node\", \"node_ID\":" + it + "}")
