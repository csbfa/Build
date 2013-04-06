=pod

=head1 NAME

 Build.PL - Builds the packaged TMPL library on system.

=head1 SYNOPSIS

 Build.PL [-h|help|?|man] [--DIR] <[install directory]>

=cut

use v5.16.0;

our $VERSION = 2.0;

use strict;
use warnings;
use Cwd;
use Net::Ping;
use Pod::Usage;
use IPC::Open3;
use Log::Log4perl;
use ExtUtils::Installed;
use Params::Check qw(check);
use English qw( -no_match_vars ); 
use Getopt::Long qw(:config bundling);
use File::Basename;
use File::HomeDir;
use Data::Dumper;
use XML::LibXML;
use XML::LibXML::Reader;

# CHECK IF ROOT USER
die( "Unsufficent permissions. Must be root user" )
    if ( $EFFECTIVE_USER_ID != 0 );

use constant {

R_REQ		=> "
Warning: 

This library installation will install R as part of the TMPL package.
If this machine is not connected to the internet, then R must be installed
maunally. If R is not installed, then this build will fail. 

R requires the gcc and gfortran compiler ( packaged as gcc ) to be installed, 
or the build will fail. If gcc and gfortran is not installed or you are unsure 
if gcc and gfortran is installed, please exit this installer and verfiy/install 
gcc and gfortran. GNU GCC can be found as a binary at 
http://gcc.gnu.org/wiki/GFortranBinaries. 

NOTE: 	Most non-MacOS UNIX systems already come with gcc and gfortran installed.
	The Windows gcc/gfortran distribution is called MinGW
      	The MacOS gcc/gfortran distribution can be installed from MacPorts as gccXX,
	where XX is the latest gcc release number ( e.g. gcc48 ) or, alternatively,
	MinGW can be installed.

R requires X11 to be installed. If X11 is not installed or you are unsure if
X11 is installed, please exit this installer and verify/install X11. 

Continue with build? (y/n) ",


CPAN          	=> "
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: 
:										:
: 			      Running CPAN -i				        :
:										:
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n\n",

CPAN_WARN	=>"
Unable to establish connection with CPAN. Installing modules from 
archive. This process may fail due to missing dependencies on the
system. It is recommended to connect to the internet and retry install",

MOD           	=> "
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: 
:										:
: 		 	    Installing Modules				        :
:										:
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n\n",

MOD_COMPLETE  	=> "
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:										: 
: 		         Modules Install Completed			        :
:										:
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n\n",


TMPL 	  	=> "
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:										: 
: 		  	    Installing TMPL				        :
:										:
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n\n",

TMPL_COMPLETE 	=> "
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:										: 
: 		  	 Installing TMPL Completed			        :
:										:
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n\n",

};

our $perl_path = '';
our ( $cmd, $retval, $path, $SS ) = ('', '', '', '');
my  @result = ();
my ( $help, $man ) = ('', ''); 
my ( $network_access, $p, $pid, $cwd ); 
my ( $perlexename, $perlbinpath, $aoeiurvnaio );
($perlexename, $perlbinpath, $aoeiurvnaio) = fileparse($^X);

GetOptions('h|help|?' 	=> \$help, 
	   'man'	=> \$man,
 	   'd|DIR:s'  	=> \$path) or pod2usage(2);

pod2usage( -exitval => 0, -verbose => 1 ) if $help or $man;

Log::Log4perl->init('log.conf');
my $logger = Log::Log4perl->get_logger();

if ( $^O eq "MSWin32" ) {

    $SS = '\\';
    $path = "C:$SS"."Users$SS"."Administrator$SS" if($path eq '');

} else {

    $path = '~/' if($path eq '');
    $SS = '/';

}

# check if the version file exist under $pathTMPL folder
my $xpath = File::HomeDir->my_home."/TMPL/version.xml";
my $version = 0;
#$logger->info("Version file $xpath ");

