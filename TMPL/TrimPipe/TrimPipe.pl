=pod

=head1 OWNER

Sergei Solonenko

=head1 AUTHOR

Jonathan Cummings

=head1 NAME

TrimPipe - Given a directory with .fastq or .fastq.gz files, will trim the files with DynamicTrim.pl and then use FastQC to perform quality analysis.

=head1 SYNOPSIS

TrimPipe.pl [-h|help|man] [-i|--input] <[dir]> [-o|--output] <[dir]> [-d|--default] [--prompt] [--parse] <[file]> [--save] <[file]> [--qsub]

=head1 DESCRIPTION

Developer's Note: 

The options are as follows:

 -h|help|man	Print documentation to STDOUT
 
 -i|--input	Required. Specify input directory name and/or full path. 

 -o|--output	Not Required. Specify output directory name and/or full path.
 
 -d|--default   Not Required. Specifies to ask if user wants to use the default output directory, if -o is not specified.
 
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


=item Files

 in: Directory with 1 or more .fastq or .fastq.gz files.
 out: Valid directory path.

=head1 Change Log

=head1 COPYRIGHT

Copyright 2012 TMPL

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
use File::HomeDir;
use File::Path;
use Pod::Usage;
use Data::Dumper::Simple as => 'display', autowarn=>1;
#End external module declaration

#Begin internal module declaration
use TMPL::Core qw(TrimPipe);
use TMPL::Utilities;
#End internal module declaration

my ($input_dir, $output_file, $default, $help, $man, $qsub, $prompt, $parse, $save) = ('', '', '', '', '', '', '', '', '');

GetOptions( 'h|help|?'	    => \$help,
	    man       	    => \$man,
	    "i|input:s"	    => \$input_dir,
	    "o|output:s"    => \$output_file,
	    'd|default'     => \$default,
	    prompt	    => \$prompt,
	    "parse:s"	    => \$parse,
	    "save:s"	    => \$save,
	    qsub	    =>\$qsub);


if ( $prompt ) {

    my %hash = ( 
	"Input file/directory" => {
		store => \$input_dir, 
		help => "File", 
		default => '',
	},
	"Output file/directory" => {
		store => \$output_file, 
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

    my %hash = ( "input"  	=> { store => \$input_dir, default => '', },
	   	 "output" 	=> { store => \$output_file, default =>  '', },
		 "default"	=> { store => \$default, default => 0, },
	   	 qsub	 	=> { store => \$qsub, default => 0, },
                 "save"  	=> { store => \$save, default => '', },
	       );

    Parse( $parse, \%hash );

}

die "Invalid input directory. Use \"perl -h\" for expected parameters."   unless($input_dir ne '');
die "Invalid output file. Use \"perl -h\" for expected parameters."       unless($output_file ne '' or $default);

my ($default_out, $valid_in, $valid_out) = ('', '', '');

#Create default paths if -d specified
if($default){
   $default_out = CreateDefaultOutput({class=>'TrimPipe'});
}

#Try to validate anything given from input and output flags
$valid_in = ValidatePath({dir=>$input_dir});
$valid_out = ValidatePath({file=>$output_file}) if(defined $output_file);

if(not defined $valid_out){
   if($default){
      print "The output path was not valid, try to use $default_out instead? (Y/N) ";
      my $user_response = <STDIN>;
      chomp($user_response) or die "Could not acquire a valid output file. Please verify the path and try again";
      if(lc $user_response eq 'y'){
         $valid_out = $default_out;
      } else{
         die "Could not acquire a valid output file. Please verify the path and try again";
      }
   } else{
      die "Could not acquire a valid output file. Please verify the path and try again";
   }
}

if(not defined $valid_in){
   die "The input path was not valid. Please verify the path and try again.";
}

if ( $save ne '' ) {

    my %hash = ( input 	 => $valid_in, 
	  	 output	 => $valid_out,
		 default => $default,
	  	 qsub 	 => $qsub
	       );

    Save( $save, \%hash );
}

if($qsub){
   &Core::TrimPipe({input=>$valid_in, output=>$valid_out, qsub=>1});
} else{
   &Core::TrimPipe({input=>$valid_in, output=>$valid_out, qsub=>0});
}
