=pod

=head1 OWNER

Sergei Solonenko

=head1 AUTHOR

Jonathan Cummings

=head1 NAME

Run02 - Given the <type of file> input file and an output file, convert files full of per-read gc content numbers into a file of relative frequencies in 2% bins from 0 to 1 GC content.

=head1 SYNOPSIS

Usage:

perl Run02.pl [-h|help|man] [-i|--input] <[file]> [-o|--output] <[file]> [-d|--default] [--parse] <[file]> [--save] <[file]> [--prompt] [--qsub]

=head1 DESCRIPTION

Developer's Note:

Program Description:

Run02 uses R data frame functions to convert files full of per-read gc content numbers into a file of relative frequencies in 2% bins from 0 to 1 GC content. The first-order option and file descriptor represents the input file. The second-order option and file descriptor represents the output file. If the man operation is not specified, then the first and second-order option and file descriptors must be defined. Any exception is caught and the program exits on error.

The options are as follows:

 -h|help|?	Print usage to STDOUT 

 -man		Print documentation to STDOUT

 -t|--type	Required. Specify if the input file was run through CAMERA or BLAST

 -i|--input	Required. Specify input file name and/or full path. 

 -o|--output	Optional. Specify output file name and/or full path. Required if CAMERA is defined.

 -d|--default	Optional. Specify that the output file/directory to be used is the default generated path.

 --parse	Optional. Overrides static input. Specify that the program will parse the provided file for command line options.

 --prompt	Optional. Overrides static input. Specify that the program will prompt the user for command line options.

 --save		Optional. Save the command line options to the provided file.

 --qsub		Optional. Run program on PBS using the parameters specified in the provided qsub.opt file.

=head1 EXIT STATUS

Run02 dies on error, creates output files in specified output directory on success.

=head1 EXAMPLES

The command:

	perl Run02.pl -i input.<type of file> -o result.<type of file>

will output the Run02's result from input.<type of file> to result.<type of file>

=head2 Files

in: user-defined <type of file> file
out: user-defined <type of file> file

=head1 CHANGE LOG

None.

=head1 EXIT STATUS

Run02 dies on error, creates output files in specified output directory on success.

=head1 Change Log

=head1 COPYRIGHT

Copyright 2012 UA TMPL

Permission is granted to copy, distribute and/or modify this 
document under the terms of the GNU Free Documentation 
License, Version 1.2 or any later version published by the 
Free Software Foundation; with no Invariant Sections, with 
no Front-Cover Texts, and with no Back-Cover Texts.

=cut
our $VERSION = 1.00;
#Begin external module declaration
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
#End external module declaration

#Begin internal module declaration
use TMPL::Core qw(Run02);
use TMPL::Utilities;
#End internal module declaration

my ($inputdir, $outputdir, $default, $help, $man, $qsub, $prompt, $parse, $save) = ('', '', '', '', '', '', '', '', '');

GetOptions( 'h|help|?'	    => \$help,
	    man       	    => \$man,
	    "i|input:s"	    => \$inputdir,
	    "o|output:s"    => \$outputdir,
	    'd|default'     => \$default,
	    prompt	    => \$prompt,
	    "parse:s"	    => \$parse,
	    "save:s"	    => \$save,
	    qsub	    =>\$qsub);

pod2usage( -exitval => 0, -verbose => 1) if $help;
pod2usage( -exitval => 0, -verbose => 3 ) if $man;

if ( $prompt ) {

    my %hash = ( 
	"Input file/directory" => {
		store => \$inputdir, 
		help => "File", 
		default => '',
	},
	"Output file/directory" => {
		store => \$outputdir, 
		help => "Optional. Use default if you specify yes to\nDefault Output or if type is BLAST [default ''] ", 
		default => '',
	},
	"Save command line options?" => {
		store => \$save, 
		help => "Optional. [default '']", 
		default => '',
	},
	"Use default output file/directory?" => {
		store => \$default, 
		help => "Cannot be specified if Output is provided. (Y/N)", 
		default => "no",
	},
	"Qsub" => {
		store => \$qsub, 
		help => "Run on PBS", 
		default => "no",
	},
    );

    Prompt(\%hash);

} 

if ( $parse ne '' ) {

    my %hash = ( "input"  	=> { store => \$inputdir, default => '', },
	   	 "output" 	=> { store => \$outputdir, default =>  '', },
		 "default"	=> { store => \$default, default => 0, },
	   	 qsub	 	=> { store => \$qsub, default => 0, },
		 "save"  	=> { store => \$save, default => '', },
	       );

    Parse( $parse, \%hash );

}

# Vefify either input file or -d is provided. Return error otherwise.
die "Invalid input directory. Use \"perl -h\" for expected parameters."   unless(defined $inputdir);
# Vefify either output file or -d is provided. Return error otherwise.
die "Invalid output directory. Use \"perl -h\" for expected parameters."  unless(defined $outputdir or $default);

my ($default_out, $valid_in, $valid_out) = ('', '', '');

#Create default paths if -d specified
if($default){
    $default_out = CreateDefaultOutput({class=>'Run02'});
}

#Try to validate anything given from input and output flags
$valid_in = ValidatePath({dir=>$inputdir}) if(defined $inputdir);
$valid_out = ValidatePath({dir=>$outputdir}) if(defined $outputdir);

die "Could not acquire a valid input directory. Please verify the path and try again" unless(defined $valid_in);

if(not defined $valid_out){
    if($default){
	print "The output path was not valid, try to use $default_out instead? (Y/N) ";
	my $user_response = <STDIN>;
	chomp($user_response) or die "Could not acquire a valid output directory. Please verify the path and try again";
	if(lc $user_response eq 'y'){
	    $valid_out = $default_out;
	} else{
	    die "Could not acquire a valid output directory. Please verify the path and try again";
	}
    } else{
	die "Could not acquire a valid output directory. Please verify the path and try again";
    }
}

die "The input path was not valid. Please verify the path and try again." unless(defined $valid_in);

if ( $save ne '' ) {

    my %hash = ( input 	=> $valid_in, 
	  	 output	=> $valid_out,
		 default => $default,
	  	 qsub 	=> $qsub
	       );

    Save( $save, \%hash );
}

#Call internal module to compute.

&Core::Run02({input=>$valid_in, output=>$valid_out, qsub=>$qsub});
