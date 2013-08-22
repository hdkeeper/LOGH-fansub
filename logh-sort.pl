#!/usr/bin/perl

use utf8;

for $ext ('srt','ass')
{
	# Read substitution table
	%subst = ();
	open SUBST, "subst-$ext.txt";
	while (<SUBST>) {
		next if m/^#/;
		my ($from, $to) = split;
		$subst{$from} = $to if ($from && $to);
	}
	close SUBST;
	
	# Write substitution table
	open OUT, ">subst-$ext.txt.new";
	for $from (sort { $a cmp $b } keys %subst) {
		print OUT "$from\t\t$subst{$from}\n";
	}
	close OUT;
}
