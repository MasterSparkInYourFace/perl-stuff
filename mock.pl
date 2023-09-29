#!/usr/bin/env perl

# mock.pl - mock case
# Copyright (C) 2023  Marisa <stoner9lab@tutanota.com>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
