"""
Provides support for the ClearCase configuration management system.

It integrates into GPS's VCS support, and uses the same menus as all other VCS
systems supported by GPS. You can easily edit this file if you would like to
customize the cleartool commands that are sent for each of the menus.
"""

import GPS

from vcs import *

actions = [
    SEPARATOR,

    { ACTION: "Status", LABEL: "Describe"  },
    { ACTION: "Update", LABEL: "Update"  },
    { ACTION: "Commit", LABEL: "Check in"  },
    { ACTION: "Commit (via revision log)", LABEL: "Check in (via revision log)"  },

    SEPARATOR,

    { ACTION: "Open",   LABEL: "Check out" },
    { ACTION: "History (as text)",          LABEL: "View _entire revision history (as text)" },
    { ACTION: "History",                    LABEL: "View _entire revision history" },
    { ACTION: "History for revision",       LABEL: "View specific revision _history"  },

    SEPARATOR,

    { ACTION: "Diff against head",          LABEL: "Compare against head revision"  },
    { ACTION: "Diff against base",          LABEL: "Compare against working revision"  },
    { ACTION: "Diff against revision",      LABEL: "Compare against specific revision" },
    { ACTION: "Diff between two revisions", LABEL: "Compare two revisions" },
    { ACTION: "Diff base against head",     LABEL: "Compare base against head" },

    SEPARATOR,

    { ACTION: "Annotate",                LABEL: "Annotations"  },
    { ACTION: "Remove Annotate",         LABEL: "Remove annotations"  },
    { ACTION: "Edit revision log",       LABEL: "Edit revision log"  },
    { ACTION: "Edit global ChangeLog",   LABEL: "Edit global ChangeLog"  },
    { ACTION: "Remove revision log",     LABEL: "Remove revision log"  },

    SEPARATOR,

    { ACTION: "Add",               LABEL: "Add"  },
    { ACTION: "Add (via revision log)",               LABEL: "Add (via revision log)"  },
    { ACTION: "Add no commit",     LABEL: "Add, no commit"  },
    { ACTION: "Remove",            LABEL: "Remove"  },
    { ACTION: "Remove (via revision log)",            LABEL: "Remove (via revision log)"  },
    { ACTION: "Remove no commit",  LABEL: "Remove, no commit"  },
    { ACTION: "Revert",            LABEL: "Cancel checkout"  },

    SEPARATOR,

    { ACTION: "Add directory, no commit",     LABEL: "Directory/Add directory, no commit"  },
    { ACTION: "Remove directory, no commit",  LABEL: "Directory/Remove directory, no commit"  },
    { ACTION: "Commit directory",             LABEL: "Directory/Commit directory"  },
    { ACTION: "Status dir",                   LABEL: "Directory/Query status for directory"  },
    { ACTION: "Update dir",                   LABEL: "Directory/Update directory"  },
    { ACTION: "Status dir (recursively)",     LABEL: "Directory/Query status for directory recursively"  },
    { ACTION: "Update dir (recursively)",     LABEL: "Directory/Update directory recursively"  },

    { ACTION: "List project",                 LABEL: "Project/List files in project"  },
    { ACTION: "Status project",               LABEL: "Project/Query status for project"  },
    { ACTION: "Update project",               LABEL: "Project/Update project"  },
    { ACTION: "List project (recursively)",   LABEL: "Project/List files in project (recursively)"  },
    { ACTION: "Status project (recursively)", LABEL: "Project/Query status for project (recursively)"  },
    { ACTION: "Update project (recursively)", LABEL: "Project/Update project (recursively)"  },
]

