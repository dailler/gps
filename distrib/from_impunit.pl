#!/usr/bin/env perl

## If the following is set to true, the menus will look like
##    Ada -> Strings -> Fixed
## Otherwise, they are   Ada -> Ada.Strings.Fixed

$expand_hierarchies = 1;

$output ="../share/support/core/runtime.py";
$impunit="../gnatlib/gnat_src/impunit.adb";

open (OUT, '>' . $output);
open (IMPUNIT, $impunit) || die "File $impunit not found";

print OUT <<EOF
"""
GNAT runtime browsing support.

This package provides a new menu /Help/GNAT Runtime, which you
can use to quickly browse the list of standard Ada runtime
units, as well as the GNAT specific runtime.
Whenever you select an entry in this menu, the corresponding
spec file is displayed.
This file is automatically generated.
"""


import GPS

XML = """<?xml version="1.0"?>
<GPS>
EOF
;

$units{"System"} = "system";
$units{"Interfaces"} = "interfac";

foreach $line (<IMPUNIT>) {
   chomp ($line);
   if ($line =~ /"([^"]+)",\s*[TF].*\s*-- (.*)/) {
       $filename=$1;
       $unit=$2;
       $units{$unit} = $filename;
   }
}

print OUT "<submenu before=\"About\">
   <title>/Help/GNAT Runtime</title>
</submenu>\n";

# Basic sanity checking

keys %units > 30 || die "Couldn't parse ${impunit}, not enough elements";
$units{"Ada.Containers"} eq "a-contai"  || die "Couldn't parse ${impunit}";

foreach $unit (sort keys %units) {
  $filename = $units{$unit};
  $filename =~ s/\s*$//g;

  if (! $expand_hierarchies) {
    $double_unit = $unit;
    $double_unit =~ s/_/__/g;
    ($hierarchy) = ($double_unit =~ /^([^.]+)\./);
    $hierarchy = $double_unit if ($hierarchy eq "");
    $menu = "/Help/GNAT Runtime/$hierarchy/$double_unit";
  } else {
    ## Hierarchy parents must have two menu entries, or every time a
    ## submenu is open, the file is also open

    $hierarchy = $unit; 
    $hierarchy =~ s/_/__/g;
    $hierarchy =~ s/\./\//g;
    ($base_unit) = ($hierarchy =~ /\/([^\/]+)$/);

    foreach $child (keys %units) {
       if ($child =~ /^$unit\./) {
         $hierarchy .= "/&lt;$base_unit&gt;";
         last;
       }
    }

    $menu = "/Help/GNAT Runtime/$hierarchy";
  }
       
  print OUT "<documentation_file>
   <shell>Editor.edit \"$filename.ads\"</shell>
   <descr>$unit</descr>
   <menu>$menu</menu>
   <category>GNAT Runtime</category>
</documentation_file>\n";
}

print OUT <<EOF
</GPS>
"""

GPS.parse_xml(XML)
EOF
;

close (IMPUNIT);
close (OUT);
