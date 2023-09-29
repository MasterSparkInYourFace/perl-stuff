#!/usr/bin/env perl

# tree for MSysGit (better than the windows tree!)
# copyleft marisa
# https://www.gnu.org/licenses/gpl-3.0.en.html

use open ":std", ":encoding(UTF-8)";
use strict;
use v5.30.0;

use Cwd qw(cwd realpath);
use Encode "decode";
use File::Basename "fileparse";
use Getopt::Std "getopts";
use Scalar::Util "reftype";

my $TREE_VERSION = "1.3";

my $HOME_DIRCOLORS = "$ENV{HOME}/.dir_colors";
my $SYS_DIRCOLORS = "/etc/DIR_COLORS";

my $LINE_HORIZONTAL = "\x{2500}";
my $LINE_VERTICAL = "\x{2502}";
my $LINE_INTERSECT = "\x{251C}";
my $LINE_CORNER = "\x{2514}";

my %OPTIONS;

sub _u8 {
	return decode("utf8", $_[0], $Encode::LEAVE_SRC);
}

sub readlink_relative {
	my $cd = cwd;
	my ($base, $dp, undef) = fileparse($_[0]);
	chdir($dp);
	my $ld = readlink($base);
	my $real = realpath($ld);
	chdir($cd);
	return ($ld, -e $real, $real);
}

sub read_dircolors($) {
	open(my $dc, "<". $_[0]) or die("can't open dircolors: $!\n");
	my %results;
	while (<$dc>) {
		$_ =~ s/^\s+|\s+$//;
		next if (substr($_, 0, 1) eq "#") or ($_ eq "");
		my @decl = split(/\s+/, $_);
		next if ($decl[0] eq "TERM"); # don't care
		$results{$decl[0]} = $decl[1];
	}
	close($dc);
	return \%results;
}

sub should_color {
	return 0 if ($OPTIONS{c});
	return 1 if ($OPTIONS{C});
	return 0 unless (-t STDOUT);
	return 1;
}

sub color {
	return unless (should_color);
	my ($rm, $c) = @_;
	my $p = exists($$rm{$c}) ? $$rm{$c} : "0";
	return "\e[${p}m";
}

sub orphaned {
	my $f = $_[0];
	return 0 unless (-l $f);
	return 0 if ((readlink_relative($f))[1]);
	return 1;
}

sub file2color {
	return unless (should_color);
	my $c = $_[0];
	my $f = (@_ < 1) ? $_ : $_[1];
	if (orphaned $f) { print color($c, "ORPHAN"); }
	elsif (-l $f)    { print color($c, "LINK"); }
	elsif (-u $f)    { print color($c, "SETUID"); }
	elsif (-g $f)    { print color($c, "SETGID"); }
	elsif (-p $f)    { print color($c, "FIFO"); }
	elsif (-S $f)    { print color($c, "SOCK"); }
	elsif (-b $f)    { print color($c, "BLK"); }
	elsif (-c $f)    { print color($c, "CHR"); }
	# I won't do (STICKY_)OTHER_WRITABLE because
	# this program is meant to be used on MSYS2;
	# checking other-writable status is too
	# difficult on windows for something minor :\
	elsif (-k $f)    { print color($c, "STICKY"); }
	elsif (-d $f)    { print color($c, "DIR"); }
	elsif (-x $f)    { print color($c, "EXEC"); }
	else {
		print color($c, $1) if ($f =~ m/(\.[[:alnum:]]+)$/);
	}
}

