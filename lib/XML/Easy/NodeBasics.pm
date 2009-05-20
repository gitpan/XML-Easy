=head1 NAME

XML::Easy::NodeBasics - basic manipulation of XML data nodes

=head1 SYNOPSIS

	use XML::Easy::NodeBasics qw(xml_content_object xml_element);

	$content = xml_content_object("this", "&", "that");
	$content = xml_content_object(@sublems);

	$element = xml_element("a", { href => "there" }, "there");
	$element = xml_element("div", @subelems);

	use XML::Easy::NodeBasics qw(xml_c_content_object);

	$content = xml_c_content_object($content);

	use XML::Easy::NodeBasics qw(
		xml_e_type_name
		xml_e_attributes xml_e_attribute
		xml_e_content_object
	);

	$type_name = xml_e_type_name($element);
	$attributes = xml_e_attributes($element);
	$href = xml_e_attribute($element, "href");
	$content = xml_e_content_object($element);

=head1 DESCRIPTION

This module supplies functions concerned with the fundamental manipulation
of XML data nodes (content chunks and elements).  The nodes are dumb
data objects, best manipulated using plain functions such as the ones
in this module.

The nodes are objects of the classes L<XML::Easy::Content> and
L<XML::Easy::Element>.  These classes do not have any interesting
object-oriented behaviour; they are simply acting as abstract data types,
encapsulating dumb data.  The minimalistic methods supplied by the node
classes are not meant to be called directly.

The data contained within an existing node cannot be modified.  This means
that references to nodes can be copied and passed around arbitrarily,
without worrying about who might write to them, or deep versus shallow
copying.  As a result, tasks that you might think of as "modifying an
XML node" actually involve creating a new node.

=cut

package XML::Easy::NodeBasics;

use warnings;
use strict;

use Params::Classify 0.000 qw(is_string is_ref);
use XML::Easy::Classify 0.001 qw(
	is_xml_name is_xml_attributes
	is_xml_content_object is_xml_element
);
use XML::Easy::Content 0.001 ();
use XML::Easy::Element 0.001 ();
use XML::Easy::Syntax 0.000 qw($xml10_char_rx);

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

our $VERSION = "0.004";

use parent "Exporter";
our @EXPORT_OK = qw(
	xml_content_object xml_content xml_element
	xml_c_content_object xml_c_content
	xml_e_type_name
	xml_e_attributes xml_e_attribute
	xml_e_content_object xml_e_content
);

sub _throw_data_error($) {
	my($msg) = @_;
	die "invalid XML data: $msg\n";
}

=head1 FUNCTIONS

=head2 Construction

The construction functions each accept any number of items of XML content.
These items may be supplied in any of several forms.  Content item
types may be mixed arbitrarily, in any sequence.  The permitted forms
of content item are:

=over

=item character data

A plain string of characters that are acceptable to XML.

=item element

A reference to an L<XML::Easy::Element> object representing an XML
element.

=item content chunk

A reference to an L<XML::Easy::Content> object representing a chunk of
XML content.

=item content array

A reference to an array of the type that can be passed to
L<XML::Easy::Content>'s C<new> constructor, listing a chunk of XML
content in canonical form.

=back

The construction functions are:

=over

=item xml_content_object(ITEM ...)

Constructs and returns a XML content object based on a list of
constituents.  Any number of I<ITEM>s (zero or more) may be supplied; each
one must be a content item of a permitted type.  All the constituents
are checked for validity, against the XML 1.0 specification, and the
function C<die>s if any are invalid.

All the supplied content items are concatenated to form a single chunk.
The function returns a reference to an L<XML::Easy::Content> object.

=cut

sub xml_content(@);

sub xml_content_object(@) { XML::Easy::Content->new(&xml_content) }

=item xml_content(ITEM ...)

Constructs and returns a XML content object based on a list of
constituents.  Any number of I<ITEM>s (zero or more) may be supplied; each
one must be a content item of a permitted type.  All the constituents
are checked for validity, against the XML 1.0 specification, and the
function C<die>s if any are invalid.

All the supplied content items are concatenated to form a single chunk.
The function returns a reference to an array listing the content in
the canonical form that is returned by the C<content> accessor of
L<XML::Easy::Content>.

=cut

