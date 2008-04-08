=head1 NAME

XML::Easy::Element - abstract form of XML data element

=head1 SYNOPSIS

	use XML::Easy::Element;

	$element = XML::Easy::Element->new("a",
			{ href => "#there" }, [ "there" ]);

	$type_name = $element->type_name;
	$attributes = $element->attributes;
	$href = $element->attribute("href");
	$content = $element->content;

=head1 DESCRIPTION

An object of this class represents an XML element, a node in the tree
making up an XML document.  This is in an abstract form, completely
isolated from the textual representation of XML, holding only the
meaningful content of the element.  This is a suitable form for
application code to manipulate an XML representation of application data.

The properties of an XML element are of three kinds.  Firstly, the element
has exactly one type, which is referred to by a name.  Secondly, the
element has a set of zero or more attributes.  Each attribute consists of
a name, which is unique among the attributes of the element, and a value,
which is a string of characters.  Finally, the element has content, which
is a sequence of zero or more characters and (recursively) elements,
interspersed in any fashion.

The element type name and attribute names all follow the XML syntax
for names.  This allows the use of a wide set of Unicode characters,
with some restrictions.  Attribute values and character content can use
almost all Unicode characters, with only a few characters (such as most
of the ASCII control characters) prohibited by the specification from
being directly represented in XML.

An abstract element object cannot be modified.  Once created, its
properties are fixed.  Tasks that you might think of as "modifying an
XML node" actually involve creating a new node.

This class is not meant to be subclassed.  XML elements are unextendable,
dumb data.

=cut

package XML::Easy::Element;

use warnings;
use strict;

use Params::Classify 0.000 qw(is_string is_ref is_strictly_blessed);
use XML::Easy::Syntax 0.000 qw($xml10_char_rx $xml10_name_rx);

BEGIN {
	if(eval { local $SIG{__DIE__};
		require Internals;
		exists &Internals::SetReadOnly;
	}) {
		*_set_readonly = \&Internals::SetReadOnly;
	} else {
		*_set_readonly = sub { };
	}
}

our $VERSION = "0.000";

sub _throw_data_error($) {
	my($msg) = @_;
	die "invalid XML data: $msg\n";
}

=head1 CONSTRUCTOR

=over

=item XML::Easy::Element->new(TYPE_NAME, ATTRIBUTES, CONTENT)

Constructs and returns a new element object with the specified properties.
I<TYPE_NAME> must be a string, I<ATTRIBUTES> must be a reference to a
hash, and I<CONTENT> must be a reference to an array, each being in the
same form that is returned by the accessor methods (below).  Particularly
note the constraints for the content array, which must alternate string
and element members.  All are checked for validity, against the XML 1.0
specification, and the function C<die>s if any are invalid.

=cut

sub new {
	my($class, $type_name, $attrs, $content) = @_;
	_throw_data_error("element type name isn't a string")
		unless is_string($type_name);
	_throw_data_error("illegal element type name")
		unless $type_name =~ /\A$xml10_name_rx\z/o;
	_throw_data_error("attribute hash isn't a hash")
		unless is_ref($attrs, "HASH");
	$attrs = { %$attrs };
	_set_readonly(\$_) foreach values %$attrs;
	_set_readonly($attrs);
	foreach(keys %$attrs) {
		_throw_data_error("illegal attribute name")
			unless /\A$xml10_name_rx\z/o;
		_throw_data_error("character data isn't a string")
			unless is_string($attrs->{$_});
		_throw_data_error("character data contains illegal character")
			unless $attrs->{$_} =~ /\A$xml10_char_rx*\z/o;
	}
	_throw_data_error("content array isn't an array")
		unless is_ref($content, "ARRAY");
	$content = [ @$content ];
	_set_readonly(\$_) foreach @$content;
	_set_readonly($content);
	_throw_data_error("content array has even length")
		unless @$content % 2 == 1;
	for(my $i = $#$content; ; $i--) {
		_throw_data_error("character data isn't a string")
			unless is_string($content->[$i]);
		_throw_data_error("character data contains illegal character")
			unless $content->[$i] =~ /\A$xml10_char_rx*\z/o;
		last if $i-- == 0;
		_throw_data_error("element data isn't an element")
			unless is_strictly_blessed($content->[$i],
						   __PACKAGE__);
	}
	my $self = bless([ $type_name, $attrs, $content ], __PACKAGE__);
	_set_readonly(\$_) foreach @$self;
	_set_readonly($self);
	return $self;
}

=back

=head1 METHODS

=over

=item $element->type_name

Returns the element type name, as a string.

=cut

sub type_name { $_[0]->[0] }

=item $element->attributes

Returns a reference to a hash encapsulating the element's attributes.
In the hash, each key is an attribute name, and the corresponding value
is the attribute's value as a string.

=cut

sub attributes { $_[0]->[1] }

=item $element->attribute(NAME)

Looks up a specific attribute of the element, by a name supplied as a
string.  If there is an attribute by that name then its value is returned,
as a string.  If there is no such attribute then C<undef> is returned.

=cut

sub attribute { exists($_[0]->[1]->{$_[1]}) ? $_[0]->[1]->{$_[1]} : undef }

=item $element->content

Returns a reference to an array encapsulating the element's content.
The array has an odd number of members.  The first and last elements,
and all elements in between with an even index, are strings giving the
element's character data.  Each element with an odd index is a reference
to an element object, being an element contained directly within the
present element.  Any of the strings may be empty, if the element has no
character data between subelements or at the start or end of the content.

=cut

sub content { $_[0]->[2] }

=back

=head1 SEE ALSO

L<XML::Easy>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org> 

=head1 COPYRIGHT

Copyright (C) 2008 PhotoBox Ltd

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
