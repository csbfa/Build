=pod

=head1 OWNER

Sergei Solonenko

=head1 AUTHOR

Jonathan Cummings

=head1 NAME

combiner.pl

=head1 SYNOPSIS

Usage:

perl Combiner.pl [-h|help|man] [-i1|--input1] <[file]> [-i2|--input2] <[file]> [-o|--output] <[file]> [-d|--default] [--parse] <[file]> [--prompt] [--save] <[file]> [--qsub]

=head1 DESCRIPTION

Developer's Note:

Program Description:

Combiner takes two .fastq files containing first and second paired end reads and output in an interweaved .fastq format (first paired end of read 1, second paired end of read 1, first paired end of read 2, etc.). The first-order option and file descriptor represents the first fastq file. The second-order option and file descriptor represents the second fastq file. The third-order option and file descriptor represents the output file name and/or path. If the man operation is not requested, then all order options and file descriptors msut be defined. Any exception is caught and the program exits on error.

The options are as follows:

 -h|help|?	Print usage to STDOUT 

 -man		Print documentation to STDOUT

 -i1|input1 	Required. Specify first fastq input file and/or full path.

 -i2|input2 	Required. Specify second fastq input file and/or full path.

 -o|--output 	Required. Output file name and/or full path.

 -d|--default	Optional. Specify that the output file/directory to be used is the default generated path.

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

Combiner dies on error, creates a .fastq file on success.

=head1 EXAMPLES

The command:

	perl Combiner.pl -input1 seqA.fastq -input2 seqB.fastq -o result.fastq

will output result.fastq to the local home directory from the input information given from the two fastq files found in the local home directory.

=head2 Files

in: user-defined fastq file
in: user-defined fastq file
out: user-defined fastq file

=head1 Change Log

None.

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
use Capture::Tiny ':all';
use Getopt::Long;
#End external module declaration

#Begin internal module declaration
use TMPL::Utilities;
use TMPL::Core qw(Combiner);
#End internal module declaration

my ($inputOne, $inputTwo, $output, $default, $help, $man, $qsub, $prompt, $parse, $save) = ('', '', '', '', '', '', '', '', '', '');

GetOptions( 'h|help|?'	    => \$help,
	    man       	    => \$man,
	    "i1|input1:s"   => \$inputOne,
	    "i2|input2:s"   => \$inputTwo,
	    "o|output=s"    => \$output,
	    'd|default'     => \$default,
	    prompt	    => \$prompt,
	    "parse:s"	    => \$parse,
	    "save:s"	    => \$save,
	    qsub	    =>\$qsub);

pod2usage( -exitval => 0, -verbose => 1) if $help;
pod2usage( -exitval => 0, -verbose => 3 ) if $man;

if ( $prompt ) {

    my %hash = ( 
	"Input1 file/directory" => {
		store => \$inputOne, 
		help => "File", 
		default => '',
	},
	"Input2 file/directory" => {
		store => \$inputTwo, 
		help => "File", 
		default => '',
	},
	"Output file/directory" => {
		store => \$output, 
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

    my %hash = ( "input1"  	=> { store => \$inputOne, default => '', },
		 "input2"  	=> { store => \$inputTwo, default => '', },
	   	 "output" 	=> { store => \$output, default =>  '', },
		 "default"	=> { store => \$default, default => 0, },
	   	 qsub	 	=> { store => \$qsub, default => 0, },
		 "save"  	=> { store => \$save, default => '', },
	       );

    Parse( $parse, \%hash );

}

# Vefify either input file or -d is provided. Return error otherwise.
die "Invalid input1 file. Use \"perl -h\" for expected parameters."   unless($inputOne ne '');
die "Invalid input2 file. Use \"perl -h\" for expected parameters."   unless($inputTwo ne '');
# Vefify either output file or -d is provided. Return error otherwise.
die "Invalid output directory. Use \"perl -h\" for expected parameters."  unless($output ne '' or $default);

my ($default_out, $valid_in1, $valid_in2, $valid_out) = ('', '', '', '');

#Create default paths if -d specified
if($default){
    $default_out = CreateDefaultOutput({class=>'Combiner'}) ."/".'output.fastq';
}

#Try to validate anything given from input and output flags
$valid_in1 = ValidatePath({file=>$inputOne}) if($inputOne ne '');
$valid_in2 = ValidatePath({file=>$inputTwo}) if($inputTwo ne '');
$valid_out = ValidatePath({file=>$output})   if($output ne '');

if(not defined $valid_in1){
    die "Could not acquire a valid input1 file. Please verify the path and try again";
}
if(not defined $valid_in2){
    die "Could not acquire a valid input2 file. Please verify the path and try again";
}

if(not defined $valid_out or $valid_out eq ''){
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

die "The input1 path was not valid. Please verify the path and try again." unless(defined $valid_in1);
die "The input2 path was not valid. Please verify the path and try again." unless(defined $valid_in2);


if ( $save ne '' ) {

    my %hash = ( input1 => $valid_in1,
		 input2 => $valid_in2,
	  	 output	=> $valid_out,
		 default => $default,
	  	 qsub 	=> $qsub
	       );

    Save( $save, \%hash );
}

&Core::Combiner({input1=>$valid_in1, input2=>$valid_in2, output=>$valid_out, qsub=>$qsub});
