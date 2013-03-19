package TMPL::Core;

use strict;
use warnings;

use Capture::Tiny qw(:all);
use Statistics::R qw(:all);
use File::Spec qw (rel2abs);
use Params::Validate qw(:all);
use Exporter qw( import );
use File::HomeDir;

our $VERSION     = 1.00;
our @ISA         = qw( Exporter );
our @EXPORT   	 = qw( Combiner LatticeHist Run02 Runhist TrimPipe );
our %EXPORT_TAGS = ( DEFAULT => [qw( Combiner LatticeHist Run02 Runhist TrimPipe )] );

sub Combiner {
    my %vars = validate
    (@_,
        {
            input1 => {
                optional => 0,
                type     => SCALAR
            },
            input2 => {
                optional => 0,
                type     => SCALAR
            },
            output => {
                optional => 0,
                type     => SCALAR
            },
	    qsub => {
		optional => 1,
		type     => SCALAR
	    }
        }
    );
    
    my $valid_in1 = $vars{input1};
    my $valid_in2 = $vars{input2};
    my $valid_out = $vars{output};
    $valid_out.='/combined.fastq' if(-d $valid_out);
    if($vars{qsub}){
	my $script = "VALID_IN1=\$VALID_IN1\nVALID_IN2=\$VALID_IN2\nVALID_OUT=\$VALID_OUT\nperl -e \"use Core qw(Combiner); Core::Combiner({input1=>\'\$VALID_IN1\', input2=>\'\$VALID_IN2\', output=>\'\$VALID_OUT\'})\"";
	Qsub({script_contents=>$script, variables=>{valid_in1=>$valid_in1, valid_in2=>$valid_in2, valid_out=>$valid_out}});
    } else {
	
	#Open files for reading and writing
	open FIRSTHALF,"< $valid_in1" or die $!;
	open SECONDHALF,"< $valid_in2" or die $!;
	open COMBINEDFILE, ">", "$valid_out" or die $!;
	
	my $line1 = '';
	my $line2 = '';
	my $line  = '';
	while ($line1=<FIRSTHALF>) {
	    $line2=<SECONDHALF>;
	    $line1=~s/^@/\>/; #convert @ to >
	    $line2=~s/^@/\>/; #convert @ to >
	    print COMBINEDFILE $line1;
	    $line=<FIRSTHALF>;
	    print COMBINEDFILE $line; #print sequence information
	    
	    print COMBINEDFILE $line2;
	    $line=<SECONDHALF>;
	    print COMBINEDFILE $line;  #print sequence information
	    
	    <FIRSTHALF>;
	    <FIRSTHALF>;
	    <SECONDHALF>;
	    <SECONDHALF>;
	    #discard quality information
	}
	#Close files for security
	close(FIRSTHALF);
	close(SECONDHALF);
	close(COMBINEDFILE);
    }
}

