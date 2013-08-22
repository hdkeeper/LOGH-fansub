#!/usr/bin/perl

$orig_dir = "Central-Anime";
$changed_dir = "merged-edited";

for $orig_file (glob $orig_dir.'/*.ass') {
	($changed_file = $orig_file) =~ s/$orig_dir/$changed_dir/;
	system "diff -u \"$orig_dir\" \"$changed_file\" >\"$changed_file.diff\"";
}