if ( -e $xpath) {
	# if version.xml exist it's version should be greate than our $VERSION 
	
	my $version_xml = XML::LibXML::Reader->new(location => $xpath);
	
	while ($version_xml->read) {
	  if ($version_xml->nodeType == XML_READER_TYPE_ELEMENT) {
	  	
	    if ($version_xml->name eq "tmplversion" ) {
	
		 if ($version_xml->moveToFirstAttribute) {
		 	  $version = $version_xml->value;
		      $version_xml->moveToElement;
		 }
	    }
	  }
    }
    
    #my $version = $version_xml->{version}->{tmpl}->{tmplversion}->[0];
    $logger->info("Version  on disk version $version installation version $VERSION ");
	if ( $version < $VERSION ) 
	{
		# do cleanup 
		$logger->info("Version $version is not supported. Cleanup will be done and version $VERSION will be installed.");
		sanity_clean_up("");
	}
	else
	{
		#no need to install, already on the latest version
		$logger->logdie("You are running the latest version of TMPL script !");
	}
    
}
else 
{
	# first do sanity cleanup and then install everything
	sanity_clean_up("");
}

$logger->warn(R_REQ);
my $response = <STDIN>;
$logger->info("exiting Build.PL...") and exit(1) if ( $response =~ /^no$/i );

$network_access = test_connection();

$cmd = ($^O eq "MSWin32") ? "WHERE R" : "which R" ;
if (system("$cmd") != 0 ) {
    install_R() if($network_access);
    $logger->logdie("Cannot install R. Please install R and retry build") if(!$network_access);
}

# Hack...$Config fails. Need a better way to grab default module lib
foreach (@INC) { $perl_path = $_ if($_ =~ m/.*[\\,\/]site_perl[\\,\/]\d[.]\d+[.]\d$/i); }

unless( -e "$perl_path$SS"."TMPL") {
    ($retval, @result, $cmd) = sys_call("mkdir $perl_path$SS"."TMPL");
    $logger->logdie("Failed to create module directory TMPL:\n\tat cmd 'mkdir $perl_path$SS"."TMPL':\n\t $!")
	unless($retval == 0);
}	

$logger->info(MOD);

if($network_access) {

    install_mods(); 

} else {

    $logger->warn(CPAN_WARN);

    $logger->info("Continue with install? (y/n) ");
    $response = <STDIN>;
    $logger->info("Exiting installer...\n") and exit(0) unless (defined $response and $response =~ /^Y.*$/i);

    install_archive();
}

$logger->info(MOD_COMPLETE);
$logger->info(TMPL);

install_tmpl();

