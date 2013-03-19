use v5.12.4;

use strict;
use Module::Build;

my $build = Module::Build->new (

    	module_name 	=> 'TMPL::TaxonomySearch',
    	license 	=> 'perl',
    	dist_author 	=> 'Brandon Webb <tmpl address!>',
    	dist_abstract	=> 'TaxonomySearch.pm -- Perl module package for TaxonomySearch.p',
	perl_version	=> '5.12.4',
    	requires => {
		'perl'			=> '5.12.4',
		'LWP::UserAgent' 	=> '0',
		'LWP::Simple'	 	=> '0',
		'XML::LibXML::Reader' 	=> '0',
		'HTTP::Request' 	=> '0',
		'HTTP::Headers' 	=> '0',
		'Params::Validate' 	=> '0',
		},
	);

$build->create_build_script;

1;

__END__
