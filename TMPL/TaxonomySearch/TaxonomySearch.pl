=pod

=head1 OWNER

Karin Holmfeldt

=head1 AUTHOR

Brandon Webb

=head1 NAME

TaxonomySearch - Given a .csv formated file containing GIvalues of each genome, query the NCBI protein database and retrieve the corresponding taxonomy name.

=head1 SYNOPSIS

 TaxonomySearch.pl [-h|help|?|man] [-i|--input] <[file]> [-o|--output] <[file]> [-d|--default] <[file]> [--parse] <[file]> [--prompt] [--save] <[file]> [--qsub] <[file]>

=head1 DESCRIPTION

Developer's Note: 

Program Description:

TaxonomySearch.pl queries the NCBI database with the GIvalues contained in the .csv file to retrieve and append the taxonomic names to the original content of the input file to the output file. The first-order option and file descriptor and option represents the .csv input file. The second-order option and file descriptor and option represents the .csv output file. If the man operation is not requested, then the first and second-order file descriptors must be specfied. Any exception is caught and the program exits on an error. 

The options are as follows:

 -h|help|?	Print usage to STDOUT 

 -man		Print documentation to STDOUT
 
 -i|--input	Specify input file name and/or full path. Required unless prompt or parse is used.  

 -o|--output	Specify output file name and/or full path. Required unless prompt or parse is used. 

 -d|--default	Optional. Specify that the output file/directory to be used is the default generated path.

 --verbose	Print verbosely.  
 
 --parse	Optional. Overrides static input. Specify that the program will parse the provided file for command line options.

 --prompt	Optional. Overrides static input. Specify that the program will prompt the user for command line options.

 --save		Optional. Save the command line options to the provided file.

 --qsub		Optional. Run program on PBS using the parameters specified in the provided qsub.opt file.

Note:

 - If file name is only provided, then the program looks for the file in the default directory (user directory). Otherwise, the program overrides the default directory path and uses the path provided.

 - For parsing the command line options, the input file must be in the format of:

	      [long option name] [value]

   e.g.		input /somedir/input_file
	  	output /somedir/outpufile

   When save is specified, the command line options will be written in this format. 

=head1 EXIT STATUS

TaxonomySearch dies on error, returns TRUE on success.

=head1 EXAMPLES

The command:

	perl TaxonomySearch.pl -i taxonomy.csv -o result.csv

will output result.csv with the taxonomy names of each genome appended to the content of taxonomy.csv. 

=over 4

=item Files

 in: user-defined .csv file
 out: user-defined .csv file

=back

=head1 Change Log

=head1 COPYRIGHT

Copyright 2012 TMPL

Permission is granted to copy, distribute and/or modify this 
document under the terms of the GNU Free Documentation 
License, Version 1.2 or any later version published by the 
Free Software Foundation; with no Invariant Sections, with 
no Front-Cover Texts, and with no Back-Cover Texts.

=cut

# use lib qw(/Users/goof_troop/TMPL/dev/Library);

our $VERSION = 1.00;

use strict;
use warnings;
use TMPL::Utilities;
use TMPL::TaxonomySearch;
use Pod::Usage;
use Getopt::Long qw(:config bundling require_order);

my ( $man, $help, $input, $output, $verbose, $prompt, $parse, $save, $qsub, $default ) = ( '', '', '', '', '', '', '', '', '', '' );
my ( $valid_input, $valid_output );
my %result;

GetOptions('h|help|?' 	=> \$help, 
	   'man'        => \$man,
	   'i|input:s'  => \$input,
	   'o|output:s' => \$output,
	   default	=> \$default,
	   verbose	=> \$verbose,
	   prompt	=> \$prompt,
	   'parse:s'	=> \$parse,
	   'save:s'	=> \$save,
	   qsub		=> \$qsub) or pod2usage(2);

pod2usage(1) if ( $help );
pod2usage(-existstatus => 0, -verbose => 2) if ( $man );

if ( $save ne '' and $parse ne '' ) {
    die "Cannot have duplicate command line option 'save'. If 'parse' is specified, 'save' cannot be. $!";
}

if ( $prompt ) {

    my %hash = ( 
	"Input file/directory" => {
		store => \$input, 
		help => "File", 
		default => '',
	},
	"Output file/directory" => {
		store => \$output, 
		help => "File", 
		default => '',
	},
	"Save command line options?" => {
		store => \$save, 
		help => "File", 
		default => '',
	},
	"Use default output file/directory?" => {
		store => \$default, 
		help => "Cannot be specified if Output is provided. (Y/N)", 
		default => "no",
	},
	"Print verbosely?" => {
		store => \$verbose,
		help => "(Y/N)",
		default => "no",
	},
	Qsub => {
		store => \$qsub, 
		help => "Run on PBS", 
		default => "no",
	},
    );

   Prompt(\%hash);

} 

if ( $parse ne '') {

    my %hash = ( input  	=> { store => \$input, default => "", },
	   	 output 	=> { store => \$output, default =>  "", },
		 default	=> { store => \$default, default => 0, },
		 verbose	=> { store => \$verbose, default => 0, },
	   	 save	 	=> { store => \$save, default => "", },
	   	 qsub	 	=> { store => \$qsub, default => 0, }, 
	       );

   Parse( $parse, \%hash );

}

if ( $input ne '' and $default ) {

    my $name = "result.out";
    $valid_output = CreateDefaultOutput({ class => 'TaxonomySearch' });

    if ( -t STDOUT ) {
	print "Please provide the output file name: [default result.out]";
	$name = <STDIN>;
    }

    $valid_output .= $name;

    %result = FileIO({ input_file=>$input });
    $valid_input = $result{input_file};

} elsif ( $input ne '' and $output ne '' ) {

    %result = FileIO({ class => "TaxonomySearch", input_file => $input, output_file => $output });
    $valid_input = $result{input_file};
    $valid_output = $result{output_file};

} else { pod2usage(2); }

if ( $save ne '' ) {

    my %hash = ( input 	=> $valid_input, 
	  	 output	=> $valid_output, 
		 default => $default,
		 verbose => $verbose,
	  	 qsub 	=> $qsub, 
	       );

    Save( $save, \%hash );
}

if($qsub) {
    
} else {
    main({ input => $valid_input, output => $valid_output, verbose => $verbose });
}

1;
