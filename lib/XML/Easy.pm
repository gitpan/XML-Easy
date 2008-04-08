=head1 NAME

XML::Easy - XML processing with a clean interface

=head1 SYNOPSIS

	use XML::Easy qw(
		xml10_read_content xml10_read_element
		xml10_read_document xml10_read_extparsedent
	);

	$content = xml10_read_content($in);
	$element = xml10_read_element($in);
	$element = xml10_read_document($in);
	$content = xml10_read_extparsedent($in);

	use XML::Easy qw(
		xml10_write_content xml10_write_element
		xml10_write_document xml10_write_extparsedent
	);

	$output = xml10_write_content($content);
	$output = xml10_write_element($element);
	$output = xml10_write_document($element, "UTF-8");
	$output = xml10_write_extparsedent($content, "UTF-8");

=head1 DESCRIPTION

This module supplies functions that parse and serialise XML data
according to the XML 1.0 specification.  The functions are implemented
in C for performance, with a pure Perl backup version (which has good
performance compared to other pure Perl parsers) for systems that can't
handle XS modules.

This module is oriented towards the use of XML to represent data for
interchange purposes, rather than the use of XML as markup of principally
textual data.  It does not perform any schema processing, and does not
interpret DTDs or any other kind of schema.

XML data in memory is represented using a tree of C<XML::Easy::Element>
objects.  Such a tree encapsulates all the structure and data content
of an XML element or document, without any irrelevant detail resulting
from the textual syntax.

=cut

package XML::Easy;

use warnings;
use strict;

use XML::Easy::Element 0.000 ();

our $VERSION = "0.000";

use base "Exporter";
our @EXPORT_OK = qw(
	xml10_read_content xml10_read_element
	xml10_read_document xml10_read_extparsedent
	xml10_write_content xml10_write_element
	xml10_write_document xml10_write_extparsedent
);

eval { local $SIG{__DIE__};
	require XSLoader;
	XSLoader::load(__PACKAGE__, $VERSION);
};

if($@ eq "") {
	close(DATA);
} else {
	local $/ = undef;
	my $pp_code = <DATA>;
	close(DATA);
	{
		local $SIG{__DIE__};
		eval $pp_code;
	}
	die $@ if $@ ne "";
}

1;

__DATA__

use Params::Classify 0.000 qw(is_string is_ref is_strictly_blessed);
use XML::Easy::Syntax 0.000 qw(
	$xml10_char_rx $xml10_chardata_rx $xml10_comment_rx $xml10_encname_rx
	$xml10_eq_rx $xml10_miscseq_rx $xml10_name_rx $xml10_pi_rx
	$xml10_prolog_xdtd_rx $xml10_s_rx $xml10_textdecl_rx
);

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

sub _throw_syntax_error($) {
	my($rin) = @_;
	die "XML syntax error\n";
}

sub _throw_wfc_error($) {
	my($msg) = @_;
	die "XML constraint error: $msg\n";
}

sub _throw_data_error($) {
	my($msg) = @_;
	die "invalid XML data: $msg\n";
}

=head1 FUNCTIONS

All functions C<die> on error.

=head2 Parsing

These function take textual XML and extract the abstract XML content.
In the terminology of the XML specification, they constitute a
non-validating processor: they check for well-formedness of the XML,
but not for adherence of the content to any schema.

The inputs (to be parsed) for these functions are always character
strings.  XML text is frequently encoded using UTF-8, or some other
Unicode encoding, so that it can contain characters from the full
Unicode repertoire.  In that case, something must perform UTF-8 decoding
(or decoding of some other character encoding) to convert the octets of
a file to the characters on which these functions operate.  A Perl I/O
layer can do the job (see L<perlio>), or it can be performed explicitly
using the C<decode> function in the L<Encode> module.

=cut

my %predecl_entity = (
	lt => "<",
	gt => ">",
	amp => "&",
	quot => '"',
	apos => "'",
);

sub _parse_reference($) {
	my($rin) = @_;
	if($$rin =~ /\G&#x([0-9A-Fa-f]+);/gc) {
		my $v = $1;
		_throw_wfc_error("invalid character in character reference")
			unless $v =~ /\A0*(.{1,6})\z/s;
		my $c = chr(hex($v));
		_throw_wfc_error("invalid character in character reference")
			unless $c =~ /\A$xml10_char_rx\z/o;
		return $c;
	} elsif($$rin =~ /\G&#([0-9]+);/gc) {
		my $v = $1;
		_throw_wfc_error("invalid character in character reference")
			unless $v =~ /\A0*(.{1,7})\z/s;
		my $c = chr($v);
		_throw_wfc_error("invalid character in character reference")
			unless $c =~ /\A$xml10_char_rx\z/o;
		return $c;
	} elsif($$rin =~ /\G&($xml10_name_rx);/ogc) {
		my $c = $predecl_entity{$1};
		_throw_wfc_error("reference to undeclared entity")
			unless defined $c;
		return $c;
	} else { _throw_syntax_error($rin) }
}

