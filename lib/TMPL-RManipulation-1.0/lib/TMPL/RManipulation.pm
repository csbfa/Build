package TMPL::RManipulation;

=pod

=head1 AUTHOR

Jonathan Cummings

=head1 NAME

RManipulation.pm -- Perl module package for R manipulation and output usage

=head1 SYNOPSIS

Usage:

 None

=head1 DESCRIPTION

RManipulation contains subroutines used for R function manipulation used within the TMPL computing environment.

=head1 SUBROUTINES

Utilities::run002gc ( {inputdir=>$inputName, outputdir=>$outputName} )

Utilities::runHist ({inputdir=>$inputName, outputdir=>$outputName })

=head1 EXIT STATUS

Utilities dies on error, returns TRUE on success.

=head1 Change Log

None.

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
use Capture::Tiny ':all';
use Statistics::R ':all';
use File::Spec 'rel2abs';
use Params::Validate ':all';

sub run002gc {
    my %vars = validate
    (@_, 
        {	
            inputdir => 
            {	
                optional => 0,
                type => SCALAR,
            },
	    outputdir =>
	    {
		optional => 0,
		type => SCALAR
	    }
        }
    );

    my $inputDir = $vars{inputdir};
    my $outputDir = $vars{outputdir};
    
    if($^O eq 'MSWin32' and $inputDir!~/^.*(\\$)/i){
        $inputDir.='\\';
    } elsif($^O ne 'MSWin32' and $inputDir!~/^.*(\/$)/i){
        $inputDir.='\/';
    }
    
    if($^O eq 'MSWin32' and $outputDir!~/^.*(\\$)/i){
        $outputDir.='\\';
    } elsif($^O ne 'MSWin32' and $outputDir!~/^.*(\/$)/i){
        $outputDir.='\/';
    }
    
    $inputDir=~s/\\/\//g;
    $outputDir=~s/\\/\//g;
    
    my $RInterpreter = Statistics::R->new;
    my @inputFiles = ();
    opendir(INPUTDIR, $inputDir);
    
    foreach my $file (readdir(INPUTDIR))
    {
        if($file=~/^.*.gc$/i){
            my $fullPathInputFile = $inputDir.$file;
            $fullPathInputFile=~s/\\/\//g;
            my $fullPathOutputFile = $outputDir.$file;
            $fullPathOutputFile=~s/.gc/.freq/;
            $RInterpreter->set('inputFile', $fullPathInputFile);
            $RInterpreter->set('outputFile', $fullPathOutputFile);
            $RInterpreter->run(qq 'gctab<-read.table(inputFile)' );
            $RInterpreter->run(qq 'gctab\$bins<-cut(gctab\$V1,breaks = seq(0,1,0.02), include.lowest = TRUE)');
            $RInterpreter->run(qq 'gcdat<-as.data.frame(table(gctab\$bin)/length(gctab\$V1))' );
            $RInterpreter->run(qq 'freq<-gcdat\$Freq' );
            $RInterpreter->run(qq 'write(freq, outputFile)' );
            open OUTFILE, $fullPathOutputFile;
            my $frequencyString = do { local $/; <OUTFILE>};
            close OUTFILE;
            open OUTFILE, '+>'.$fullPathOutputFile;
            $frequencyString=~s/\s/\n/g;
            print OUTFILE $frequencyString;
            close OUTFILE;
        }
    }
    
    closedir(INPUTDIR);
}

