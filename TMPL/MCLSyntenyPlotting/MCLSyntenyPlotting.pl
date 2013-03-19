=pod

=head1 OWNER

Karin Holmfeldt

=head1 AUTHOR

Brandon Webb

=head1 NAME

MCLSytenyPlotting -- Given a MCL output file, parse and format an synteny csv file for GNU plotting

=head1 SYNOPSIS

    MCLSytenyPlotting [-h|help|?|man] [-i|--input] <[file]> [-o|--output] <[file]> [-r|--ref] <[file]> [-p|--plot] <[file]> [-t|--option] <[file]> [-d|--default] <[file]> [--gnu] <[file]> [--parse] <[file]> [--prompt] [--save] <[file]> [--qsub] <[file]>

=head1 DESCRIPTION

This application requires that BLAST and MCL has been run first to produce this application's input.

Developer's Note:

Program Description:

MCLSyntenyPlotting reads the MCL file sequentially, referencing from the Amino Acid Multi-FASTA file, and writing the placement of the gene in the genome value ( #:# ) to the output .csv file by line. The first-order option and file descriptor represents the MCL input file. The second-order option and file descriptor represents the output file name. The third-order option and file descriptor represents the Amino Acid Multi-FASTA file. The fourth-order option and file descriptor represents the plot output file name. THe fourth-order option and file descriptor represents the plot option file. The fifth-order option is requried if the Amino Acid Multi-FASTA file is absent and calls the external database utility. If man operation is not requested, then the first-order option and file descriptor, the second-order option and file descriptor, and either the third-order option and file descriptor or the fifth-order option must be specified. Any exception is caught and the program exits on an error.

The options are as follows:

 -h|help|?	Print usage to STDOUT 

 -man		Print documentation to STDOUT

 -i|--in	Required. Specify input file name and/or full path.

 -o|--out	Required. Specify output file name and/or full path.

 -r|--ref	Optional. Specify the Amino Acid Multi-FASTA file file name and/or full path. Required if -use-db is not defined.

 -p|--plot	Optional. Specify plot output file name and/or full path.

 -t|--option	Optional. Specify plot option file name and/or full path.

 -d|--default	Optional. Specify that the output file/directory to be used is the default generated path.

 --gnu		Optional. Specify GNU plot file name and/or full path.

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

MCLSyntenyPlotting dies on error, returns TRUE on success.

=head1 EXAMPLES

The command:

	perl MarkovPlotting.pl -i out.18_3-19_3_blast.I20 -o result.csv -r all_aa.faa.txt -p plot.out -t plot.opt

will process all_aa.faa.txt and out.18_3-19_3_blast.I20 to output result.csv, then use plot.opt and result.csv to output the GNU plotting instructions file to plot.out.

Example of plot.opt:

	500 1000 1500 2000 2500 3000 3500
	80000
	4000
	18_3-19_3

Where the first line of plot.opt is the number of genomes supplied, the second line represents the length of the genomes (x-axis), the thrid line represents te number of genomes (y-axis), and the last line is the desired prefix of the resulting .eps file.

=over 4

=item Files

 in: user-defined .csv file
 out: user-defined .csv file
 ref: user-defined Amino Acid Multi-FASTA file
 plot: user-defined sytenty out file
 option: user-defined plotting option file

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

use strict;
use warnings;
use Pod::Usage;
use TMPL::Utilities;
use TMPL::MCLSyntenyPlotting;
use Getopt::Long qw(:config bundling require_order);

my ( $man, $help, $ref, $input, $output, $plot, $option, $gnu, $default ) = ( '', '', '', '', '', '', '', '', '', '' );
my ( $default_out, $valid_input, $valid_output );
my ( $parse, $prompt, $save, $qsub ) = ( '', '', '', '' );
my %result;

GetOptions('h|help|?' 	=> \$help, 
	   'man'	=> \$man,
 	   'i|in:s'  	=> \$input,
	   'o|out:s'  	=> \$output,
	   'r|ref:s'	=> \$ref,
	   'p|plot:s' 	=> \$plot,
	   't|option:s' => \$option,
	   'd|default'  => \$default,
	   'gnu:s'	=> \$gnu,
	   'parse:s'	=> \$parse,
	   'prompt'	=> \$prompt,
	   'save:s'	=> \$save,
	   'qsub'	=> \$qsub) or pod2usage(2);

pod2usage( -exitval => 0, -verbose => 1 ) if $help;
pod2usage( -existval => 0, -verbose => 3 ) if $man;

if ( $save ne '' and $parse ne '' ) {
    die "Cannot have duplicate command line option 'save'. If 'parse' is specified, 'save' cannot be. $!";
}

if( $prompt ) {
 
    my %hash = ( "Input file/directory" => {
			store => \$input,
			help => "File",
			default => '',
		 },
		 "Output file/directory" => {
			store => \$output,
			help => "File",
			default => '',
		 },
		 "Amino acids referenced file" => {
			store => \$ref,
			help => "File",
			default => '',		 
		 },
		 "GNU plotting instructions output file name" => {
			store => \$plot,
			help => "File",
			default => '',
		 },
		 "GNU plotting options file" => {
			store => \$option,
			help => "File",
			default => '',
		 },
		 "Use default output file/directory?" => {
			store => \$default,
			help => "(Y/N)",
			default => "n",
		 },
		 "Directory to save GNU Plot to" => {
			store => \$gnu,
			help => "Directory. Use '' to indicate that no plot is to be made",
			default => '',
		 },
		 "Save command line options?" => {
			store => \$save,
			help => "File",
			default => '',
		 },
		 "qsub?" => {
			store => \$qsub,
			help => "Run on PBS (Y/N)",
			default => "n",
		 },
	       );

    Prompt(\%hash);

} 

if ( $parse ne '' ) {

    my %hash = ( "input"  	=> { store => \$input, default => '' },
	   	 "output"  	=> { store => \$output, default => '' },
	   	 "ref"		=> { store => \$ref, default => '' },
	   	 "plot" 	=> { store => \$plot, default => '' },
	   	 "option" 	=> { store => \$option, defauly => '' },
	   	 "default"  	=> { store => \$default, default => '' },
	   	 gnu		=> { store => \$gnu, default => 0 },
	   	 save		=> { store => \$save, default => '' },
	   	 qsub		=> { store => \$qsub, default => 0 },
	       );

    Parse( $parse, \%hash );
} 

if ( $plot and !$option ) { die "Plotting option file must be provided with plotting output file"; }

if ( $input ne '' and $default ) {

    my $name = "result.out";
    $valid_output = CreateDefaultOutput({ class => 'MCLSyntenyPlotting' });

    if ( -t STDOUT ) {
	print "Please provide the output file name: [default result.out]";
	$name = <STDIN>;
    }

    $valid_output .= $name;

    %result = FileIO({ input_file => $input });
    $valid_input = $result{input_file};

} elsif ( $input ne '' and $output ne '' ) {

    %result = FileIO({ class => "MCLSyntenyPlotting", input_file => $input, output_file => $output });
    $valid_input = $result{input_file};
    $valid_output = $result{output_file};
    
} else { pod2usage( -exitval => 0, -verbose => 2 ); }

my ( $valid_ref, $valid_plot, $valid_option, $valid_gnu ) = ( '', '', '', '' );

if ( $ref ne '' ) {
    %result = FileIO({ input_file => $ref });
    $valid_ref = $result{input_file};
}

if ( $plot ne '' ) {
    %result = FileIO({ output_file => $plot });
    $valid_plot = $result{output_file};
}

if ( $option ne '' ) {
    %result = FileIO({ input_file => $option });
    $valid_option = $result{input_file};
}

if ( $gnu ne '' ) {
    %result = FileIO({ output_dir => $gnu });
    $valid_gnu = $result{output_dir};
}

if( $save ne '' ) {

    my %hash = ( input    => $valid_input,
	   	 output   => $valid_output,
	   	 ref	  => $valid_ref,
	   	 plot	  => $valid_plot, 
	   	 option	  => $valid_option,
	   	 default  => $default,
	   	 gnu	  => $valid_gnu,
	   	 qsub	  => $qsub, 
	       );

    Save( $save, \%hash );
}

if( $qsub ) {
    
} else {
    main({ ref => $valid_ref, input => $valid_input, output => $valid_output, plot => $valid_plot, option => $valid_option, gnu => $valid_gnu });
}

1;
