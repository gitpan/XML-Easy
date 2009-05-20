=head1 NAME

XML::Easy::Content - abstract form of XML content

=head1 SYNOPSIS

	use XML::Easy::Content;

	$content = XML::Easy::Content->new([
		"foo",
		$subelement,
		"bar",
	]);

	$content = $content->content;

=head1 DESCRIPTION

An object of this class represents a chunk of XML content, the kind
of matter that can be contained within an XML element.  This is in
an abstract form, completely isolated from the textual representation
of XML, holding only the meaningful content of the chunk.  This is a
suitable form for application code to manipulate an XML representation
of application data.

An XML content chunk consists of a sequence of zero or more characters
and XML elements, interspersed in any fashion.  Character content can
use almost all Unicode characters, with only a few characters (such as
most of the ASCII control characters) prohibited by the specification
from being directly represented in XML.  Each XML element in a content
chunk itself recursively contains a chunk of content, in addition to
having attached metadata.

An abstract content chunk object cannot be modified.  Once created,
its properties are fixed.  Tasks that you might think of as "modifying
an XML node" actually involve creating a new node.

This class is not meant to be subclassed.  XML content is unextendable,
dumb data.  Content objects are better processed using the functions in
L<XML::Easy::NodeBasics> than using the methods of this class.

=cut

package XML::Easy::Content;

use warnings;
use strict;

our $VERSION = "0.004";

eval { local $SIG{__DIE__};
	require XSLoader;
	XSLoader::load("XML::Easy", $VERSION) unless defined &new;
};

if($@ eq "") {
	close(DATA);
} else {
	(my $filename = __FILE__) =~ tr# -~##cd;
	local $/ = undef;
	my $pp_code = "#line 73 \"$filename\"\n".<DATA>;
	close(DATA);
	{
		local $SIG{__DIE__};
		eval $pp_code;
	}
	die $@ if $@ ne "";
}

1;

__DATA__

# Note perl bug: a bug in perl 5.8.{0..6} screws up __PACKAGE__ (used below)
# for the eval.  Explicit package declaration here fixes it.
package XML::Easy::Content;

use Params::Classify 0.000 qw(is_string is_ref is_strictly_blessed);
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

sub _throw_data_error($) {
	my($msg) = @_;
	die "invalid XML data: $msg\n";
}

=head1 CONSTRUCTOR

=over

=item XML::Easy::Content->new(CONTENT_ARRAY)

Constructs and returns a new content chunk object with the specified
content.  The content is checked for validity, against the XML 1.0
specification, and the function C<die>s if it is invalid.

I<CONTENT_ARRAY> must be a reference to an array listing the chunk's
content in a canonical form.  The array must have an odd number of
members.  The first and last members, and all members in between with an
even index, must be strings, and give the chunk's character data.  Each
member with an odd index must be a reference to an L<XML::Easy::Element>
object, representing an XML element contained directly within the chunk.
Any of the strings may be empty, if the chunk has no character data
between subelements or at the start or end of the chunk.

=cut

sub new {
	my($class, $content_array) = @_;
	_throw_data_error("content array isn't an array")
		unless is_ref($content_array, "ARRAY");
	$content_array = [ @$content_array ];
	_set_readonly(\$_) foreach @$content_array;
	_set_readonly($content_array);
	_throw_data_error("content array has even length")
		unless @$content_array % 2 == 1;
	for(my $i = 0; ; $i++) {
		_throw_data_error("character data isn't a string")
			unless is_string($content_array->[$i]);
		{
			no warnings "utf8";
			_throw_data_error(
				"character data contains illegal character")
					unless $content_array->[$i] =~
						/\A$xml10_char_rx*\z/o;
		}
		last if ++$i == @$content_array;
		_throw_data_error("element data isn't an element")
			unless is_strictly_blessed($content_array->[$i],
						   "XML::Easy::Element");
	}
	my $self = bless([ $content_array ], __PACKAGE__);
	_set_readonly(\$_) foreach @$self;
	_set_readonly($self);
	return $self;
}

=back

=head1 METHODS

=over

=item $content->content

Returns a reference to an array listing the chunk's content in a
canonical form.  The array has an odd number of members.  The first and
last members, and all members in between with an even index, are strings
giving the chunk's character data.  Each member with an odd index is a
reference to an L<XML::Easy::Element> object, representing an XML element
contained directly within the chunk.  Any of the strings may be empty,
if the chunk has no character data between subelements or at the start
or end of the chunk.

=cut

sub content { $_[0]->[0] }

=back

=head1 SEE ALSO

L<XML::Easy::Element>,
L<XML::Easy::NodeBasics>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 PhotoBox Ltd

Copyright (C) 2009 Andrew Main (Zefram) <zefram@fysh.org>

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