sub Run02 {
    my %vars = validate
    (@_, 
        {	
            input => 
            {	
                optional => 0,
                type => SCALAR,
            },
            output =>
            {
                optional => 0,
                type => SCALAR
            },
	    qsub => {
		    optional => 1,
		    type	 => SCALAR
	    }
        }
    );

    my $inputDir = $vars{input};
    my $outputDir = $vars{output};
    if($vars{qsub}){
	my $script = "VALID_IN=\$INPUTDIR\nVALID_OUT=\$OUTPUTDIR\nperl -e \"use Core qw(Run02); Core::Run02({input=>\'\$VALID_IN\', output=>\'\$VALID_OUT\'})\"";
	Qsub({script_contents=>$script, variables=>{inputdir=>$inputDir, outputdir=>$outputDir}});
    } else{
	
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
}

sub LatticeHist{
    my %vars = validate
    (@_, 
        {	
            input => 
            {	
                optional => 0,
                type => SCALAR,
            },
            output =>
            {
                optional => 0,
                type => SCALAR,
            },
	    qsub => {
		    optional => 1,
		    type => SCALAR
	    }
        }
    );
    my $start_path = Cwd->getcwd;
    my $input_dir = $vars{input};
    my $output_file = $vars{output};
	
    if($vars{qsub}){
	my $script = "VALID_IN=\$VALID_IN\nVALID_OUT=\$VALID_OUT\nperl -e \"use Core qw(LatticeHist); Core::LatticeHist({input=>\'\$VALID_IN\', output=>\'\$VALID_OUT\'})\"\n";
	Qsub({script_contents=>$script, variables=>{valid_in=>$input_dir, valid_out=>$output_file}});
    } else {
	    
	$output_file = $1.".pdf" if($output_file=~/^(.*)\..*$/i);
	my @input_files = ();
	
	chdir($input_dir);
	my @contents = <*>;
	if(@contents){
	    foreach my $file(@contents){
		if($file=~/^.*.gc$/i){
		    push(@input_files, $file);
		}
	    }
	}
    
	my $temp_input = $output_file.".tmp";
	open(TEMPFILE, "+>".$temp_input);
	print TEMPFILE "gc,run\n";
	foreach my $input_file(@input_files){
	    open(INPUTFILE, '<'.$input_file);
	    my $file_name = $1 if($input_file=~/^(.*).gc$/i);
	    chomp($file_name);
	    foreach my $line(<INPUTFILE>){
		chomp($line);
		print TEMPFILE "$line,$file_name\n";
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
}

sub TrimPipe {
    my %vars = validate
    (@_,
	{
	    input =>
	    {
		optional => 0,
		type	 => SCALAR
	    },
	    output =>
	    {
		optional => 0,
		type     => SCALAR
	    },
	    qsub  =>
	    {
		optional => 0,
		type	 => SCALAR
	    }
	}
    );
    my $valid_in = $vars{input};
    my $valid_out = $vars{output};
    chdir($valid_out);
    mkdir('quality');
    chdir('quality');
    my $valid_qual = Cwd->getcwd;
    chdir($valid_in);
    my @dir_contents = <*>;
    my @gunzipped_files = ();
    foreach my $file(@dir_contents){
       if($file =~ /^.*fastq$/i){
	  push(@gunzipped_files, $file);
       } elsif($file =~/^.*fastq.gz$/i){
	  `gzip -d $file`;
	  push(@gunzipped_files, substr($file, 0, length($file)-3));
       }
    }
    
    my $shell_script_qsub = File::HomeDir->my_home."/TMPL/lib/Applications/TrimPipe/trim20.sh";
    my $shell_script_noqsub = File::HomeDir->my_home."/TMPL/lib/Applications/TrimPipe/trim20noqsub.sh";
    my $count = 0;
    $valid_qual = substr($valid_qual, 0, length($valid_qual)-1) if($valid_qual =~ /^.*\/$/i);
    
    if($vars{qsub}){
	foreach my $file(@gunzipped_files){
	    Qsub({script=>$shell_script_qsub, variables=>{dir=>$valid_in, finaldir=>$valid_out, file=>$file, quality=>$valid_qual}});
	}
    } else{
	foreach my $file(@gunzipped_files){
	    `$shell_script_noqsub $valid_in $valid_out $file $valid_qual`;
	}
    }
    
}

sub Runhist{
    my %vars = validate
    (@_, 
        {	
            input => 
            {	
                optional => 0,
                type => SCALAR,
            },
	    output =>
	    {
		optional => 0,
		type => SCALAR,
	    },
	    qsub => {
		optional => 1,
		type => SCALAR
	    }
	}
    );
    
    my $inputDir = $vars{input};
    my $outputDir = $vars{output};
    
    if($vars{qsub}){
	my $script = "VALID_IN=\$INPUTDIR\nVALID_OUT=\$OUTPUTDIR\nperl -e \"use Core qw(Runhist); Core::Runhist({input=>\'\$VALID_IN\', output=>\'\$VALID_OUT\'})\"";
	Qsub({script_contents=>$script, variables=>{inputdir=>$inputDir, outputdir=>$outputDir}});
    } else{
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
}

1;
