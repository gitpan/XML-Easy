use warnings;
use strict;

use Params::Classify qw(is_ref);
use t::DataSets (map { ("COUNT_$_", "foreach_$_") } qw(
	yes_name
	yes_attributes
	yes_content_array
));
use t::ErrorCases (map { ("COUNT_$_", "test_$_") } qw(
	error_type_name
	error_attribute_name
	error_attributes
	error_content
	error_element
	error_content_item
));

use Test::More tests => 64 +
	9*COUNT_yes_content_array + 2*COUNT_yes_name + 4*COUNT_yes_attributes +
	COUNT_error_content_item*12 +
	COUNT_error_type_name*4 + COUNT_error_attributes*5 +
	COUNT_error_content*2 + COUNT_error_element*6 +
	COUNT_error_attribute_name;

BEGIN { $SIG{__WARN__} = sub { die "WARNING: $_[0]" }; }

BEGIN {
	use_ok "XML::Easy::NodeBasics", qw(
		xml_content_object xml_content xml_element
		xml_c_content_object xml_c_content
		xml_e_type_name
		xml_e_attributes xml_e_attribute
		xml_e_content_object xml_e_content
	);
}

my $c0 = xml_content_object("bop");
is_deeply xml_content_object("b", "op"), $c0;
is_deeply xml_content_object(["bop"]), $c0;
is_deeply xml_content_object("bo", "", "p"), $c0;
is_deeply xml_content_object(["bo"], [""], "p"), $c0;
is_deeply xml_content_object($c0), $c0;
is_deeply xml_content_object("", $c0, ""), $c0;

is_deeply xml_content("bop"), ["bop"];
is_deeply xml_content(["bop"]), ["bop"];
is_deeply xml_content("b", "op"), ["bop"];
is_deeply xml_content("bo", "", "p"), ["bop"];
is_deeply xml_content(["bo"], [""], "p"), ["bop"];
is_deeply xml_content($c0), ["bop"];
is_deeply xml_content("", $c0, ""), ["bop"];

my $a0 = { bar=>"baz", quux=>"wibble" };
my $e0 = xml_element("foo", $a0, "bop");
is_deeply xml_element("foo", {bar=>"baz"}, "bop", {quux=>"wibble"}), $e0;
is_deeply xml_element("foo", {}, {quux=>"wibble"}, {bar=>"baz"}, "bop"), $e0;
is_deeply xml_element("foo", ["bop"], $a0), $e0;
is_deeply xml_element("foo", "b", "op", $a0), $e0;
is_deeply xml_element("foo", "bo", $a0, "", "p"), $e0;
is_deeply xml_element("foo", $a0, ["bo"], [""], "p"), $e0;
is_deeply xml_element("foo", $c0, $a0), $e0;
is_deeply xml_element("foo", "", $c0, $a0, ""), $e0;

my $c1 = xml_content_object("a", $e0, "b");
is_deeply xml_content_object(["a", $e0, "b"]), $c1;
is_deeply xml_content_object(["a"], $e0, "", "b"), $c1;
is_deeply xml_content_object("a", ["", $e0, ""], "b"), $c1;
is_deeply xml_content_object("a", xml_content_object($e0, "b")), $c1;

is_deeply xml_content("a", $e0, "b"), ["a", $e0, "b"];
is_deeply xml_content(["a", $e0, "b"]), ["a", $e0, "b"];
is_deeply xml_content(["a"], $e0, "", "b"), ["a", $e0, "b"];
is_deeply xml_content("a", ["", $e0, ""], "b"), ["a", $e0, "b"];
is_deeply xml_content("a", xml_content_object($e0, "b")), ["a", $e0, "b"];

my $e1 = xml_element("bar", "a", $e0, "b");
is_deeply xml_element("bar", ["a", $e0, "b"], {}), $e1;
is_deeply xml_element("bar", ["a"], $e0, "", "b"), $e1;
is_deeply xml_element("bar", {}, "a", {}, ["", $e0, ""], "b"), $e1;
is_deeply xml_element("bar", "a", {}, xml_content_object($e0, "b")), $e1;

is_deeply xml_content(), xml_content("");
is_deeply xml_element("foo"), xml_element("foo", "");

foreach_yes_content_array sub { my($carr) = @_;
	my $c = xml_content_object($carr);
	is ref($c), "XML::Easy::Content";
	is_deeply $c->content, $carr;
	is_deeply xml_content_object(@$carr), $c;
	is_deeply xml_content($carr), $carr;
	is_deeply xml_content(@$carr), $carr;
};
foreach_yes_content_array sub { my($carr) = @_;
	my $e = xml_element("foo", $carr);
	is ref($e), "XML::Easy::Element";
	is_deeply $e->content, $carr;
	is_deeply $e->content_object->content, $carr;
	is_deeply xml_element("foo", @$carr), $e;
};

