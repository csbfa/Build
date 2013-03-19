use v5.12.4;

use strict;
use Module::Build;

my $build = Module::Build->new (

    	module_name 	=> 'TMPL::MCLSyntenyPlotting',
    	license 	=> 'perl',
    	dist_author 	=> 'Brandon Webb <tmpl address!>',
	dist_abstract	=> 'MCLSyntenyPlotting.pm -- Perl module package for MCLSyntenyPlotting.pl',
	perl_version	=> '5.12.4',
    	requires => {
		'perl' 			=> '5.12.4',
		'Tie::File' 		=> '0',
		'Params::Validate' 	=> '0',
		},
	);

  $build->create_build_script;

__END__
