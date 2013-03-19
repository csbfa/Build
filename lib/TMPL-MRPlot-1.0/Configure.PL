use v5.12.4;

use strict;
use Module::Build;

my $build = Module::Build->new (

    	module_name 	=> 'TMPL::MRPlot',
    	license 	=> 'perl',
    	dist_author 	=> 'Brandon Webb <tmpl address!>',
    	dist_abstract	=> 'MRPlot.pm - Perl module for MRPlot.pl',
	perl_version	=> '5.12.4',
    	requires => {
		'perl' 			=> '5.12.4',
		'Params::Validate' 	=> '0',
		},
	);

$build->create_build_script;

1;

__END__
