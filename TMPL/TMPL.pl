use strict;
use warnings;
use Utilities;
use XML::Simple qw(XMLin);
use Cwd qw(abs_path);
use Core;
use Data::Dumper::Simple as => 'display', autowarn=>1;
use File::HomeDir;

&run;

sub run {
    my $xpath = File::HomeDir->my_home."/TMPL/lib/Modules/programs.xml";

    my $programs = XMLin($xpath);
    
    my @program_names = keys %{$programs->{program}};
    @program_names = sort { lc($a) cmp lc($b) } @program_names;
    
    my $program = chooseprogram(\@program_names);
    
    print "\nRun $program? (Y/N) " if(defined $program and $program ne '') or exit($!);
    
    my $resp = '';
    $resp = <STDIN>;
    chomp($resp) if(defined $resp and $resp ne '') or exit($!);
    
    return &run if('No' =~ qr/$resp/i);
    
    my %sub_table = (
        "Combiner" => \&Core::Combiner,
        "Runhist" => \&Core::Runhist,
        "LatticeHist" => \&Core::LatticeHist,
        "Run02" => \&Core::Run02,
        "TrimPipe" => \&Core::TrimPipe,
    );
    
    my @required_opts = keys %{$programs->{program}->{$program}};
    my $program_call = ();
    $program_call = createcall($program, \@required_opts, $programs);
    
    print "\nWould you like to use qsub? (Y/N) ";
    $resp = '';
    $resp = <STDIN>;    
    chomp($resp) if(defined $resp and $resp ne '') or exit($!);
    
    if('Y' =~ qr/$resp/i){
        $program_call->{qsub}=1;
    } else {
        $program_call->{qsub}=0;
    }
    
    no strict 'refs';
    &{$sub_table{$program}}($program_call);
}

sub createcall {
    my $program = shift;
    my $required_opts = shift;
    my $programs = shift;
    my %program_call = ();
    for(@$required_opts){
        if($_ eq 'inputdir'){
            my $inputdir = '';
            while((defined $inputdir and $inputdir eq '') or not defined $inputdir){
                my $resp = '';
                print "\nEnter path to input directory: ";
                $resp = <STDIN>;
                chomp($resp) if(defined $resp and $resp ne '') or exit($!);
                $inputdir = Utilities::ValidatePath({dir=>$resp});
            }
            $program_call{$programs->{program}->{$program}->{$_}}=$inputdir;
        } elsif($_ eq 'inputfile'){
            foreach my $inputs(@{$programs->{program}->{$program}->{$_}}){
                my $inputfile = '';
                while((defined $inputfile and $inputfile eq '') or not defined $inputfile){
                    print "Enter path to input file for option \'$inputs\': ";
                    my $resp = '';
                    $resp = <STDIN>;
                    chomp($resp) if(defined $resp and $resp ne '') or exit($!);
                    $inputfile = Utilities::ValidatePath({file=>$resp});
                }
                $program_call{$inputs} = $inputfile;
            }
        } elsif($_ eq 'outputfile'){
            my $default = Utilities::CreateDefaultOutput({class=>$program}).'/'.'output';
            my $resp = '';
            print "Current output directory is set to \'$default\' would you like to keep it? (Y/N) ";
            $resp = <STDIN>;
            chomp($resp) if(defined $resp and $resp ne '') or exit($!);
            if('Yes' =~ qr/$resp/i){
                $program_call{$programs->{program}->{$program}->{$_}} = $default;
            } else {
                my $outputfile = '';
                while((defined $outputfile and $outputfile eq '') or not defined $outputfile){
                    $resp = '';
                    print "\nEnter path to file: ";
                    $resp = <STDIN>;
                    chomp($resp) if(defined $resp and $resp ne '') or exit($!);
                    $outputfile = Utilities::ValidatePath({file=>$resp});
                }
                $program_call{$programs->{program}->{$program}->{$_}}=$outputfile;
            }
        } elsif($_ eq 'outputdir'){
            my $default = Utilities::CreateDefaultOutput({class=>$program});
            my $resp = '';
            print "Current output directory is set to \'$default\' would you like to keep it? (Y/N) ";
            $resp = <STDIN>;
            chomp($resp) if(defined $resp and $resp ne '') or exit($!);
            if('Yes' =~ qr/$resp/i){
                $program_call{$programs->{program}->{$program}->{$_}} = $default;
            } else {
                my $outputdir = '';
                while((defined $outputdir and $outputdir eq '') or not defined $outputdir){
                    $resp = '';
                    print "\nEnter path to directory or file: ";
                    $resp = <STDIN>;
                    chomp($resp) if(defined $resp and $resp ne '') or exit($!);
                    $outputdir = Utilities::ValidatePath({dir=>$resp});
                }
                $program_call{$programs->{program}->{$program}->{$_}}=$outputdir;
            }
        }
    }
    return \%program_call;
}

sub chooseprogram {
    my $program_names = shift;
    print "Please give the program name or type \'help\' for a list of possible programs. ";
    my $prog_to_run = '';
    $prog_to_run = <STDIN>;
    
    chomp($prog_to_run) if( defined $prog_to_run and $prog_to_run ne '') or exit($!);
    
    if('help' =~ qr/$prog_to_run/i){
        print "\n";
        for(@$program_names){
            print $_."\n";
        }
        return &chooseprogram($program_names);
    } else{
        for(@$program_names){
            return $_ if($_ =~ qr/$prog_to_run/i);
        }
    }
}