sub make_tree {
	if (reftype($_[0]) eq "ARRAY") {
		my @dirs = map { make_tree($_); } @{$_[0]};
		${$dirs[-1]}{is_last} = 1;
		return \@dirs;
	}
	my %t = (
		name => $_[0],
		dir_path => (@_ > 2) ? "$_[2]/" : "",
		is_dir => 0,
		is_last => 0
	);
	$t{path} = "$t{dir_path}$t{name}";
	my $depth = (@_ > 3) ? $_[3] : 0;
	my $md = (@_ > 1) ? $_[1] : $OPTIONS{d};
	if (!-d $t{path}) {
		$t{error} = "No such file or directory" if (!-e $t{path});
		return \%t;
	}
	$t{is_dir} = 1;
	return \%t if (($md > 0 and $depth >= $md) or ($OPTIONS{l} and -l $t{path}));
	my $d;
	unless (opendir($d, $t{path})) {
		$t{error} = $!;
		return \%t;
	}
	my @l = readdir($d);
	closedir($d);
	$t{files} = [map(+{
		name => $_,
		dir_path => $t{path},
		path => "$t{path}/$_",
		is_dir => 0,
		is_last => 0
	}, grep { !-d "$t{path}/$_" } @l)];
	# weed out dot links
	push(@{$t{files}}, map { make_tree($_, $md, $t{path}, $depth + 1); } grep { -d "$t{path}/$_" && $_ !~ /^\.+$/ } @l);
	${@{$t{files}}[-1]}{is_last} = 1 if (@{$t{files}} > 0);
	return \%t;
}

sub print_padding {
	for (my $i = 0; $i < @_; $i++) {
		if ($i < $#_) {
			print(($_[$i] ? " " : $LINE_VERTICAL) . " " x $OPTIONS{b});
		} else {
			print(($_[$i] ? $LINE_CORNER : $LINE_INTERSECT) . $LINE_HORIZONTAL x $OPTIONS{b});
		}
	}
}

sub print_file {
	my $c = $_[0];
	my %f = %{$_[1]};
	file2color($c, $f{path});
	print(_u8($f{name}) . color($c, "RESET") . ((exists $f{error}) ? " ($f{error})" : ""));
	if (-l $f{path}) {
		my ($ld, $ex, $real) = readlink_relative($f{path});
		print(" -> ");
		if ($ex) {
			file2color($c, $real);
		} else {
			print color($c, "MISSING");
		}
		print(_u8($ld) . color($c, "RESET"));
	}
	say
}

sub print_tree {
	my $col = $_[0];
	my @files = (reftype($_[1]) eq "ARRAY") ? @{$_[1]} : (%{$_[1]},);
	my $level = (@_ > 1) ? $_[2] : 0;
	my @mask = (@_ > 2) ? @{$_[3]} : ();
	$level++;
	push(@mask, 1);
	foreach	my $r (@files) {
		my %f = %$r;
		$mask[-1] = $f{is_last};
		print_padding(@mask);
		print_file($col, $r);
		if ($f{is_dir}) {
			next unless (exists $f{files});
			print_tree($col, $f{files}, $level, \@mask);
		};
	}
}

sub VERSION_MESSAGE {
	my $fh = $_[0];
	say($fh "marisa's tree, version $TREE_VERSION or something");
}

sub HELP_MESSAGE {
	my $fh = $_[0];
	print $fh <<~ "EOM";
	usage: $0 [-b <width>] [-d <depth>] [-c|-C] [-hlv] [dir ...]
	  -b <width>    horizontal branch padding (default 1)
	  -c            disable colors
	  -C            force colors even if output isn't a terminal
	  -d <depth>    maximum tree depth
	  -h|--help     display this message
	  -l            don't follow symlinks
	  -v|--version  display version
	EOM
}

sub coerce_int {
	my $r = $_[0];
	if (defined $$r) {
		$$r = int($$r);
		return;
	}
	$$r = (@_ > 1) ? $_[1] : 0;
}

sub main {
	my $dcf = (-e $HOME_DIRCOLORS) ? $HOME_DIRCOLORS : $SYS_DIRCOLORS;
	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	getopts("b:cCd:hlv", \%OPTIONS);
	die("-c and -C are incompatible, pick one") if ($OPTIONS{c} and $OPTIONS{C});
	if ($OPTIONS{h}) {
		VERSION_MESSAGE \*STDOUT;
		HELP_MESSAGE \*STDOUT;
		return;
	}
	if ($OPTIONS{v}) {
		VERSION_MESSAGE \*STDOUT;
		return;
	}
	coerce_int(\$OPTIONS{d});
	coerce_int(\$OPTIONS{b}, 1);
	my $col = (should_color and -e $dcf) ? read_dircolors($dcf) : {};
	print_tree($col, make_tree((@ARGV > 0) ? [map { s/\/+$//r } @ARGV] : ["."]));
}

main;
