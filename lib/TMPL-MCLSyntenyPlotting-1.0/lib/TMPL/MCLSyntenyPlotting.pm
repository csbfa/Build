package TMPL::MCLSyntenyPlotting;

=pod

=head1 OWNER

Karin Holmfeldt

=head1 AUTHOR

Brandon Webb

=head1 NAME

MCLSyntenyPlotting.pm -- Perl module package for MCLSyntenyPlotting.pl

=head1 SYNOPSIS

Usage:

 None

=head1 DESCRIPTION

MCLSyntenyPlotting.pm contains the subroutines necessary for MCLSyntenyPlotting.pl application to run. 

=head1 SUBROUTINES

 MCLSyntenyPlotting::insert({ ref=>file }) -- parses the file into a hashtable

 MCLSyntenyPlotting::get( string ) -- returns the values found at the key string in the hashtable

 MCLSyntenyPlotting::trim( string ) -- trims "Phi" from the genome string

 MCLSyntenyPlotting::run({ intput=>file, output=>file, genomes=>string }) -- given the input and file, run parses the input file according to information contained in the hashtable and outputs the .csv information to the output file.

 MCLSyntenyPlotting::plot({ plot=>file, output=>file, option=>file }) -- given the output file from run as the input file, an output file, and an options file, plot outputs GNU plotting instructions to the output file.

=head1 EXIT STATUS

Subroutines exit on error, return 0 otherwise.

=head1 Change Log

06/25/2012	Brandon Webb	Renamed package to MCLSyntenyPlotting

=head1 COPYRIGHT

Copyright 2012 TMPL

Permission is granted to copy, distribute and/or modify this 
document under the terms of the GNU Free Documentation 
License, Version 1.2 or any later version published by the 
Free Software Foundation; with no Invariant Sections, with 
no Front-Cover Texts, and with no Back-Cover Texts.

=cut

use strict;
use warnings;
use Tie::File;
use TMPL::Utilities;
use Params::Validate qw(:all);
use Exporter qw( import );

our $VERSION     = 1.02;
our @ISA         = qw( Exporter );
our @EXPORT   	 = qw( main insert update remove get initialize configure run plot help );
our %EXPORT_TAGS = ( DEFAULT => [qw( main insert update remove get initialize configure run plot help )] );

my %reference_table = ();

sub main {

    my %vars = validate (@_, {
	ref 	=> {
	    optional => 0,
	    TYPE     => SCALAR
	},
	input 	=> {
	    optional => 0,
	    TYPE     => SCALAR
	},
	output 	=> {
	    optional => 0,
	    TYPE     => SCALAR
	},
	plot	=> {
	    optional => 0,
	    TYPE     => SCALAR
	},
	option	=> {
	    optional => 0,
	    TYPE     => SCALAR
	},
	gnu	=> {
	    optional => 0,
	    TYPE     => SCALAR
	}	
    } );


    my $gnu = $vars{gnu};
    my $plot = $vars{plot};
    my $genomes = insert( {ref=>$vars{ref} });
    run({ input=>$vars{input}, output=>$vars{output}, genomes=>$genomes });

    if ( $plot ) { plot({ plot=>$plot, input=>$vars{output}, option=>$vars{option} }); }

    # GNU plotting

    if ( $gnu ne '' ) { CreateGraph({ class=>"MCLSynteny", input=>$vars{plot}, gnu => $gnu }); }

}

sub get {

    exists $reference_table{$_[0]} ? return @{$reference_table{$_[0]}} : die "$_[0] not contained in reftable: $!";
  
}

# TODO:
# this is to insert whole files (will overwrite existing data)
# update with mixed new/old data (update count)
# need methods to combine certain keys (merge)
# delete whole files/sequence (include wildcard e.g. -r Phi18:3*, or range Phi18:3_orf1 - Phi18:3_orf10)
# delete individual phi
# show existing data in readable format
# find ways to compress