sub runHist{
    my %vars = validate
    (@_, 
        {	
            inputdir => 
            {	
                optional => 0,
                type => SCALAR,
            },
	    outputdir =>
	    {
		optional => 0,
		type => SCALAR,
	    },
        }
    );
    
    my $inputDir = $vars{inputdir};
    my $outputDir = $vars{outputdir};
    
    if($^O eq 'MSWin32' and $inputDir!~/^.*(\\$)/i){
        $inputDir.='\\';
    } elsif($^O ne 'MSWin32' and $inputDir!~/^.*(\/$)/i){
        $inputDir.='\/';
    }
    
    if($^O eq 'MSWin32' and $outputDir!~/^.*(\\$)/i){
        $outputDir.='\\';
    } elsif($^O ne 'MSWin32' and $outputDir!~/^.*(\/$)/i){
        $outputDir.='\/';
    }
    
    $inputDir=~s/\\/\//g;
    $outputDir=~s/\\/\//g;
    
    my $RInterpreter = Statistics::R->new;
    $RInterpreter->set('library', 'MASS');
    
    opendir INPUTDIR, $inputDir;
    my @inputFiles = ();
    
    foreach my $file(readdir(INPUTDIR)){
	push(@inputFiles, $inputDir.$file) if(defined $file);
    }
    
    for(my $i=0; $i<@inputFiles; $i++){
	for(my $j=$i+1; $j<@inputFiles; $j++){
	    my $first = $inputFiles[$i];
	    my $second = $inputFiles[$j];
	    if($first=~/^.*.gc$/i and $second=~/^.*.gc$/i){
		$first=~s/\\/\//g;
		$second=~s/\\/\//g;
		$RInterpreter->set('inputOne', $first);
		$RInterpreter->set('inputTwo', $second);
		$first =~ /^.*\/(.*).gc/i;
		$first=$1;
		$second =~ /^.*\/(.*).gc/i;
		$second=$1;
		$RInterpreter->set('outfile', $outputDir.$first.'_vs_'.$second.'.pdf');
		$RInterpreter->run(qq 'data1<-scan(inputOne)' );
		$RInterpreter->run(qq 'data2<-scan(inputTwo)' );
		$RInterpreter->run(qq 'pdf(outfile)' );
		my $title = $first.' vs '.$second;
		$RInterpreter->run(qq 'hist(data1,freq=FALSE,breaks=seq(0,1,0.01), main="$title",xlab="GC",col="blue")' );
		$RInterpreter->run(qq 'hist(data2,freq=FALSE,breaks=seq(0,1,0.01), add=T, col=rgb(0,1,0,0.5))' );
		$RInterpreter->run(qq 'dev.off()' );
	    }
	}
    }
}

sub latticeHist{
    my %vars = validate
    (@_, 
        {	
            input_dir => 
            {	
                optional => 0,
                type => SCALAR,
            },
	    output_file =>
	    {
		optional => 0,
		type => SCALAR,
	    },
        }
    );
    my $start_path = Cwd->getcwd;
    my $input_dir = $vars{input_dir};
    my $output_file = $vars{output_file};
    $output_file = $1.".pdf" if($output_file=~/^(.*)\..*$/i);
    my @input_files = ();
    
    chdir($input_dir);
    my $contents = <*>;
    if($contents){
	foreach my $file($contents){
	    if($file=~/^.*.gc$/i){
		push(@input_files, $file);
	    }
	}
    }

    my $temp_input = $output_file.".tmp";
    open(TEMPFILE, "+>".$temp_input);
    print TEMPFILE "gc,run\n";
    my $counter = 0;
    foreach my $input_file(@input_files){
	open(INPUTFILE, $input_file);
	my $file_name = $1 if($input_file=~/^(.*).gc$/i);
	foreach my $line(<INPUTFILE>){
	    chomp($line);
	    print TEMPFILE ("$line,$file_name\n");
	    $counter++;
	}
    }
    close(TEMPFILE);
        
    my $RInterpreter = Statistics::R->new;    
    $RInterpreter->set('inputFile', $temp_input);
    $RInterpreter->set('outputFile', $output_file);
    $RInterpreter->run(qq 'ih4s.df = read.csv(inputFile, sep = ",", dec=".")');
    $RInterpreter->run(qq 'ih4s.df\$run = factor(ih4s.df\$run)' );
    $RInterpreter->run(qq 'pdf(file=outputFile)' );
    $RInterpreter->run(qq 'hist( ih4s.df\$gc, data = ih4s.df, xlab = "GC", main = "Histograms of GC Frequency of Whole Reads")' );
    $RInterpreter->run(qq 'dev.off()' );
    
    unlink ($temp_input);
    chdir($start_path);
}

1;