$logger->info(TMPL_COMPLETE);
$logger->info("
Install directory:      $path\n
Library name:	   	TMPL\n
TMPL Modules directory: $perl_path\n");


###########################################################################
# End Build.PL								  #
###########################################################################

sub install_R {

    my ( $url, $file );

    eval "use LWP;";
    if ( $@ ) {
	($retval, @result, $cmd) = sys_call($perlbinpath . "cpanp -i LWP");
	$logger->logdie("Failed to install LWP::Simple\n\tSee install.log for details") 
	    unless(system $retval == 0 );
    }

    if($^O eq "MSWin32") {

	$url = "http://cran.r-project.org/bin/windows/base/R-2.15.2-win.exe";
	$file = "R-2.15.2-win.exe";

	($retval, @result, $cmd) = sys_call("lwp-download $url $file");
	$logger->logdie("Failed to download R:\n\tat cmd 'lwp-download $url $file':\n\t $!")
	    unless( $retval == 0 );


	($retval, @result, $cmd) = sys_call("$file /VERYSILENT");
	$logger->logdie("Failed to install R-2.15.2:\n\tat cmd '$file /VERYSILENT'\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("DEL /Q /S /F $file");
	$logger->warn("Failed to cleanup R:\n\tat cmd 'DEL /Q /S /F $file':\n\t $!")
	    unless( $retval == 0 );

	
    } elsif($^O eq "darwin") {

	$url = "http://cran.r-project.org/bin/macosx/R-2.15.2.pkg";
	$file = "R-2.15.2.pkg";

	($retval, @result, $cmd) = sys_call("lwp-download $url $file");
	$logger->logdie("Failed to download R:\n\tat cmd 'lwp-download $url $file':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("installer -pkg $file -target /");
	$logger->logdie("Failed to install R:\n\tat cmd 'installer -pkg $file -target /':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("rm -rf $file");
	$logger->warn("Failed to cleanup R:\n\tat cmd 'rm -rf $file':\n\t $!")
	    unless( $retval == 0 );
	
    } else {

	$url = "http://lib.stat.cmu.edu/R/CRAN/src/base/R-2/R-2.15.2.tar.gz";
	$file = "R-2.15.2.tar.gz";

	($retval, @result, $cmd) = sys_call("lwp-download $url $file");
	$logger->logdie("Failed to download R:\n\tat cmd 'lwp-download $url $file':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("gzip -d $file") unless ( -e "R-2.15.2.tar" );
	$logger->logdie("Failed to uncompress R:\n\tat cmd 'gzip -d $file':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("tar -xvf R-2.15.2.tar") unless ( -e "R-2.15.2" );
	$logger->logdie("Failed to untar R:\n\tat cmd 'tar -xvf R-2.15.2.tar':\n\t $!")
	    unless( $retval == 0 );

    	$cwd = cwd();
    	chdir("R-2.15.2") or $logger->logdie("Failed to change to directory R-2.15.2:\n\tat cmd 'chdir(R-2.15.2)':\n\t $!");

	($retval, @result, $cmd) = sys_call("./configure");
	$logger->logdie("Failed to configure R installation for machine:\n\tat cmd './configure':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("make");
	$logger->logdie("Failed to make R:\n\tat cmd 'make':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("make check");
	$logger->logdie("Failed to check make success for R:\n\tat cmd 'make check':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("make install");
	$logger->logdie("Failed to install R:\n\tat cmd 'make install':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("make dvi");
	$logger->warn("Failed to make R dvi help:\n\tat cmd 'make dvi':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("make info");
	$logger->warn("Failed to make R info:\n\tat cmd 'make info':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("make pdf");
	$logger->warn("Failed to make pdf R:\n\tat cmd 'make pdf':\n\t $!")
	    unless( $retval == 0 );

   	 chdir($cwd) or $logger->logdie("Failed to change back to directory $cwd:\n\tat cmd 'chdir($cwd)':\n\t $!");

	($retval, @result, $cmd) = sys_call("rm -rf R-2.15.2.tar");
	$logger->warn("Failed to cleanup R:\n\tat cmd 'rm -rf R-2.15.2.tar':\n\t $!")
	    unless( $retval == 0 );

	($retval, @result, $cmd) = sys_call("rm -rf R-2.15.2");
	$logger->warn("Failed to cleanup R:\n\tat cmd 'rm -rf R-2.15.2':\n\t $!")
	    unless( $retval == 0 );

    }
}

sub test_connection {

    my $result = 0;
    $p = Net::Ping->new();
    $logger->info("Testing internet connection...");
    $result = 1 if ($p->ping('66.39.54.27'));
    $p->close();
    $result ? $logger->info("Network connection detected"): $logger->info("No network connection detected"); 
    return $result;

}

sub install_mods {

    my ( $dir, $mod_name, $mod_path, $module );
    my ( @contents, @missing ); 

    opendir ( MODULES, 'lib' ) or $logger->logdie("Filed to open directory 'lib': $!");
    @contents = grep !/^([.]{1,2}|.DS_Store|[\.\w*]*)$/, readdir(MODULES) or $logger->logdie("Error reading directory 'lib' content: $!");
    closedir ( MODULES ) or $logger->logdie("Failed to close directory 'lib': $!");   

    foreach $dir ( @contents ) {

        $mod_name = "TMPL::".(split('-', $dir))[1];
        $mod_path = "lib$SS$dir$SS";
	($retval, @result, $cmd) = sys_call($perlbinpath . "perl -M$mod_name -e 1");
	build(dir => $mod_path) unless ( $retval == 0);
    }

    opendir ( APPS, 'TMPL' ) or $logger->logdie("Filed to open directory 'TMPL': $!");
    @contents = grep !/^([.]{1,2}|.DS_Store)$/, readdir(APPS) or $logger->logdie("Error reading directory 'TMPL' content: $!");
    closedir ( APPS ) or $logger->logdie("Failed to close directory 'TMPL': $!");

    foreach $dir ( @contents ) {

	@missing = ();
        $module = "TMPL/$dir$SS$dir.pl";
        ($retval, @result, $cmd) = sys_call($perlbinpath . "perl -c -Mlist_deps $module"); 

        foreach (@result) { 

	    # Encode::ConfigLocal can be broken or missing depending on a corrupted or improper install. We will try to repair it.
	    if($_ eq "Encode::ConfigLocal") { 
		($retval, @result, $cmd) = sys_call("enc2xs -C");
		$logger->logdie("Encode::ConfigLocal was not found on the system. Attempted update failed:\n\tat cmd 'enc2xs -C':\n\t $!")
		    unless ( $retval == 0);
	    }

	    if($_ =~ m/^\w*::\w*$/) { push ( @missing, $_ ) unless(eval("require $_"));}
	}

        foreach $module ( @missing ) {

	    ($retval, @result, $cmd) = sys_call($perlbinpath . "cpanp -i $module");
	    $logger->logdie("Failed to install $module: $!\n\tSee install.log for details") 
	        unless(system $retval == 0 );
        }
    }
}

sub install_archive {

    my ( $cmd, $dir );
    my @contents;

    ($retval, @result, $cmd) = sys_call("unzip archive.zip");

    unless ($retval == 0) {

        $cmd = ($^O eq "MSWin32") ? "WHERE unzip" : "which unzip";
	($retval, @result, $cmd) = sys_call($cmd);
	if ( $result[0] =~ m/.*unzip/ ) {
	    $logger->logdie("Failed to unzip archive:\n\tat cmd 'unzip archive'"); 
	} else {
	    $logger->logdie("Utility 'unzip' not installed:\n\tat cmd $cmd:\n\t $!");
	} 
    }

    opendir ( MODULES, 'archive' ) or $logger->logdie("Filed to open directory 'archive': $!");
    @contents = grep !/^([.]{1,2}|.DS_Store)$/, readdir(MODULES) or $logger->logdie("Error reading directory 'archvie' content: $!");
    closedir ( MODULES ) or $logger->logdie("Failed to close directory 'archive': $!");   

    $logger->info(MOD);

    foreach my $module ( @contents ) {  

	$module = "archive$SS$module";

	($retval, @result, $cmd) = sys_call("unzip $module");
        $logger->logdie("Failed to unzip modules:\n\tat cmd 'unzip $module':\n\t $!") 
	    unless( $retval == 0);

	$module =~ s/".tar"//i;

	if ( $^O eq 'MSWin32' ) {
	    
	    # just move stuff to perl lib
	    move(dir => $module);

        } else {

	    if ( -e "archive/$dir/Makefile.PL" ) {
		unless ( -x "archive/$dir/Makefile.PL" ) {
		    ($retval, @result, $cmd) = sys_call("chmod a+x ./archive/$module/Makefile.PL");
		    $logger->logdie("Command chmod a+x ./archive/$module/Makefile.PL failed: $!") 
			unless( $retval == 0 );
		}

		make(dir => "archive/$module/");

	    } elsif ( -e "archive/$module/Build.PL" ) {
		unless ( -x "archive/$dir/Build.PL" ) {
		    ($retval, @result, $cmd) = sys_call("chmod a+x ./archive/$module/Build.PL");
		    $logger->logdie("Command chmod a+x ./archive/$dir/Build.PL failed: $!") 
			unless( $retval == 0 );
		}

		build(dir => "archive/$module");

	    } else { 
		$logger->logdie("Fatal Error: Makefile.PL or Build.PL doesn't exist in archive$SS$module:\n\tPlease verify module integrity at $module:\n\t $!"); 
	    }
	}
    }

    if ( $^O eq "MSWin32" ) { $cmd = "DEL /Q /S /F archive"; } 
    else { $cmd = "rm -rf archive"; }

    ($retval, @result, $cmd) = sys_call($cmd);
    $logger->warn("Cleanup failed:\n\tat '$cmd:\n\t $!") 
        unless($retval == 0 );
    
}

sub install_tmpl {
    # Why do we need program.xml, it is only used in TMPL.pl, which is junk now ( TBD )
    $perl_path .= $SS unless( $perl_path =~ m/^.*$SS$/i ); 
    my $mv_cmd = ( $^O eq 'MSWin32' ) ? "COPY /Y programs.xml $path" : "cp -f -v programs.xml $path";
    ($retval, @result, $cmd) = sys_call($mv_cmd);
    $logger->warn("Copy failed:\n\tat $perl_path"."programsl\n\tat programs.xml\n\tat cmd $mv_cmd:\n\t$!") 
	unless( $retval == 0 );
	
	# if there is any error while copying TMPL files, clean will remove the already copied content, for fresh start on next try
	# As per Zach, dependencies have their inbuilt clean in case of failure, so they need not to be handled.
    $path .= $SS unless( $path =~ m/^.*$SS$/i ); 
    $mv_cmd = ( $^O eq 'MSWin32' ) ? "COPY /Y TMPL $path" : "cp -f -v -r TMPL $path";
    ($retval, @result, $cmd) = sys_call($mv_cmd);
    if ( $retval != 0 ) 
    { 
    	clean_up("Copy failed:\n\tat $path"."TMPL\n\tat TMPL\n\tat cmd $mv_cmd:\n\t$!"); 
    } 
    
    # Version.XML to be copied for first installation for version control purposes
    $perl_path .= $SS unless( $perl_path =~ m/^.*$SS$/i ); 
    $mv_cmd = ( $^O eq 'MSWin32' ) ? "COPY /Y TMPL/version.xml $path"."TMPL/" : "cp -f -v TMPL/version.xml $path"."TMPL/";
    ($retval, @result, $cmd) = sys_call($mv_cmd);
    $logger->warn("Copy failed:\n\tat $path"."TMPL/"."version.xml\n\tat version.xml\n\tat cmd $mv_cmd:\n\t$!") 
	unless( $retval == 0 );
    
}

sub move {

    my %hash = @_;
    my ( $module, $mod_path, $dir, $file );

    my $input = {
	dir => { required => 1, store => \$dir },
    };

    my $args = check( $input, \%hash, 1 )
	or die "Invalid Arguments:\n\tat move\n\t $!";

    ($retval, @result, $cmd) = sys_call("WHERE /r archive\\$dir\\*.pm");
    $logger->logdie("Could not find .pm file:\n\tat 'WHERE /r archive\\$dir\\*.pm:\n\t\t $!")
	unless( $retval == 0);
    
    $file = $result[0];
    $module =~ s/\w*.pm$//gi;
    $mod_path = "$perl_path$SS$module";

    ($retval, @result, $cmd) = sys_call("MKDIR $mod_path");
    $logger->logdie("Could not create module directory $mod_path:\n\tat cmd MKDIR $mod_path:\n\t $!")
	unless( $retval == 0);

    ($retval, @result, $cmd) = sys_call("MOVE /Y $file $mod_path");
    $logger->logdie("Could not move $file to $mod_path:\n\tat cmd 'MOVE /Y $file $mod_path':\n\t $!")
	unless( $retval == 0);

    ($retval, @result, $cmd) = sys_call("WHERE /r archive\\$dir\\ *.html");
    $logger->logdie("Could not find .html file:\n\tat $module:\n\t\tat cmd 'WHERE /r archive\\$dir\\ *.html:\n\t\t $!")
	unless( $retval == 0);

    $file = @result;

    ($retval, @result, $cmd) = sys_call("MOVE /Y $file $mod_path");
    $logger->logdie("Could not move $file to $perl_path:\n\tat cmd 'MOVE /Y $file $mod_path':\n\t $!")
	unless( $retval == 0);

    ($retval, @result, $cmd) = sys_call("WHERE /r archive\\$dir\\ *.ix");
    if( $retval == 0 ) {
	
	$file = @result;

	($retval, @result, $cmd) = sys_call("MOVE /Y $file $mod_path");
	$logger->logdie("Could not move $file to $mod_path:\n\tat cmd 'MOVE /Y $file $mod_path':\n\t $!")
	    unless( $retval == 0 );

    } else {
       $logger->warn("Could not find .ix file:\n\tat $module:\n\t\tat cmd 'WHERE /r archive\\$dir\\ *.ix:\n\t\t $!\nThis is typical for some modules - Ignoring warning");
    }
}

sub make {

    my %hash = @_;
    my $dir;

    my $input = {
	dir => { required => 1, store => \$dir },
    };

    my $args = check( $input, \%hash, 1 )
	or die "Invalid Arguments:\n\tat make\n\t $!";

    ($retval, @result, $cmd) = sys_call($perlbinpath . "perl $dir/Makefile.PL");
    $logger->logdie("Makefile.PL failed: $dir: $!") 
	unless( $retval == 0 );
    
    ($retval, @result, $cmd) = sys_call("$dir/make");
    $logger->logdie("Make failed: $dir:\n\tat cmd $dir/make:\n\t $!") 
	unless( $retval == 0 );
    
    ($retval, @result, $cmd) = sys_call("$dir/make test");
    $logger->logdie("Test failed: $dir:\n\tat $dir/make test:\n\t $!") 
	unless( $retval == 0 );
    
    ($retval, @result, $cmd) = sys_call("$dir/make install");	
    $logger->logdie("Installation failed: $dir:\n\tat $dir/make install:\n\t $!") 
	unless( $retval == 0 );
    	
}

sub build {

    my %hash = @_;
    my ( $dir, $cwd, $prefix );

    # parse in $dir
    my $input = {
	dir => { required => 1, store => \$dir },
    };

    my $args = check( $input, \%hash, 1 )
	or die "Invalid Arguments:\n\tat make\n\t $!";

    $prefix = ($^O eq "MSWin32") ? "" : "./";

    $cwd = cwd();
    chdir($dir) or $logger->logdie("Failed to change to directory $dir:\n\tat cmd 'chdir($dir)':\n\t $!");
    
    ($retval, @result, $cmd) = sys_call($perlbinpath . "perl Configure.PL");
    $logger->logdie("Module build failed:\n\tat cmd 'perl Configure.PL':\n\tin $dir\n\t $!")
 	unless($retval != 1);
    
    ($retval, @result, $cmd) = sys_call("$prefix"."Build installdeps --cpan_client '" . $perlbinpath . "cpanp -i'");	
    $logger->logdie("./Build failed: $dir:\n\tat cmd '$prefix"."Build manifest installdeps --cpan_client '" . $perlbinpath . "cpanp -i'':\n\t $!") 
	unless( $retval == 0 );
    
    ($retval, @result, $cmd) = sys_call("$prefix"."Build test");	
    $logger->logdie("./Build test failed: $dir:\n\tat cmd '$prefix"."Build test':\n\t $!") 
	unless( $retval == 0 );
    
    ($retval, @result, $cmd) = sys_call("$prefix"."Build install");	
    $logger->logdie("./Build install failed: $dir:\n\tat cmd '$prefix"."Build install':\n\t $!") 
	unless( $retval == 0 );
    
    ($retval, @result, $cmd) = sys_call("rm -rf _build blib Build MYMETA.json MYMETA.yml");
    $logger->warn("Failed to clean up after build:\n\tat cmd 'rm -rf _build blib Build MYMETA.json MYMETA.yml':\n\t $!")
	unless( $retval == 0 );

    chdir($cwd) or $logger->logdie("Failed to change back to directory $cwd:\n\tat cmd 'chdir($cwd)':\n\t $!");
}

sub sys_call {

    my ( $wtr, $rdr, $err, $pid, $retval, @result, $output );
    $pid = open3($wtr, $rdr, $err, $_[0]);

    while($output = <$rdr>) {
	chomp($output);
	$logger->info("$output");
	push(@result, "$output");
    }

    waitpid($pid, 0);
    $retval = $? >> 8;
    push(@result, " ") unless(@result);
    return ($retval, @result, " command: $_[0]: ");
}

sub clean_up {

    my ( $wtr, $rdr, $err, $pid, $retval, @result, $output );
    # hard coded clean up string, function will be updated if we add more directories in installation
    $pid = open3($wtr, $rdr, $err, "rm -rf $path"."TMPL");

    while($output = <$rdr>) {
	chomp($output);
	$logger->info("$output");
    }

    waitpid($pid, 0);
    $retval = $? >> 8;
	$logger->logdie($_[0]) 
}

sub sanity_clean_up {

    my ( $wtr, $rdr, $err, $pid, $retval, @result, $output );
    # hard coded clean up string, function will be updated if we add more directories in installation
    $pid = open3($wtr, $rdr, $err, "rm -rf $path"."TMPL");

    while($output = <$rdr>) {
	chomp($output);
	$logger->info("$output");
    }

    waitpid($pid, 0);
    $retval = $? >> 8;
}

1;
