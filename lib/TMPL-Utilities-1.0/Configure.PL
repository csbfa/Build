use v5.12.4;

use strict;
use Module::Build;

my $build = Module::Build->new (

    	module_name 	=> 'TMPL::Utilities',
    	license 	=> 'perl',
    	dist_author 	=> 'Jon Cummings, Brandon Webb <tmpl address!>',
    	dist_abstract	=> 'Utilities.pm -- Perl module package for TMPL utilities usage',
	perl_version	=> '5.12.4',
    	requires => {
		'perl' 			=> '5.12.4',
		'Cwd' 			=> '0',
		'File::Spec' 		=> '0',
		'File::HomeDir' 	=> '0',
		'File::Basename' 	=> '0',
		'Params::Validate' 	=> '0',
		'Data::Dumper::Simple' 	=> '0',
		},
	);

$build->create_build_script;

1;

__END__
