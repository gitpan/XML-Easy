use Test::More tests => 23;

BEGIN { use_ok "XML::Easy::Element"; }

$e0 = XML::Easy::Element->new("foo", { bar=>"baz", quux=>"wibble" }, ["bop"]);
is $e0->type_name, "foo";
is_deeply $e0->attributes, { bar => "baz", quux => "wibble" };
is $e0->attribute("bar"), "baz";
is $e0->attribute("quux"), "wibble";
is $e0->attribute("foo"), undef;
is_deeply $e0->content, ["bop"];

$e1 = XML::Easy::Element->new("bar", {}, [ "a", $e0, "b" ]);
is $e1->type_name, "bar";
is_deeply $e1->attributes, {};
is $e1->attribute("foo"), undef;
is $e1->attribute("bar"), undef;
is_deeply $e1->content, [ "a", $e0, "b" ];

eval { XML::Easy::Element->new({}, {}, ["bop"]) };
is $@, "invalid XML data: element type name isn't a string\n";
eval { XML::Easy::Element->new("foo+bar", {}, ["bop"]) };
is $@, "invalid XML data: illegal element type name\n";
eval { XML::Easy::Element->new("foo", "", ["bop"]) };
is $@, "invalid XML data: attribute hash isn't a hash\n";
eval { XML::Easy::Element->new("foo", { "foo+bar" => "quux" }, ["bop"]) };
is $@, "invalid XML data: illegal attribute name\n";
eval { XML::Easy::Element->new("foo", { "z" => [] }, ["bop"]) };
is $@, "invalid XML data: character data isn't a string\n";
eval { XML::Easy::Element->new("foo", { "z" => "foo\0bar" }, ["bop"]) };
is $@, "invalid XML data: character data contains illegal character\n";
eval { XML::Easy::Element->new("foo", {}, "") };
is $@, "invalid XML data: content array isn't an array\n";
eval { XML::Easy::Element->new("foo", {}, [ "bop", $e0 ]) };
is $@, "invalid XML data: content array has even length\n";
eval { XML::Easy::Element->new("foo", {}, [ [] ]) };
is $@, "invalid XML data: character data isn't a string\n";
eval { XML::Easy::Element->new("foo", {}, [ "foo\0bar" ]) };
is $@, "invalid XML data: character data contains illegal character\n";
eval { XML::Easy::Element->new("foo", {}, [ "a", "", "b" ]) };
is $@, "invalid XML data: element data isn't an element\n";

1;