XML = r"""<?xml version="1.0" ?>
<ClearCase_support>
   <!-- ClearCase describe -->

   <action name="clearcase_describe" show-command="true" output="none" category="">
      <shell output="">echo "Describing $2-"</shell>
      <external>cleartool describe -fmt "%%En\n%%Xn\n%%f\n%%m %%Rf\n" $2-</external>
      <shell>VCS.status_parse "ClearCase Native" "%1" $1 FALSE</shell>
   </action>

   <!-- ClearCase annotate -->

   <action name="clearcase_annotate" show-command="true" output="none" category="">
      <shell output="">echo "Querying annotations for $1"</shell>
      <external>cleartool annotate -nheader -force -fmt "%%Sd\040%%-16.16u\040%%-40.39Vn:" -out - "$1"</external>
      <shell>VCS.annotations_parse "ClearCase Native" "$1" "%1"</shell>
   </action>

   <!-- ClearCase local status -->

   <action name="clearcase_local_status" show-command="true" output="none" category="">
      <external>cleartool ls -short $2-</external>
      <shell>VCS.status_parse "ClearCase Native" "%1" FALSE TRUE</shell>
   </action>

   <!-- ClearCase checkin -->

   <action name="clearcase_checkin" show-command="true" output="none" category="">
      <shell output="">echo "Checking in file(s) $2-"</shell>
      <shell>dump "$1" TRUE</shell>
      <external>cleartool ci -cfile "%1" $2-</external>
      <on-failure>
         <shell output="">echo_error "Clearcase error:"</shell>
         <shell output="">echo_error "%2"</shell>
         <shell>MDI.dialog "Clearcase: could not check-in file(s)."</shell>
      </on-failure>
      <shell>delete "%2"</shell>
   </action>

   <!-- ClearCase history -->


   <action name="clearcase_history" show-command="true" output="none" category="">
      <external>cleartool lshistory "$1"</external>
      <shell>dump "%1" TRUE</shell>
      <shell>Editor.edit "%1"</shell>
      <shell>MDI.split_vertically TRUE</shell>
      <shell>delete "%2"</shell>
   </action>

   <action name="clearcase_history_rev" show-command="true" output="none" category="">
      <external>cleartool lshistory "$2"</external>
      <shell>dump "%1" TRUE</shell>
      <shell>Editor.edit "%1" 1</shell>
      <shell>MDI.split_vertically TRUE</shell>
      <shell>File "%3"</shell>
      <shell>File.search_next %1 "$1"</shell>
      <shell>FileLocation.line %1</shell>
      <shell>Editor.edit "%6" %1</shell>
      <shell>delete "%7"</shell>
   </action>

   <!-- ClearCase update -->

   <action name="clearcase_update" show-command="true" output="none" category="">
      <external>cleartool update $*</external>
      <on-failure>
         <shell output="">echo_error "Clearcase error:"</shell>
         <shell output="">echo_error "%2"</shell>
         <shell>MDI.dialog "Clearcase: could not update file(s)."</shell>
      </on-failure>
      <shell>Hook "file_changed_on_disk"</shell>
      <shell>Hook.run %1 null</shell>
   </action>

   <!-- ClearCase diff -->

   <action name="clearcase_diff_patch" show-command="true" output="none" category="">
      <external>cleartool diff -diff_format  "${1}@@/main/LATEST" "$2"</external>

      <on-failure>
        <shell>dump_file "%1" "$1" FALSE</shell>
      </on-failure>
   </action>

   <action name="clearcase_diff_head" show-command="true" output="none" category="">
      <external>cleartool diff -diff_format  "${1}@@/main/LATEST" "$1"</external>

      <on-failure>
        <shell>base_name "$1"</shell>
        <shell>dump "%2" TRUE</shell>
        <shell>File %1</shell>
        <shell>File $1</shell>
        <shell>Hook "diff_action_hook"</shell>
        <shell>Hook.run %1 "$1" null %2 %3 "%5 [LATEST]"</shell>
        <shell>delete %5</shell>
      </on-failure>
      <shell output="">echo "No differences found."</shell>
   </action>

   <action name="clearcase_diff_working" show-command="true" output="none" category="">
      <external>cleartool diff -diff_format -predecessor "$1"</external>
      <on-failure>
        <shell>base_name "$1"</shell>
        <shell>dump "%2" TRUE</shell>
        <shell>File %1</shell>
        <shell>File $1</shell>
        <shell>Hook "diff_action_hook"</shell>
        <shell>Hook.run %1 "$1" null %2 %3 "%5 [WORKING]"</shell>
        <shell>delete %5</shell>
      </on-failure>
      <shell output="">echo "No differences found."</shell>
   </action>

   <action name="clearcase_diff" show-command="true" output="none" category="">
      <external>cleartool diff -diff_format "${2}@@${1}" "$2" </external>

      <on-failure>
        <shell>base_name "$2"</shell>
        <shell>dump "%2" TRUE</shell>
        <shell>File %1</shell>
        <shell>File $2</shell>
        <shell>Hook "diff_action_hook"</shell>
        <shell>Hook.run %1 "$2" null %2 %3 "%5 [$1]"</shell>
        <shell>delete "%5"</shell>
      </on-failure>
      <shell output="">echo "No differences found."</shell>
   </action>

   <!-- ClearCase checkout -->

   <action name="clearcase_checkout" show-command="true" output="none" category="">
      <shell>MDI.input_dialog "Checking out file(s)" "Comment:=GPS check-out"</shell>
      <external>cleartool co -c "%1" $*</external>
      <on-failure>
         <shell output="">echo_error "Clearcase error:"</shell>
         <shell output="">echo_error "%2"</shell>
         <shell>MDI.dialog "Clearcase: could not checkout file(s)."</shell>
      </on-failure>
      <shell>Hook "file_changed_on_disk"</shell>
      <shell>Hook.run %1 null</shell>
   </action>

   <!-- Clearcase uncheckout -->

   <action name="clearcase_uncheckout" show-command="true" output="none" category="">
      <external>cleartool uncheckout -keep $*</external>
      <on-failure>
         <shell output="">echo_error "Clearcase error:"</shell>
         <shell output="">echo_error "%2"</shell>
         <shell>MDI.dialog "Clearcase: could not uncheckout file(s)."</shell>
      </on-failure>
      <shell>Hook "file_changed_on_disk"</shell>
      <shell>Hook.run %1 null</shell>
   </action>

   <!-- ClearCase Add -->

   <action name="clearcase_add" show-command="true" output="" category="">
      <shell>dump "$1" TRUE</shell>
      <external>cleartool co -cfile "%1" .</external>
      <external>cleartool mkelem -cfile "%2" "$2"</external>
      <external>cleartool ci -cfile "%3" "$2"</external>
      <external>cleartool ci -cfile "%4" .</external>
      <shell>delete "%5"</shell>
   </action>

   <!-- ClearCase Add (no commit) -->

   <action name="clearcase_add_no_commit" show-command="true" output="" category="">
      <shell>dump "$1" TRUE</shell>
      <external>cleartool co -cfile "%1" .</external>
      <external>cleartool mkelem -cfile "%2" "$2"</external>
      <external>cleartool ci -cfile "%4" .</external>
      <shell>delete "%4"</shell>
   </action>

   <!-- ClearCase Remove -->

   <action name="clearcase_remove" show-command="true" output="" category="">
      <shell>dump "$1" TRUE</shell>
      <external>cleartool co -cfile "%1" .</external>
      <external>cleartool rm -cfile "%2" "$2"</external>
      <external>cleartool ci -cfile "%3" "$2"</external>
      <external>cleartool ci -cfile "%4" .</external>
      <shell>delete "%5"</shell>
   </action>

   <!-- ClearCase Remove (no commit) -->

   <action name="clearcase_remove_no_commit" show-command="true" output="" category="">
      <shell>dump "$1" TRUE</shell>
      <external>cleartool co -cfile "%1" .</external>
      <external>cleartool rm -cfile "%2" "$2"</external>
      <external>cleartool ci -cfile "%4" .</external>
      <shell>delete "%4"</shell>
   </action>

   <!-- ClearCase -->

   <vcs name="ClearCase Native" absolute_names="FALSE" category="">
      <status_files     action="clearcase_describe"         label="Describe"/>
      <local_status_files action="clearcase_local_status"   label="ls"/>
      <open             action="clearcase_checkout"         label="Check out"/>
      <update           action="clearcase_update"           label="Update"/>
      <commit           action="clearcase_checkin"          label="Check in"/>
      <history          action="clearcase_history"          label="View entire revision history"/>
      <history_revision action="clearcase_history_rev"      label="View specific revision history"/>
      <annotate         action="clearcase_annotate"         label="Annotations"/>
      <add              action="clearcase_add"              label="Add"/>
      <add_no_commit    action="clearcase_add_no_commit"    label="Add, no commit"/>
      <remove           action="clearcase_remove"           label="Remove"/>
      <remove_no_commit action="clearcase_remove_no_commit" label="Remove, no commit"/>
      <revert           action="clearcase_uncheckout"       label="Cancel checkout"/>
      <diff_patch       action="clearcase_diff_patch"       label="Compare against head revision for building a patch file"/>
      <diff_head        action="clearcase_diff_head"        label="Compare against latest"/>
      <diff_working     action="clearcase_diff_working"     label="Compare against working"/>
      <diff             action="clearcase_diff"             label="Compare against other rev."/>

      <status label="Not checked out" stock="gps-vcs-up-to-date" />
      <status label="Checked Out (Reserved)" stock="gps-vcs-modified" />
      <status label="Checked Out (Unreserved)" stock="gps-vcs-modified" />
      <status label="View-private File" stock="gps-vcs-not-registered" />

      <status_parser>
         <regexp>([^\n]*)\n(.*@@)?(.*)\n(.*)\n(.*)(\n|$)</regexp>

         <file_index>0</file_index>
         <status_index>5</status_index>
         <local_revision_index>3</local_revision_index>
         <repository_revision_index>4</repository_revision_index>

         <status_matcher label="Checked Out (Reserved)">version reserved</status_matcher>
         <status_matcher label="Checked Out (Unreserved)">version unreserved</status_matcher>
         <status_matcher label="Not checked out">version</status_matcher>
         <status_matcher label="View-private File">view private object</status_matcher>
      </status_parser>

      <local_status_parser>
         <regexp>([^@@]+)(@@)?([^\s]*)(\n|$)</regexp>

         <file_index>1</file_index>
         <local_revision_index>3</local_revision_index>
      </local_status_parser>

      <annotations_parser>
         <regexp>\d\d[^\\]*(\\[^\s]*)\s*(.*)(\n|$)</regexp>

         <repository_revision_index>1</repository_revision_index>
         <file_index>2</file_index>
      </annotations_parser>
   </vcs>
</ClearCase_support>
"""

GPS.parse_xml(XML)
register_vcs_actions ("ClearCase Native", actions)
