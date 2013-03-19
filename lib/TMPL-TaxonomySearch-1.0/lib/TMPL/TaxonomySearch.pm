package TMPL::TaxonomySearch;

=pod

=head1 OWNER

Karin Holmfeldt

=head1 AUTHOR

Brandon Webb

=head1 NAME

TaxonomySearch.pm -- Perl module package for TaxonomySearch.pl

=head1 SYNOPSIS

Usage:

 None

=head1 DESCRIPTION

TaxonomySearch.pm contains the subroutines necessary for TaxonomySearch.pl application to run. 

=head1 SUBROUTINES

 TaxonomySearch::main({ input => $input, output => $output, xml => $xml, verbose => $verbose }) -- main method 

 TaxonomySearch::retrieve( string ) -- Establish NCBI DB communication, initialize agents, and retireve XML query results from NCBI DB

 TaxonomySearch::process( string ) -- Process XML results

 TaxonomySearch::parse({ intput=>file, output=>file, genomes=>string }) -- Private method. Helper method for Twig

 TaxonomySearch::repair({ plot=>file, output=>file, option=>file }) -- Using PHP tidy functionality, attempt to repair the xml file

=head1 EXIT STATUS

Subroutines exit on error, return 0 otherwise.

=head1 Change Log

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
use LWP::UserAgent;
use LWP::Simple;
use XML::LibXML::Reader;
use HTTP::Request;
use HTTP::Headers;
use Params::Validate qw(:all);
use Exporter qw( import );

our $VERSION     = 1.00;
our @ISA         = qw( Exporter );
our @EXPORT   	 = qw( main process retrieve );
our %EXPORT_TAGS = ( DEFAULT => [qw( main retrieve )] );

my @taxonomy = ();
my $XML;
my $XML_data;

sub main {

    my %vars = validate (@_, {
	input   => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	output  => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	verbose => {
	    optional => 0,
 	    TYPE     => SCALAR
	}
    } );

    open ( my $INFILE, "<:crlf", "$vars{input}" ) or die "Error opening file $vars{input}: $!";
    open ( my $OUTFILE, ">", "$vars{output}" ) or die "Error opening file $vars{output}: $!";

    my ( $gi, $line ) = ( '', '');
    my @tokens = ();

    while ( $line = <$INFILE> ) {

    	chomp ( $line );
    	@tokens = split ( /\|/, $line);
    	$gi .= "$tokens[1], ";
    }

    seek ( $INFILE, 0, 0 );
    chop ( $gi );

    retrieve({ gi => $gi, verbose => $vars{verbose} });

    while ( $line = <$INFILE> ) {

    	chomp( $line );
    	my $str =  pop @taxonomy;
    	print $OUTFILE "$line $str\n";
    }

    close $INFILE or die "Error closing file $INFILE: $!";
    close $OUTFILE or die "Error closing file $OUTFILE: $!";

    return 0;

}

sub retrieve {

    my %vars = validate (@_, {
	gi => {
	    optional => 0,
	    TYPE     => SCALAR
	},
	verbose => {
	    optional => 0,
 	    TYPE     => SCALAR
	}
    } );

    my $verbose = $vars{verbose};
    my $gi = $vars{gi};
   
    my ( $response, $QueryKey, $WebEnv, $ua, $headers, $request ) = '';
    my $efetch = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi";
    my $epost = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/epost.fcgi";


    $ua = LWP::UserAgent->new();
    $ua->agent("ePost/eFetch");
    if ( $verbose ) { $ua->show_progress( 1 ); }

    $headers = new HTTP::Headers( 
			Accept		=> "text/html, text/plain",
			Content_type	=> "application/x-www-form-urlencoded" );

    $request = HTTP::Request->new( "POST", $epost, $headers, "db=protein&id=$gi" );
    $response = $ua->request( $request );

    if ( $verbose ) {

    	print "Responce status message: [" . $response->message . "]\n
    	       Responce content: 	[" . $response->content . "]\n";
    }

    $response->content =~ m|<QueryKey>(\d+)</QueryKey.*<WebEnv>(\S+)</WebEnv>|s;
    ( $QueryKey, $WebEnv)  = ( $1, $2 );

 
    my $reader = XML::LibXML::Reader->new(location => "$efetch?db=protein&query_key=$QueryKey&WebEnv=$WebEnv&rettype=gp&retmode=xml") 
	or die "Request Error: $!";

    while ( $reader->read ) {

    	if ($reader->nodeType == XML_READER_TYPE_ELEMENT) {
    	    if( $verbose) {		
		if($reader->name() eq 'GBSeq_taxonomy') {
		    print "\n-----------------\nElement ". $reader->name,"\n";
	    	    my $str = $reader->readInnerXml();
		    chomp ( $str );
		    print "$str";  
		    unshift (@taxonomy, $str);
                }
    	    } else {
    	        if($reader->name() eq 'GBSeq_taxonomy') {
	    	    my $str = $reader->readInnerXml();
		    chomp ( $str );
		    unshift (@taxonomy, $str);
            	}
	    }
        }
    }

    $reader->finish;

    return 0;
}

1;
