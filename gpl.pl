#!/usr/bin/env perl

# gpl.pl - GPL-3 disclaimer addition tool
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

use v5.34;

use Getopt::Std;

my %COMMENT_STYLES = (
	c => [ "/* ", " * ", " */\n" ],
	none => [ "", "", "" ],
	perl => [ "# ", "# ", "" ]
);

my %OPTIONS = (
	c => "c",
);
$Getopt::Std::STANDARD_HELP_VERSION = 1;
getopts("c:", \%OPTIONS);
die("invalid comment style") if (!exists($COMMENT_STYLES{$OPTIONS{c}}));

die("usage: $0 <description> <file ...>\n") if (@ARGV < 2);

my $DESC = shift @ARGV;
my $EMAIL = 'stoner9lab@tutanota.com';
my $ME = "Marisa <$EMAIL>";
my $YEAR = (localtime(time()))[5] + 1900;

my $GPL_NOTICE = <<END_NOTICE;
COMMENT_BEGIN %s - %s
COMMENT Copyright (C) %d  %s
COMMENT
COMMENT This program is free software: you can redistribute it and/or modify
COMMENT it under the terms of the GNU General Public License as published by
COMMENT the Free Software Foundation, either version 3 of the License, or
COMMENT (at your option) any later version.
COMMENT
COMMENT This program is distributed in the hope that it will be useful,
COMMENT but WITHOUT ANY WARRANTY; without even the implied warranty of
COMMENT MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
COMMENT GNU General Public License for more details.
COMMENT
COMMENT You should have received a copy of the GNU General Public License
COMMENT along with this program.  If not, see <https://www.gnu.org/licenses/>.
COMMENT_END
END_NOTICE

foreach my $fn (@ARGV) {
	my $f;
	unless (open($f, "<", $fn)) {
		say(STDERR "open($fn, O_RDONLY) failed, skipping: $!");
		next;
	}
	local $/;
	my $stuff = <$f>;
	close($f);
	unless (open($f, ">", $fn)) {
		say(STDERR "open($fn, O_WRONLY) failed, skipping: $!");
		next;
	}
	my ($cb, $cm, $ce) = (@{$COMMENT_STYLES{$OPTIONS{c}}});
	my $r = $GPL_NOTICE
		=~ s/COMMENT_BEGIN[ \t]*/$cb/gr
		=~ s/COMMENT_END[ \t]*/$ce/gr
		=~ s/COMMENT[ \t]*/$cm/gr;
	print($f sprintf($r, $fn, $DESC, $YEAR, $ME) . $stuff);
	close($f);
}