sub insert {

    my %vars = validate (@_, {
	ref => {
	    optional => 0,
	    TYPE     => SCALAR
	}
    } );
    
    my @tokens = ();
    my $ref = $vars{ref};
    my ( $str, $key, $genomes, $prefix ) = ( '', '', '', '' );

    open( my $INFILE, "<", $ref ) or die "Error opening $ref: $!";

    # input file into hash
    foreach my $line ( <$INFILE> ) {

	# clean and split the line
	chomp( $line );
	$line =~ s/[[:^print:]]+//g;
	@tokens = split(/\s+/, $line);

	# set key
	if ( substr( $tokens[0], 0, 1) eq '>' ) { 

	    $key = $tokens[0];
	    $key =~ s/>//gi;
	    $reference_table{$key} = () unless ( exists $reference_table{$key} );
	    splice ( @tokens, 0, 1 );

   	    # append new genomic key if the string does not exist in the genomic string
	    $prefix = substr( $key, 0, index( $key, '_' ));
	    unless ( $genomes =~ m/$prefix/ ) { $genomes .= "$prefix\t"; }
 	}

	foreach my $token ( @tokens ) {

	    if( $token =~ m/\d+\s*:\d+$/ ) {
		unshift( @{$reference_table{$key}}, $token );
	    } else {
		push( @{$reference_table{$key}}, $token ); 
	    }
	} 
    }

    close $INFILE or die "Error closing $INFILE: $!";

    return $genomes;
}

sub trim {

    my $str = $_[0];
       $str =~ s/>//gi;
       $str = substr($str, 0, index($str, '_' ));

    return $str;

}

sub group {

    my $prefix = "$_[0]_orf";
    my $line = $_[1];
    my @row = ();
    my @tokens = split ( /\s+/, $line );

    foreach my $token ( @tokens ) {
	$token =~ s/[[:^print:]]+//g;
	if ( $token =~ m/^$prefix.*$/i ) { push ( @row, $token ); } 
    } 

    return @row;
}

sub run {

    my %vars = validate (@_, {
	input   => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	output  => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	genomes => {
	    optional => 0,
	    TYPE     => SCALAR
	}
    } );

    my $count = 0;
    my $index = 0;
    my ( @var, @row1, @row2, $genome, $i );
    my ( $input, $output, $genomes ) = ( $vars{input}, $vars{output}, $vars{genomes} );

    # get the genomes "Phi#" we're working with
    my @genome_tags = split( /\s+/, $genomes ); 

    open ( my $INFILE, "<:crlf", $input ) or die "Error opening $input: $!";
    open ( my $OUTFILE, ">", $output ) or die "Error opening $output: $!";

    print $OUTFILE "Cluster\t$genomes\n";

    foreach my $line ( <$INFILE> ) {
	chomp( $line );
	$index++;

	# print line number and tab
	print $OUTFILE "$index\t";

	# get two arrays containing the group genomes
	@row1 = group( $genome_tags[0], $line );
	@row2 = group( $genome_tags[1], $line );

	# loop through each genome, grab its length, and print to outfile
	for $i ( 0 .. $#row1 ) {
	    @var = get( $row1[$i] );
	    $var[0] = "|".$var[0] if ( $i > 1 );
	    print $OUTFILE "$var[0]";
	}

	print $OUTFILE "\t";

	for $i ( 0 .. $#row2 ) {
	    @var = get( $row2[$i] );
	    $var[0] = "|".$var[0] if ( $i > 1 );
	    print $OUTFILE "$var[0]";
	}

	print $OUTFILE "\n";
    }

    
    close $OUTFILE or die "Error closing $OUTFILE: $!";
    close $INFILE or die "Error opening $INFILE: $!";

    return 0;

}