sub _parse_attvalue($) {
	my($rin) = @_;
	$$rin =~ /\G(["'])/gc or _throw_syntax_error($rin);
	my $q = $1;
	my $value = "";
	while(1) {
		if($$rin =~ /\G$q/gc) {
			last;
		} elsif($$rin =~ /\G(?:\x{d}\x{a}?|[\x{9}\x{a}])/gc) {
			$value .= " ";
		} elsif($$rin =~ /\G(["']
				     |(?:(?![<&"'\x{9}\x{a}\x{d}])
					 $xml10_char_rx)+)/xogc) {
			$value .= $1;
		} elsif($$rin =~ /\G(?=&)/gc) {
			$value .= _parse_reference($rin);
		} else { _throw_syntax_error($rin) }
	}
	return $value;
}

sub _parse_element($);

sub _parse_content($) {
	my($rin) = @_;
	my @content = ("");
	while(1) {
		if($$rin =~ /\G((?:(?![<&])$xml10_char_rx)+)/ogc) {
			my $value = $1;
			_throw_syntax_error($rin) if $value =~ /\]\]>/;
			$value =~ s/\x{d}\x{a}?/\x{a}/g;
			$content[-1] .= $value;
		}
		if($$rin =~ m#\G(?=<[^/?!])#gc) {
			push @content, _parse_element($rin), "";
		} elsif($$rin =~ /\G(?=&)/gc) {
			$content[-1] .= _parse_reference($rin);
		} elsif($$rin =~ /\G<!\[CDATA\[($xml10_char_rx*?)\]\]>/ogc) {
			my $value = $1;
			$value =~ s/\x{d}\x{a}?/\x{a}/g;
			$content[-1] .= $value;
		} elsif($$rin =~ /\G(?:$xml10_pi_rx|$xml10_comment_rx)/ogc) {
			# no content
		} else {
			return \@content;
		}
	}
}

sub _parse_element($) {
	my($rin) = @_;
	$$rin =~ /\G<($xml10_name_rx)/ogc or _throw_syntax_error($rin);
	my $ename = $1;
	my %attrs;
	while($$rin =~ /\G$xml10_s_rx/ogc) {
		last unless $$rin =~ /\G($xml10_name_rx)$xml10_eq_rx/ogc;
		_throw_wfc_error("duplicate attribute") if exists $attrs{$1};
		$attrs{$1} = _parse_attvalue($rin);
	}
	$$rin =~ m#\G(/)?>#gc or _throw_syntax_error($rin);
	my $content;
	if(defined $1) {
		$content = [""];
	} else {
		$content = _parse_content($rin);
		$$rin =~ m#\G</($xml10_name_rx)$xml10_s_rx?>#gc
			or _throw_syntax_error($rin);
		_throw_wfc_error("mismatched tags") unless $1 eq $ename;
	}
	return XML::Easy::Element->new($ename, \%attrs, $content);
}

=over

=item xml10_read_content(INPUT)

I<INPUT> must be a character string.  It is parsed against the B<content>
production of the XML 1.0 grammar; i.e., as a sequence of the kind of
matter that can appear between the start-tag and end-tag of an element.
Returns a reference to an array of content, alternating character
strings with references to subelements in the same form that is used
with L<XML::Easy::Element>.

Normally one would not want to use this function directly, but prefer the
higher-level C<xml10_read_document> function.  This function exists for
the construction of custom XML parsers in situations that don't match
the full XML grammar.

=cut

sub xml10_read_content($) {
	my($in) = @_;
	my $content = _parse_content(\$in);
	$in =~ /\G\z/gc or _throw_syntax_error(\$in);
	_set_readonly(\$_) foreach @$content;
	_set_readonly($content);
	return $content;
}

=item xml10_read_element(INPUT)

I<INPUT> must be a character string.  It is parsed against the B<element>
production of the XML 1.0 grammar; i.e., as an item bracketed by tags
and containing content that may recursively include other elements.
Returns a reference to an C<XML::Easy::Element> object.

Normally one would not want to use this function directly, but prefer the
higher-level C<xml10_read_document> function.  This function exists for
the construction of custom XML parsers in situations that don't match
the full XML grammar.

=cut

sub xml10_read_element($) {
	my($in) = @_;
	my $element = _parse_element(\$in);
	$in =~ /\G\z/gc or _throw_syntax_error(\$in);
	return $element;
}

=item xml10_read_document(INPUT)

I<INPUT> must be a character string.  It is parsed against the B<document>
production of the XML 1.0 grammar; i.e., as a root element (possibly
containing subelements) optionally preceded and followed by non-content
matter, possibly headed by an XML declaration.  (A document type
declaration is I<not> accepted; this module does not process schemata.)
Returns a reference to an C<XML::Easy::Element> object which represents
the root element.  Nothing is returned relating to the XML declaration
or other non-content matter.

This is the most likely function to use to process incoming XML data.
Beware that the encoding declaration in the XML declaration, if any, does
not affect the interpretation of the input as a sequence of characters.

=cut

sub xml10_read_document($) {
	my($in) = @_;
	$in =~ /\A$xml10_prolog_xdtd_rx/ogc or _throw_syntax_error(\$in);
	my $element = _parse_element(\$in);
	$in =~ /\G$xml10_miscseq_rx\z/ogc or _throw_syntax_error(\$in);
	return $element;
}

=item xml10_read_extparsedent(INPUT)

I<INPUT> must be a character string.  It is parsed against the
B<extParsedEnt> production of the XML 1.0 grammar; i.e., as a sequence
of element content (containing character data and subelements), possibly
headed by a text declaration (which is similar to, but not the same
as, an XML declaration).  Returns a reference to an array of content,
alternating character strings with references to subelements in the same
form that is used with L<XML::Easy::Element>.

This is a relatively obscure part of the XML grammar, used when a
subpart of a document is stored in a separate file.  You're more likely
to require the C<xml10_read_document> function.

=cut

sub xml10_read_extparsedent($) {
	my($in) = @_;
	$in =~ /\A$xml10_textdecl_rx/gc;
	my $content = _parse_content(\$in);
	$in =~ /\G\z/gc or _throw_syntax_error(\$in);
	_set_readonly(\$_) foreach @$content;
	_set_readonly($content);
	return $content;
}

=back

=head2 Serialisation

These function take abstract XML data and serialise it as textual XML.
They do not perform indentation, default attribute suppression, or any
other schema-dependent processing.

The outputs of these functions are always character strings.  XML text
is frequently encoded using UTF-8, or some other Unicode encoding,
so that it can contain characters from the full Unicode repertoire.
In that case, something must perform UTF-8 encoding (or encoding of some
other character encoding) to convert the characters generated by these
functions to the octets of a file.  A Perl I/O layer can do the job
(see L<perlio>), or it can be performed explicitly using the C<encode>
function in the L<Encode> module.

=cut

sub _serialise_chardata($$) {
	my($rout, $str) = @_;
	_throw_data_error("character data isn't a string")
		unless is_string($str);
	while(1) {
		# Note perl bug: directly appending $1 to $$rout in this
		# statement tickles a bug in perl 5.8.0 that causes UTF-8
		# lossage.  The apparently-redundant stringification of
		# $1 works around it.
		$str =~ /\G((?:(?![\x{d}<&]|(?<=\]\])>)$xml10_char_rx)+)/gc
			and $$rout .= "$1";
		last if $str =~ /\G\z/gc;
		if($str =~ /\G([\x{d}<&>])/g) {
			$$rout .= sprintf("&#x%02x;", ord($1));
		} else {
			_throw_data_error(
				"character data contains illegal character");
		}
	}
}

sub _serialise_element($$);

sub _serialise_content($$) {
	my($rout, $cont) = @_;
	_throw_data_error("content array isn't an array")
		unless is_ref($cont, "ARRAY");
	_throw_data_error("content array has even length")
		unless @$cont % 2 == 1;
	_serialise_chardata($rout, $cont->[0]);
	my $ncont = @$cont;
	for(my $i = 1; $i != $ncont; ) {
		_serialise_element($rout, $cont->[$i++]);
		_serialise_chardata($rout, $cont->[$i++]);
	}
}

sub _serialise_attvalue($$) {
	my($rout, $str) = @_;
	_throw_data_error("character data isn't a string")
		unless is_string($str);
	while(1) {
		# Note perl bug: directly appending $1 to $$rout in this
		# statement tickles a bug in perl 5.8.0 that causes UTF-8
		# lossage.  The apparently-redundant stringification of
		# $1 works around it.
		$str =~ /\G((?:(?![\x{9}\x{a}\x{d}"<&])$xml10_char_rx)+)/gc
			and $$rout .= "$1";
		last if $str =~ /\G\z/gc;
		if($str =~ /\G([\x{9}\x{a}\x{d}"<&])/g) {
			$$rout .= sprintf("&#x%02x;", ord($1));
		} else {
			_throw_data_error(
				"character data contains illegal character");
		}
	}
}

sub _serialise_element($$) {
	my($rout, $elem) = @_;
	_throw_data_error("element data isn't an element")
		unless is_strictly_blessed($elem, "XML::Easy::Element");
	my $type_name = $elem->type_name;
	_throw_data_error("element type name isn't a string")
		unless is_string($type_name);
	_throw_data_error("illegal element type name")
		unless $type_name =~ /\A$xml10_name_rx\z/o;
	$$rout .= "<".$type_name;
	my $attributes = $elem->attributes;
	_throw_data_error("attribute hash isn't a hash")
		unless is_ref($attributes, "HASH");
	foreach(sort keys %$attributes) {
		_throw_data_error("illegal attribute name")
			unless /\A$xml10_name_rx\z/o;
		$$rout .= " ".$_."=\"";
		_serialise_attvalue($rout, $attributes->{$_});
		$$rout .= "\"";
	}
	my $content = $elem->content;
	if(is_ref($content, "ARRAY") && @$content == 1 &&
			is_string($content->[0]) && $content->[0] eq "") {
		$$rout .= "/>";
	} else {
		$$rout .= ">";
		_serialise_content($rout, $content);
		$$rout .= "</".$type_name.">";
	}
}

=over

=item xml10_write_content(CONTENT)

I<CONTENT> must be a reference to an array alternating character
strings with references to subelements, in the same form that is used
with L<XML::Easy::Element>.  The XML 1.0 textual representation of that
content is returned.

=cut

sub xml10_write_content($) {
	my($cont) = @_;
	my $out = "";
	_serialise_content(\$out, $cont);
	return $out;
}

=item xml10_write_element(ELEMENT)

I<ELEMENT> must be a reference to an C<XML::Easy::Element> object.
The XML 1.0 textual representation of that element is returned.

=cut

sub xml10_write_element($) {
	my($elem) = @_;
	my $out = "";
	_serialise_element(\$out, $elem);
	return $out;
}

=item xml10_write_document(ELEMENT[, ENCODING])

I<ELEMENT> must be a reference to an C<XML::Easy::Element> object.
The XML 1.0 textual form of a document with that element as the root
element is returned.  The document includes an XML declaration.
If I<ENCODING> is supplied, it must be a valid character encoding
name, and the XML declaration specifies it in an encoding declaration.
(The returned string consists of unencoded characters regardless of the
encoding specified.)

=cut

sub xml10_write_document($;$) {
	my($elem, $enc) = @_;
	my $out = "<?xml version=\"1.0\"";
	if(defined $enc) {
		_throw_data_error("encoding name isn't a string")
			unless is_string($enc);
		_throw_data_error("illegal encoding name")
			unless $enc =~ /\A$xml10_encname_rx\z/;
		$out .= " encoding=\"".$enc."\"";
	}
	$out .= " standalone=\"yes\"?>\n";
	_serialise_element(\$out, $elem);
	$out .= "\n";
	return $out;
}

=item xml10_write_extparsedent(CONTENT[, ENCODING])

I<CONTENT> must be a reference to an array alternating character
strings with references to subelements, in the same form that is used
with L<XML::Easy::Element>.  The XML 1.0 textual form of an external
parsed entity encapsulating that content is returned.  If I<ENCODING> is
supplied, it must be a valid character encoding name, and the returned
entity includes a text declaration that specifies the encoding name in
an encoding declaration.  (The returned string consists of unencoded
characters regardless of the encoding specified.)

=cut

sub xml10_write_extparsedent($;$) {
	my($cont, $enc) = @_;
	my $out = "";
	if(defined $enc) {
		_throw_data_error("encoding name isn't a string")
			unless is_string($enc);
		_throw_data_error("illegal encoding name")
			unless $enc =~ /\A$xml10_encname_rx\z/;
		$out .= "<?xml encoding=\"".$enc."\"?>";
	}
	_serialise_content(\$out, $cont);
	return $out;
}

=back

=head1 SEE ALSO

L<XML::Easy::Element>,
L<XML::Easy::Syntax>,
L<http://www.w3.org/TR/REC-xml/>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org> 

=head1 COPYRIGHT

Copyright (C) 2008 PhotoBox Ltd

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
