#!/usr/bin/env perl

# hello perlness my old friend
# writing perl is awful without perldoc or man. why doesn't msysgit come with these

use strict;
use v5.30.0;

sub mock($$) {
	my $t = $_[1];
	foreach my $c (split(//, $_[0])) {
		print($$t == 1 ? lc($c) : uc($c));
		$$t = !$$t;
	}
	$$t = !$$t;
	print(" ");
}

sub main {
	my $t = 0;
	foreach my $a (@ARGV) {
		mock($a, \$t);
	}
	say();
}

main;
