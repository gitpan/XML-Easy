use warnings;
use strict;

use Module::Build;

Module::Build->subclass(code => q{
	unless(__PACKAGE__->can("cbuilder")) {
		*cbuilder = sub { $_[0]->_cbuilder or die "no C support" };
	}
	sub find_xs_files {
		my($self) = @_;
		return {} unless eval { $self->cbuilder };
		require ExtUtils::CBuilder;   # observed to fail without this
		return $self->SUPER::find_xs_files;
	}
})->new(
	module_name => "XML::Easy",
	license => "perl",
	build_requires => {
		"Encode" => 0,
		"IO::File" => 0,
		"Module::Build" => 0,
		"Params::Classify" => 0,
		"Scalar::Util" => 0,
		"Test::More" => 0,
		"perl" => "5.008",
		"strict" => 0,
		"utf8" => 0,
		"warnings" => 0,
	},
	build_recommends => {
		"ExtUtils::CBuilder" => "0.15",
	},
	requires => {
		"Exporter" => 0,
		"Params::Classify" => 0,
		"base" => 0,
		"perl" => "5.008",
		"strict" => 0,
		"warnings" => 0,
	},
	recommends => {
		"Internals" => 0,
		"XSLoader" => 0,
	},
	dynamic_config => 1,
	meta_add => { distribution_type => "module" },
	create_makefile_pl => "passthrough",
	sign => 1,
)->create_build_script;

exit 0;
