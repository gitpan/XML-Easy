use warnings;
use strict;

our @things;
BEGIN {
	@things = qw(
		name encname chardata
		attributes
		content_object content_array
		content element
	);
}

use t::DataSets (map { ("COUNT_$_", "foreach_$_") }
			map { ("yes_$_", "no_$_") } @things);

use Test::More;

my $ntests = 1;
foreach(@things) {
	no strict "refs";
	$ntests += &{"COUNT_yes_$_"}() + &{"COUNT_no_$_"}();
}
plan tests => $ntests;

$SIG{__WARN__} = sub { die "WARNING: $_[0]" };

use_ok "XML::Easy::Classify", (map { "is_xml_$_" } @things);

foreach(@things) {
	eval "foreach_yes_$_ sub { ok is_xml_$_(\$_[0]) }; 1" or die $@;
	eval "foreach_no_$_ sub { ok !is_xml_$_(\$_[0]) }; 1" or die $@;
}

1;
