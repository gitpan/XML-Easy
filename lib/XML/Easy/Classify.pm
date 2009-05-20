=head1 NAME

XML::Easy::Classify - classification of XML-related items

=head1 SYNOPSIS

	use XML::Easy::Classify qw(
		is_xml_name is_xml_encname is_xml_chardata
		is_xml_attributes
		is_xml_content_object is_xml_content_array
		is_xml_content is_xml_element
	);

	$ok = is_xml_name($foo);
	$ok = is_xml_encname($foo);
	$ok = is_xml_chardata($foo);
	$ok = is_xml_attributes($foo);
	$ok = is_xml_content_object($foo);
	$ok = is_xml_content_array($foo);
	$ok = is_xml_content($foo);
	$ok = is_xml_element($foo);

=head1 DESCRIPTION

This module provides various type-testing functions, relating to data
types used in the L<XML::Easy> ensemble.  These are mainly intended to be
used to enforce validity of data being processed by XML-related functions.
They do not generate exceptions themselves, but of course type enforcement
code can be built using these predicates.

=cut

package XML::Easy::Classify;

use warnings;
use strict;

use Params::Classify 0.000 qw(is_string is_ref is_strictly_blessed);
use XML::Easy::Syntax 0.000
	qw($xml10_char_rx $xml10_name_rx $xml10_encname_rx);

our $VERSION = "0.004";

use parent "Exporter";
our @EXPORT_OK = qw(
	is_xml_name is_xml_encname is_xml_chardata
	is_xml_attributes
	is_xml_content_object is_xml_content_array
	is_xml_content is_xml_element
);

=head1 FUNCTIONS

=over

=item is_xml_name(ARG)

Returns true iff I<ARG> is a plain string satisfying the XML name syntax.
(Such names are used to identify element types, attributes, entities,
and other things in XML.)

=cut

sub is_xml_name($) {
	no warnings "utf8";
	return is_string($_[0]) && $_[0] =~ /\A$xml10_name_rx\z/o;
}

=item is_xml_encname(ARG)

Returns true iff I<ARG> is a plain string satisfying the XML character
encoding name syntax.

=cut

sub is_xml_encname($) {
	no warnings "utf8";
	return is_string($_[0]) && $_[0] =~ /\A$xml10_encname_rx\z/o;
}

=item is_xml_chardata(ARG)

Returns true iff I<ARG> is a plain string consisting of a sequence of
characters that are acceptable to XML.  Such a string is valid as data
in an XML element (where it may be intermingled with subelements) or as
the value of an element attribute.

=cut

sub is_xml_chardata($) {
	no warnings "utf8";
	return is_string($_[0]) && $_[0] =~ /\A$xml10_char_rx*\z/o;
}

=item is_xml_attributes(ARG)

Returns true iff I<ARG> is a reference to a hash that is well-formed as
an XML element attribute set.  To be well-formed, each key in the hash
must be an XML name string, and each value must be an XML character
data string.

=cut

sub is_xml_attributes($) {
	return undef unless is_ref($_[0], "HASH");
	my $attrs = $_[0];
	foreach(keys %$attrs) {
		return undef unless
			is_xml_name($_) && is_xml_chardata($attrs->{$_});
	}
	return 1;
}

=item is_xml_content_object(ARG)

Returns true iff I<ARG> is a reference to an L<XML::Easy::Content>
object, and thus represents a chunk of XML content.

=cut

sub is_xml_content_object($) {
	return is_strictly_blessed($_[0], "XML::Easy::Content");
}

=item is_xml_content_array(ARG)

Returns true iff I<ARG> is a reference to an array of the type that can
be passed to L<XML::Easy::Content>'s C<new> constructor, and thus lists
a chunk of XML content in canonical form.

=cut

sub is_xml_element($);

sub is_xml_content_array($) {
	return undef unless is_ref($_[0], "ARRAY");
	my $arr = $_[0];
	return undef unless @$arr % 2 == 1;
	for(my $i = $#$arr; ; $i--) {
		return undef unless is_xml_chardata($arr->[$i]);
		last if $i-- == 0;
		return undef unless is_xml_element($arr->[$i]);
	}
	return 1;
}

=item is_xml_content(ARG)

Returns true iff I<ARG> is a reference to either an L<XML::Easy::Content>
object or an array of the type that can be passed to that class's C<new>
constructor, and thus represents a chunk of XML content.

=cut

sub is_xml_content($) {
	return is_xml_content_object($_[0]) || is_xml_content_array($_[0]);
}

=item is_xml_element(ARG)

Returns true iff I<ARG> is a reference to an L<XML::Easy::Element>
object, and thus represents an XML element.

=cut

sub is_xml_element($) { is_strictly_blessed($_[0], "XML::Easy::Element") }

=back

=head1 SEE ALSO

L<Params::Classify>,
L<XML::Easy::NodeBasics>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org>

=head1 COPYRIGHT

Copyright (C) 2009 Andrew Main (Zefram) <zefram@fysh.org>

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
