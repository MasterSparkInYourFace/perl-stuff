package MasterFSM;
use v5.36;

use Scalar::Util "reftype";

=head1 NAME

[DEFUNCT] MasterFSM - A bad finite state machine implementation

=head1 DESCRIPTION

MasterFSM is an FSM implementation that supports regex for character transitions
and allows you to write transition actions (as well as functions for your
transitions ;) for your lexing needs :3

=head2 Methods

=over

=item C<< MasterFSM->new() >>

Initializes a new FSM instance. See the examples section for an
explanation - I'm too lazy to be verbose today.

=back

=head1 EXAMPLES

Following is an example of a very simple number lexer:

	my $buf;
	my $line = 0;
	my $col = 0;
	my $fsm = MasterFSM->new(
		initial_state => "first",
		pre_action => sub {
			$col++;
			if ($_[0] eq "\n") {
				$col = 0;
				$line++;
			}
		},
		default_action => sub { $buf .= $_[0] },
		unmatched => "loop",
		states => [
			["first",    "-",      "negatory"],
			["first",    ".",      "float"],
			["first",    /[0-9]/,  "integer"],

			["negatory", /[0-9]/,  "integer"],
			["negatory", ".",      "float"],
			["negatory", /./,      "error",  sub { die("invalid unary minus"); }],

			["integer",  ".",      "float"],
			["integer",  "e",      "injiner" ],
			["integer",  /[^0-9]/, "first",  sub { say("integer: $buf"); $buf = ""; }],

			["float",    "e",      "injiner"],
			["float",    /[^0-9]/, "first",  sub { say("float: $buf"); $buf = ""; }],

			["injiner",  /[^0-9]/, "first",  sub { say("float (scientific notation): $buf"); $buf = ""; }]
		]
	);

=cut

my $common_close = sub {
	my $self = shift;
	$self->{input_data} = {};
	delete $self->{input_close};
	delete $self->{input_consume};
	delete $self->{input_push};
};

my $str_consume = sub {
	my $self = shift;
	my $c = substr($self->{input_data}{str}, 0, 1);
	$self->{input_data}{str} = substr($self->{input_data}{str}, 1);
	return $c;
};

my $str_push = sub {
	my $self = shift;
	$self->{input_data}{str} = shift . $self->{input_data}{str};
};

my $file_consume = sub {
	my $self = shift;
	my $ubuf = $self->{input_data}{unget_buf};
	my ($c, $e) = (undef, 1);
	$c = pop(@{$ubuf}) if (@{$ubuf} > 0);
	$e = read($self->{input_data}{file}, $c, 1) unless (defined($c));
	die("read() failed: $!\n") unless (defined($e));
	$self->{input_data}{eof} = 1 if ($e == 0);
	return $c;
};

my $file_push = sub {
	my $self = shift;
	my $ubuf = $self->{input_data}{unget_buf};
	push(@{$ubuf}, shift);
};

my $file_close = sub {
	my $self = shift;
	close($self->{input_data}{file});
	$self->$common_close();
};

sub close_input {
	my $self = shift;
	return $self->{input_close}();
}

my @required = qw(states initial_state);
sub new {
	my $class = shift;
	my $self = {
		auxdata => {}, # a storage area for you 'cause I'm nice <3
		input_data => {},
		unmatched => "loop",
	};

	while (@_) {
		my $k = shift;
		$self->{$k} = shift;
	}

	# validate requirements
	foreach my $r (@required) {
		die("$r is required") if (!exists($self->{$r}));
	}

	# validate states
	# no need for strict type validation, perl will throw runtime errors
	# anyways if the types aren't correct. what's the difference between throwing errors
	# now and throwing them later
	$self->{current_state} = $self->{initial_state};

	die("error_state is required when unmatched behavior is set to error\n")
		unless ($self->{unmatched} ne "error" or exists($self->{error_state}));

	foreach my $s (@{$self->{states}}) {
		die("a state must have at least an input state and transition value") if (@{$s} < 2);
		# the two arg form can be used to make an explicit loop easily
		push(@{$s}, $s->[0]) if (@{$s} < 3);
		die("do not use references as state names!\n")
			if (defined(reftype $s->[0]) or defined(reftype $s->[2]));
	}

	# validate other stuff
	$self->{pre_action} = sub {} unless (exists($self->{pre_action}));
	$self->{default_action} = sub {} unless (exists($self->{default_action}));
	$self->{post_action} = sub {} unless (exists($self->{post_action}));

	return bless($self, $class);
}

sub string {
	my $self = shift;
	$self->close_input if (exists($self->{input_data}{mode}));
	$self->{input_data} = {
		mode => "string",
		str => shift
	};
	die("string() requires one argument") if (!defined($self->{input_data}{str}));
	$self->{input_close} = $common_close;
	$self->{input_consume} = $str_consume;
	$self->{input_push} = $str_push;
}

sub file {
	my $self = shift;
	my %opt = ( encoding => "" );
	while (@_) {
		my $k = shift;
		$opt{$k} = shift;
	}
	$self->close_input if (exists($self->{input_data}{mode}));
	$self->{input_data} = {
		mode => "file",
		eof => 0,
		unget_buf => []
	};
	die("missing path\n") unless (exists($opt{path}));
	open($self->{input_data}{file}, "<$opt{encoding}", $opt{path})
		or die("can't open $opt{path}: $!\n");
	$self->{input_close} = $file_close;
	$self->{input_consume} = $file_consume;
	$self->{input_push} = $file_push;
}