test_error_content_item \&xml_content_object;
test_error_content_item \&xml_content;
test_error_content_item sub {
	die "invalid XML data: invalid content item\n"
		if is_ref($_[0], "HASH");
	xml_element("foo", $_[0]);
};
test_error_content_item sub { xml_content_object("foo", $_[0]) };
test_error_content_item sub { xml_content("foo", $_[0]) };
test_error_content_item sub {
	die "invalid XML data: invalid content item\n"
		if is_ref($_[0], "HASH");
	xml_element("foo", "foo", $_[0]);
};
test_error_content_item sub { xml_content_object($_[0], "foo") };
test_error_content_item sub { xml_content($_[0], "foo") };
test_error_content_item sub {
	die "invalid XML data: invalid content item\n"
		if is_ref($_[0], "HASH");
	xml_element("foo", $_[0], "foo");
};

test_error_content_item sub { xml_content_object($_[0], []) };
test_error_content_item sub { xml_content($_[0], []) };
test_error_content_item sub {
	die "invalid XML data: invalid content item\n"
		if is_ref($_[0], "HASH");
	xml_element("foo", $_[0], []);
};

foreach_yes_name sub { my($name) = @_;
	my $e = xml_element($name, {}, "bop");
	is ref($e), "XML::Easy::Element";
	is $e->type_name, $name;
};
foreach_yes_attributes sub { my($attr) = @_;
	my $e = xml_element("foo", $attr, "bop");
	is ref($e), "XML::Easy::Element";
	is_deeply $e->attributes, $attr;
	is $e->attribute("foo"), $attr->{foo};
	is $e->attribute("bar"), $attr->{bar};
};

test_error_type_name sub { xml_element($_[0], $c0) };
eval { xml_element("foo", { foo=>"bar", baz=>"quux" }, $c0, {foo=>"bar"}) };
is $@, "invalid XML data: duplicate attribute name\n";
test_error_attributes sub {
	die "invalid XML data: attribute hash isn't a hash\n"
		unless is_ref($_[0], "HASH");
	xml_element("foo", $_[0], $c0);
};
test_error_attributes sub {
	die "invalid XML data: attribute hash isn't a hash\n"
		unless is_ref($_[0], "HASH");
	xml_element("foo", { womble => "foo" }, $_[0], $c0);
};
test_error_attributes sub {
	die "invalid XML data: attribute hash isn't a hash\n"
		unless is_ref($_[0], "HASH");
	xml_element("foo", $_[0], { womble => "foo" }, $c0);
};

test_error_type_name sub { xml_element($_[0], undef) };
test_error_type_name sub { xml_element($_[0], { "foo\0bar" => {} }) };
test_error_type_name sub { xml_element($_[0], {foo=>"bar"}, {foo=>"bar"}) };
eval { xml_element("foo", {foo=>"bar"}, {foo=>"bar"}, undef) };
is $@, "invalid XML data: duplicate attribute name\n";
eval { xml_element("foo", {foo=>"bar"}, undef, {foo=>"bar"}) };
is $@, "invalid XML data: duplicate attribute name\n";
eval { xml_element("foo", undef, {foo=>"bar"}, {foo=>"bar"}) };
is $@, "invalid XML data: duplicate attribute name\n";
eval {
	xml_element("foo", undef, { "foo\0bar" => {} },
		{foo=>"bar"}, {foo=>"bar"});
};
is $@, "invalid XML data: duplicate attribute name\n";
test_error_attributes sub {
	die "invalid XML data: attribute hash isn't a hash\n"
		unless is_ref($_[0], "HASH");
	xml_element("foo", $_[0], undef);
};
test_error_attributes sub {
	die "invalid XML data: attribute hash isn't a hash\n"
		unless is_ref($_[0], "HASH");
	xml_element("foo", undef, $_[0]);
};

is_deeply xml_c_content_object($c0), $c0;
is_deeply xml_c_content_object(["bop"]), $c0;
is_deeply xml_c_content_object($c1), $c1;
is_deeply xml_c_content_object(["a", $e0, "b"]), $c1;

test_error_content \&xml_c_content_object;

is_deeply xml_c_content($c0), ["bop"];
is_deeply xml_c_content(["bop"]), ["bop"];
is_deeply xml_c_content($c1), ["a", $e0, "b"];
is_deeply xml_c_content(["a", $e0, "b"]), ["a", $e0, "b"];

test_error_content \&xml_c_content;

is xml_e_type_name($e0), "foo";
is xml_e_type_name($e1), "bar";

test_error_element \&xml_e_type_name;

is_deeply xml_e_attributes($e0), { bar => "baz", quux => "wibble" };
is_deeply xml_e_attributes($e1), {};

test_error_element \&xml_e_attributes;

is xml_e_attribute($e0, "foo"), undef;
is xml_e_attribute($e0, "bar"), "baz";
is xml_e_attribute($e0, "quux"), "wibble";
is xml_e_attribute($e1, "foo"), undef;
is xml_e_attribute($e1, "bar"), undef;
is xml_e_attribute($e1, "quux"), undef;

test_error_element sub { xml_e_attribute($_[0], "foo") };
test_error_attribute_name sub { xml_e_attribute($e1, $_[0]) };

test_error_element sub { xml_e_attribute($_[0], undef) };

is_deeply xml_e_content_object($e0), $c0;
is_deeply xml_e_content_object($e1), $c1;

test_error_element \&xml_e_content_object;

is_deeply xml_e_content($e0), ["bop"];
is_deeply xml_e_content($e1), [ "a", $e0, "b" ];

test_error_element \&xml_e_content;

1;
