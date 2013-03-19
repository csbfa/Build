package TMPL::MRPlot;

=pod

=head1 OWNER

Karin Holmfeldt

=head1 AUTHOR

Brandon Webb

=head1 NAME

MRPlot.pm - Perl module for MRPlot.pl

=head1 SYNOPSIS

Usage:

 None

=head1 DESCRIPTION

=head1 SUBROUTINES

 MRPlot::recruitment ({ type=>CAMERA/BLAST, input=>file, plot=>file, length=>LENGTH,color=> COLOR }) -- Generate a recruitment plot file for GNU plotting given a .csv input file and file type, an output file name, and additional optional arguments LENGTH, and COLOR.

 MRPlot::pBLASTnt({ input=>file,output=>file }) -- Given a BLAST output file run on CAMERA (.csv format), parse and format the output .csv file for plotting through program Recruitment.pl.

=head1 EXIT STATUS

MetagonmeRecruitmentPlot dies on error, returns TRUE on success.

=head1 Change Log

06/19/2012	Brandon Webb		Standards Adherence, Documentation
06/20/2012	Brandon Webb		Exportation to perl module

=head1 COPYRIGHT

Copyright 2012 TMPL

Permission is granted to copy, distribute and/or modify this 
document under the terms of the GNU Free Documentation 
License, Version 1.2 or any later version published by the 
Free Software Foundation; with no Invariant Sections, with 
no Front-Cover Texts, and with no Back-Cover Texts.

=cut

# Primary Function:
# Parse input.csv and output read position to result.csv 

use strict;
use warnings;
use TMPL::Utilities;
use Params::Validate qw(:all);
use Exporter qw( import );

our $VERSION     = 1.00;
our @ISA         = qw( Exporter );
our @EXPORT   	 = qw( main pBLASTnt recruitment );
our %EXPORT_TAGS = ( DEFAULT => [qw( main pBLASTnt recruitment )] );

sub main {

    my %vars = validate ( @_, {
	type => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	input => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	output => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	plot => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	length => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	color => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	gnu => {
	    optional => 0,
	    TYPE     => SCALAR
	},
    } );

    if ( $vars{type} =~ /CAMERA/i ) {
    	pBLASTnt({ input => $vars{input}, output => $vars{output} });
    	recruitment({ type => $vars{type}, input => $vars{output}, plot => $vars{plot}, length => $vars{length}, color => $vars{color} });
    } elsif ( $vars{type} =~ /BLAST/i ) {
    	recruitment({ type => $vars{type}, input => $vars{input}, plot => $vars{plot}, length => $vars{length}, color => $vars{color} });
    } else {
    	die "Input Error: CAMERA/BLAST expected. Instead recieved: $vars{type}: #!";
    }

    # GNU Plot
    my $gnu = $vars{gnu};
    if ( $gnu ) { CreateGraph({ input => $vars{plot}, gnu => $gnu }); }
}

sub pBLASTnt {

    my %vars = validate ( @_, {
	input => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	output => {
	    optional => 0,
	    TYPE     => SCALAR
	}
    } );

    my ( $input, $output ) = ( $vars{input}, $vars{output} );

    open ( my $INFILE, "<:crlf", $input ) or die "Error opening $input: $!";
    open ( my $OUTFILE, ">", $output ) or die "Error opening $output: $!";

    print $OUTFILE "Start\tStop\n\n";

    foreach( <$INFILE> ){
        chomp( $_ );
        my $line = $_;
        my ( $direction, $start, $qst, $qs, $alength, $alen, $stop );
    	if ( $line =~ /^.*\s(\d*):(\d*)(.*)\sMW:\d*,(\d*),(\d*$)/i ) {
	    my @lineArgs = ( $1, $2, $3, $4, $5 );
 	    $direction = $lineArgs[2];
	    $qst = $lineArgs[3];
	    $qs = $qst * 3;
	    $alength = $lineArgs[4];
	    $alen = $alength * 3;
	    $start = ( $direction = /^.*forward.*$/i ) ? $lineArgs[0] + $qs - 3 : $lineArgs[1] - $qs + 3 - $alen;
	    $stop = $start + $alen;
	    print $OUTFILE "$start\t$stop\n";
    	}
    }

    # Security:
    # Close IO

    close $INFILE or die "Error closing $INFILE: $!";
    close $OUTFILE or die "Error closing $OUTFILE: $!";

}

sub recruitment {

    my %vars = validate ( @_, {
	type => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	input => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	plot => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	length => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	color => {
	    optional => 0,
	    TYPE     => SCALAR
	}
    } );

    my ( $type, $input, $plot, $length, $color ) = ( $vars{type}, $vars{input}, $vars{plot}, $vars{length}, $vars{color} );

    open ( my $INFILE, "<:crlf", $input ) or die "Error opening file $input: $!";
    open ( my $OUTFILE, ">", $plot ) or die "Error opening file $plot: $!";

    my @blast;
    my ( $y, $a, $b, $c, $d );
    my $id = 'XXX';

    ( $a, $b, $c, $d ) = ( $type =~ /CAMERA/i ) ?  ( 2, 1, 3, 4 ) : ( 3, 2, 8, 9 );

    while ( <$INFILE> ) {
    	chomp ( $_ );
    	@blast = split ( /\t/, $_ );
       	if ( $id ne $blast[0] and $blast[$a] > $length ) {
	    $y = $blast[$b] * 25 + 1000;
	    print $OUTFILE "set arrow from $blast[$c],$y to $blast[$d],$y as $color\n";
	    $id = $blast[0];
    	}
    }

    # Security:
    # Close IO

    close $INFILE or die "Error closing $INFILE: $!";
    close $OUTFILE or die "Error closing $OUTFILE: $!";  

}

1;
