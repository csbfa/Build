=pod

=head1 OWNER

Karin Holmfeldt

=head1 AUTHOR

Brandon Webb

=head1 NAME

MRPlot - Given a BLAST or CAMERA ,csv output, parse and format an output .csv file (CAMERA dependent), recruitment plot file, and GNU plot file. 

=head1 SYNOPSIS

 MRPlot.pl [-h|help|?|man] [-t|--type] <CAMERA|BLAST> [-i|--input] <[file]> [-o|--output] <[file]> [-d|--default] <[file]> [-l|--length] <integer> [-c|--color] <#RGB> [--gnu] <[file]> [--parse] <[file]> [--prompt] [--save] <[file]> [--qsub] <[file]>

=head1 DESCRIPTION

Developer's Note: 

Program Description:

MRPlot runs a recruitment plotting on either a BLAST or CAMERA supplied input file to generate a recruitment plot file. If a CAMERA file is provided, then an output .csv file is generated through a pBLAST to NT utilitiy prior to generating the recruitment plot file. If instructed, MRPlot will also generate a GNU plotting file from the generated recruitment plot file. The first-order option specifies the input file type. The second-order option and file descriptor and option specifies the .csv input file. The third-order option and file descriptor and option specifies the name of the desired .csv output file to be generated. The fourth-order option specifies the length of <WHAT?>. The fifth-order option specifies the color tag for the GNU plot. The sixth-order option indicates that MRPlot should generate a plot file with the specified file name. If man operation is not requested, then the first-order option, the second-order option and file descriptor, and the third-order option and file descriptor must be specified. Any exception is caught and the program exits on an error.

The options are as follows:

 -h|help|?	Print usage to STDOUT 

 -man		Print documentation to STDOUT

 -t|--type	Required. Specify if the input file was run through CAMERA or BLAST

 -i|--in	Required. Specify input file name and/or full path. 

 -o|--out	Optional. Specify output file name and/or full path. Required if CAMERA is defined.

 -d|--default	Optional. Specify that the output file/directory to be used is the default generated path.

 -p|--plot	Required. Specify plot output file name and/or full path.

 -l|--length	Optional. Length of sequence. Defualt is 50.

 -c|--color	Optional. Color tag for GNU Plotting. Default is #ffffff (white).

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

MRPlot dies on error, returns TRUE on success.

=head1 EXAMPLES

The command:

	perl MRPlot.pl -t CAMERA -i input.csv -o output.csv -l 45 --gnu 13-4_19-7.png

will output a .csv file with the read position on the genome (output.csv) and create a recruitment plot file with a length of 45 and the default color of white. MRPlot will then run GNU plot with an output file name of 13-4_19-7.png.  

=over 4

=item Files

 in: user-defined .csv file
 out: user-defined .csv file, GNU plotting file

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
use TMPL::MRPlot;
use TMPL::Utilities;
use Getopt::Long qw(:config bundling);

# accept a blast input file, output a plotting file
# if run through CAMERA, do pBLASTnt to get start/stop locations, then run recruitment with BLAST
# otherwise, run recruitment with BLAST

my ( $man, $help ) = ( 0, 0 );
my ( $type, $input, $output, $plot, $gnu, $length, $color ) = ('', '', '', '', '', 50, "#ffffff"); 
my ( $parse, $prompt, $save, $qsub, $default ) = ( '', '', '', '', '' );
my %result;

GetOptions('h|help|?' 	 => \$help, 
	    man     	 => \$man,
	    "t|type:s"   => \$type,
	    "i|input:s"  => \$input,
	    "o|output:s" => \$output,
	    default	 => \$default,
	    "p|plot:s"	 => \$plot,
	    "l|length:s" => \$length,
	    "c|color:s"  => \$color,
	    "gnu:s"	 => \$gnu,
	    prompt	 => \$prompt,
	    "parse:s"	 => \$parse,
	    "save:s"	 => \$save,
	    qsub	 => \$qsub) or pod2usage(2);

pod2usage( -exitval => 0, -verbose => 1) if $help;
pod2usage( -exitval => 0, -verbose => 3 ) if $man;

if ( $prompt ) {

    my %hash = ( 
	"File type" => {
		store => \$type,
		help => "CAMERA/BLAST",
		default => '',
	},
	"Input file/directory" => {
		store => \$input, 
		help => "File", 
		default => '',
	},
	"Output file/directory" => {
		store => \$output, 
		help => "Optional. Use default if you specify yes to\nDefault Output or if type is BLAST [default ''] ", 
		default => '',
	},
	"GNU Plotting instructions output file" => {
		store => \$plot,
		help => "File",
		default => '',
	},
	"Sequence length" => {
		store => \$length,
		help => "Integer",
		default => 50,
	},
	"GNU Plotting color" => {
		store => \$color,
		help => "RGB color code",
		default => "#ffffff",
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
	"GNU Plot file" => {
		store => \$gnu,
		help => ".png file",
		default => '',
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

    my %hash = ( "type"		=> { store => \$type, default => "", },
		 "input"  	=> { store => \$input, default => '', },
	   	 "output" 	=> { store => \$output, default =>  '', },
		 "default"	=> { store => \$default, default => 0, },
		 "plot"		=> { store => \$plot, deafult => '', },
		 "length"	=> { store => \$length, default => 50, },
		 "color"	=> { store => \$color, default	=> "#ffffff", },
		 gnu		=> { store => \$gnu, default => '', },	
	   	 save	 	=> { store => \$save, default => '', },
	   	 qsub	 	=> { store => \$qsub, default => 0, }, 
	       );

    Parse( $parse, \%hash );

}

die "Type and GNU plotting instructions file must be specified" if ( $type eq '' and $plot eq '' );
die "Ouput must be provided if file type is CAMERA" if ( $type eq "CAMERA" and $output eq '' );

my ( $valid_input, $valid_output, $valid_plot, $valid_gnu );

if ( $input ne '' ) {

    %result = FileIO({ input_file=>$input });
    $valid_input = $result{input_file};

    if ( $default ) {

	my $name = "result.out";
        $valid_output = CreateDefaultOutput({ class => 'TaxonomySearch' });

	if ( -t STDOUT ) {
	    print "Please provide the output file name: [default result.out]";
	    $name = <STDIN>;
        }

        $valid_output .= $name;

    }

    if ( $output ne '' ) {
        %result = FileIO({ output_file=>$output });
        $valid_output = $result{output_file};
    }

} else { pod2usage( -exitval => 0, -verbose => 1); }

if ( $plot ne '' ) {
    %result = FileIO({ output_file => $plot });
    $valid_plot = $result{output_file};
}

if ( $gnu ne '' ) {
    %result = FileIO({ output_file => $gnu });
    $valid_gnu = $result{output_file};
}

if ( $save ne '' ) {

    my %hash = ( type => $type,
		 input 	=> $valid_input, 
	  	 output	=> $valid_output,
		 plot => $valid_plot,
		 length => $length,
		 color => $color,
		 default => $default,
	  	 qsub 	=> $qsub, 
		 gnu => $gnu,
	       );

    Save( $save, \%hash );
}

if( $qsub ) {
    
} else {
    main({ type => $type, input => $valid_input, output => $valid_output, plot => $valid_plot, length => $length, color => $color, gnu => $valid_gnu });
}

1;