sub plot {

    my %vars = validate (@_, {
	plot => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	input => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	option => {
	    optional => 0,
	    TYPE     => SCALAR
	}
    } );

    my %tab;
    my $count = 0;
    my ( @data, @tokens, @coo1, @coo2, @x_1, @x_2 );
    my ( $x1, $x2, $y1, $y2, $i, $j, $k, $y );
    my ( $plot, $input, $options ) = ( $vars{plot}, $vars{input}, $vars{option} );

    open ( my $plot_file, ">", $plot ) or die "Error opening file $plot: $!";
    open ( my $options_file, "<:crlf", $options ) or die "Error opening file $options: $!";

    tie my @array, 'Tie::File', $options_file or die "Can't tie $options_file: $!";

    # tab: changes with as many genomes currently processing    
    @tokens = split(" ", $array[0]);
    foreach my $token ( @tokens ) {
	$count++;
	$tab{ $count } = $token; 
    } 

    my $xr = $array[1];
    my $yr = $array[2];
    my $prefix = $array[3];                        

    print $plot_file "set terminal png\nset style line 1 lt rgbcolor \"\#000000\" lw 1\nset style line 2 lt rgbcolor \"\#0000FF\" lw 1\nset style arrow 1 nohead ls 1\nset style arrow 2 nohead ls 2\nset autoscale\nset terminal postscript\nset output \"$prefix.png\"\n";

    for $i ( 1..$count ) { # this changes to the number in %tab

        open ( my $csv_in, "<:crlf", $input ) or die "Error opening file $input: $!";  
                       
	while ( <$csv_in> ) {   
            if ( $_ eq $prefix ) {         
 	        chomp ( $_ );                           
	        @data = split ( /\t/, $_ );
									   
	        if( $data[$i] ){                                                                      
		    @coo1 = split ( /\|/, $data[$i] );  
                               
		    for $j ( 0..$#coo1 ) {						   
		        if ( $coo1[$j] =~ /(\d+)\:(\d+)/ ) {					   
			    $y = $tab{$i} + 50;						  
			    print $plot_file "set arrow from $1,$tab{$i} to $2,$tab{$i} as 1\nset arrow from $1,$y to $2,$y as 1\nset arrow from $1,$y to $1,$tab{$i} as 1\nset arrow from $2,$y to $2,$tab{$i} as 1\n";		   
		        }
		    }
	        }
	    }
	}
	close $csv_in or die "Error closing $csv_in: $!";
    }

    open ( my $csv_in, "<:crlf", $input ) or die "Error opening file $input: $!";
			
    while ( <$csv_in> ) {
	if ( $_ eq $prefix ) {
 	    chomp ( $_ );  						
	    @data = split ( /\t/, $_ );
						
	    for $i ( 1..$count ) { # this changes to the number in %tab
	        if ( $data[$i] and $data[$i + 1] ) {
		    @coo1 = split ( /\|/, $data[$i] );					   
		    @coo2 = split ( /\|/, $data[$i + 1] );
                                      
		    for $j ( 0..$#coo1 ) {

		        @x_1 = split ( /\:/, $coo1[$j] );
		        if( @x_1 == 1 ) { push ( @x_1, 0 ); }
		        for $k ( 0..$#coo2 ) {			
			    @x_2 = split ( /\:/, $coo2[$k] );
			    if( @x_2 == 1 ) { push ( @x_2, 0 ); }				
			    $x1 = ( $x_1[0] + $x_1[1] ) / 2;		
			    $x2 = ( $x_2[0] + $x_2[1] ) / 2;
			    $y1 = $tab{ $i };				
		    	    $y2 = $tab{ $i } + 500; 		
		 	    print $plot_file "set arrow from $x1,$y1 to $x2,$y2 as 2\n";  		
		        }								
		    }									
	        }
	    }
	}
    }

    print $plot_file "set xr \[0\.0\:$xr\]\nset yr \[0\.0\:$yr\]";

    close $plot_file or die "Error closing $plot_file: $!";
    close $csv_in or die "Error closing $csv_in: $!";
    close $options_file or die "Error closing $options_file: $!";
	
    return 0;

}

1;
