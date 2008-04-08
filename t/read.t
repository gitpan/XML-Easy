use Test::More tests => 1 + 2*274;

BEGIN { use_ok "XML::Easy", qw(
		xml10_read_content xml10_read_element
		xml10_read_document xml10_read_extparsedent
); }

use Encode qw(decode);
use IO::File ();
use Params::Classify qw(scalar_class);
use Scalar::Util qw(blessed reftype);
use utf8 ();

sub deep_match($$);
sub deep_match($$) {
	my($a, $b) = @_;
	my $ac = scalar_class($a);
	my $bc = scalar_class($b);
	return 0 unless $ac eq $bc;
	if($ac eq "STRING") {
		return $a eq $b;
	} elsif($ac eq "BLESSED" || $ac eq "REF") {
		return 0 if $ac eq "BLESSED" && blessed($a) ne blessed($b);
		my $at = reftype($a);
		my $bt = reftype($b);
		return 0 unless $at eq $bt;
		if($at =~ /\A(?:REF|SCALAR|LVALUE|GLOB)\z/) {
			return deep_match($$a, $$b);
		} elsif($at eq "ARRAY") {
			return 0 unless @$a == @$b;
			foreach(my $i = @$a; $i--; ) {
				return 0 unless deep_match($a->[$i], $b->[$i]);
			}
			return 1;
		} elsif($at eq "HASH") {
			my @keys = keys %$a;
			foreach(@keys) {
				return 0 unless exists $b->{$_};
				return 0 unless deep_match($a->{$_}, $b->{$_});
			}
			foreach(keys %$b) {
				return 0 unless exists $a->{$_};
			}
			return 1;
		} else {
			return 1;
		}
	} else {
		return 1;
	}
}

sub upgraded($) {
	my($str) = @_;
	utf8::upgrade($str);
	return $str;
}

sub downgraded($) {
	my($str) = @_;
	utf8::downgrade($str, 1);
	return $str;
}

my %reader = (
	c => \&xml10_read_content,
	e => \&xml10_read_element,
	d => \&xml10_read_document,
	x => \&xml10_read_extparsedent,
);

sub try_read($$) {
	my $result = eval { $reader{$_[0]}->($_[1]) };
	return $@ ne "" ? [ "error", $@ ] : [ "ok", $result ];
}

my $data_in = IO::File->new("t/read.data", "r") or die;
my $line = $data_in->getline;

while(1) {
	$line =~ /\A###([a-z])?\n\z/ or die;
	last unless defined $1;
	my $prod = $1;
	$line = $data_in->getline;
	last unless defined $line;
	my $input = "";
	while($line ne "#\n") {
		die if $line =~ /\A###/;
		$input .= $line;
		$line = $data_in->getline;
		die unless defined $line;
	}
	die if $input eq "";
	chomp($input);
	$input = decode("UTF-8", $input);
	my $correct = "";
	while(1) {
		$line = $data_in->getline;
		die unless defined $line;
		last if $line =~ /\A###/;
		$correct .= $line;
	}
	chomp $correct;
	$correct = $correct =~ /\A[:'A-Za-z ]+\z/ ? [ "error", "$correct\n" ] :
						    [ "ok", eval($correct) ];
	ok deep_match(try_read($prod, upgraded($input)), $correct);
	ok deep_match(try_read($prod, downgraded($input)), $correct);
}

1;