sub xml_content(@) {
	my @content = ("");
	foreach(@_) {
		if(is_string($_)) {
			no warnings "utf8";
			_throw_data_error(
				"character data contains illegal character")
					unless /\A$xml10_char_rx*\z/o;
			$content[-1] .= $_;
		} elsif(is_xml_element($_)) {
			push @content, $_, "";
		} elsif(is_xml_content_object($_)) {
			my $carr = $_->content;
			$content[-1] .= $carr->[0];
			push @content, @{$carr}[1 .. $#$carr];
		} elsif(is_ref($_, "ARRAY")) {
			$_ = XML::Easy::Content->new($_)->content;
			$content[-1] .= $_->[0];
			push @content, @{$_}[1 .. $#$_];
		} else {
			_throw_data_error("invalid content item");
		}
	}
	_set_readonly(\$_) foreach @content;
	_set_readonly(\@content);
	return \@content;
}

=item xml_element(TYPE_NAME, ITEM ...)

Constructs and returns an L<XML::Easy::Element> object, representing an
XML element, based on a list of consitutents.  I<TYPE_NAME> must be a
string, and gives the name of the element's type.  Any number of I<ITEM>s
(zero or more) may be supplied; each one must be either a content item
of a permitted type or a reference to a hash of attributes.  All the
constituents are checked for validity, against the XML 1.0 specification,
and the function C<die>s if any are invalid.

All the attributes supplied are gathered together to form the element's
attribute set.  It is an error if an attribute name has been used more
than once (even if the same value was given each time).  All the supplied
content items are concatenated to form the element's content.
The function returns a reference to an L<XML::Easy::Element> object.

=cut

sub xml_element($@) {
	my $type_name = shift(@_);
	XML::Easy::Element->new($type_name, {}, [""])
		unless is_xml_name($type_name);
	my %attrs;
	for(my $i = 0; $i != @_; ) {
		my $item = $_[$i];
		if(is_ref($item, "HASH")) {
			while(my($k, $v) = each(%$item)) {
				_throw_data_error("duplicate attribute name")
					if exists $attrs{$k};
				$attrs{$k} = $v;
			}
			splice @_, $i, 1, ();
		} else {
			$i++;
		}
	}
	XML::Easy::Element->new($type_name, \%attrs, [""])
		unless is_xml_attributes(\%attrs);
	return XML::Easy::Element->new($type_name, \%attrs,
					&xml_content_object);
}

=back

=head2 Examination of content chunks

=over

=item xml_c_content_object(CONTENT)

I<CONTENT> must be a reference to either an L<XML::Easy::Content>
object or an array of the type that can be passed to that class's C<new>
constructor.
Returns a reference to an L<XML::Easy::Content> object encapsulating
the content.

=cut

sub xml_c_content_object($) {
	return is_xml_content_object($_[0]) ? $_[0] :
		is_ref($_[0], "ARRAY") ? XML::Easy::Content->new($_[0]) :
		_throw_data_error("content data isn't a content chunk");
}

=item xml_c_content(CONTENT)

I<CONTENT> must be a reference to either an L<XML::Easy::Content>
object or an array of the type that can be passed to that class's C<new>
constructor.
Returns a reference to an array listing the content in
the canonical form that is returned by the C<content> accessor of
L<XML::Easy::Content>.

=cut

sub xml_c_content($) { xml_c_content_object($_[0])->content }

=back

=head2 Examination of elements

=over

=item xml_e_type_name(ELEMENT)

I<ELEMENT> must be a reference to an L<XML::Easy::Element> object,
representing an XML element.  Returns the element's type's name, as
a string.

=cut

sub xml_e_type_name($) {
	_throw_data_error("element data isn't an element")
		unless is_xml_element($_[0]);
	return $_[0]->type_name;
}

=item xml_e_attributes(ELEMENT)

I<ELEMENT> must be a reference to an L<XML::Easy::Element> object,
representing an XML element.  Returns a reference to a hash encapsulating
the element's attributes.  In the hash, each key is an attribute name,
and the corresponding value is the attribute's value as a string.

=cut

sub xml_e_attributes($) {
	_throw_data_error("element data isn't an element")
		unless is_xml_element($_[0]);
	return $_[0]->attributes;
}

=item xml_e_attribute(ELEMENT, NAME)

I<ELEMENT> must be a reference to an L<XML::Easy::Element> object,
representing an XML element.  Looks up a specific attribute of the
element, by a name supplied as a string.  If there is an attribute by
that name then its value is returned, as a string.  If there is no such
attribute then C<undef> is returned.

=cut

sub xml_e_attribute($$) {
	_throw_data_error("element data isn't an element")
		unless is_xml_element($_[0]);
	return $_[0]->attribute($_[1]);
}

=item xml_e_content_object(ELEMENT)

I<ELEMENT> must be a reference to an L<XML::Easy::Element> object,
representing an XML element.
Returns a reference to an L<XML::Easy::Content> object encapsulating
the element's content.

=cut

sub xml_e_content_object($) {
	_throw_data_error("element data isn't an element")
		unless is_xml_element($_[0]);
	return $_[0]->content_object;
}

=item xml_e_content(ELEMENT)

I<ELEMENT> must be a reference to an L<XML::Easy::Element> object,
representing an XML element.
Returns a reference to an array listing the element's content in
the canonical form that is returned by the C<content> accessor of
L<XML::Easy::Content>.

=cut

sub xml_e_content($) {
	_throw_data_error("element data isn't an element")
		unless is_xml_element($_[0]);
	return $_[0]->content;
}

=back

=head1 SEE ALSO

L<XML::Easy::Classify>,
L<XML::Easy::Content>,
L<XML::Easy::Element>,
L<XML::Easy::Text>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org>

=head1 COPYRIGHT

Copyright (C) 2009 Andrew Main (Zefram) <zefram@fysh.org>

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
