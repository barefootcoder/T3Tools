#! /usr/bin/perl

use strict;

use CGI;
$| = 1;

use constant DEBUG => 0;

my $debug_user;
($debug_user) = $ENV{SCRIPT_FILENAME} =~ m@/([^/]*?)test/@ if DEBUG;

my $cgi = new CGI;
my $script = "/tmp/sqlcgi$$.ksh";
my $basepath = DEBUG ? "/export/usr/$debug_user/proj/t3/timerweb/reports/"
		: "/home/httpd/sybase/timer_reports/";
my $lib = "/usr/local/bin/kshlib";
my $db = DEBUG ? "timertest" : "timer";
my $title = "";
my $debug_string = "";

set_environment();
print $cgi->header();

my $file = $ARGV[0] ? $ARGV[0] : $cgi->param("sqlfile");
if ($file)
{
	$file=$basepath . $file;
	debug("file is $file");

	if (create_script($file, $script))
	{
		print $cgi->start_html(-title=>$title);
		if ($title)
		{
			print $cgi->center($cgi->h1($title)), "\n";
		}

		print "<PRE>\n";
		print STDERR "going to run script\n";
		system ("ksh", "-c", $script) == 0 or die "system \@args failed: $?";
		print STDERR "ran script\n";
		print "</PRE>\n";
		print $debug_string if DEBUG;
		print $cgi->end_html();
	}

	unlink $script unless DEBUG;
}
else
{
	error("no report specified");
}

sub set_environment
{
	$ENV{PATH} .= ":/opt/sybase/bin:/usr/local/sybutils:/opt/sybase:.";
	$ENV{SYBASE} = "/opt/sybase";
	$ENV{HOME} = "/home/www" if !$ENV{HOME};

	# get cookie values and stick them in the environment
	my @cookies = $cgi->cookie();
	foreach my $name (@cookies)
	{
		my $value = $cgi->cookie($name);
		$ENV{$name} = $value;
	}

	# get CGI attributes and stick them in the environment too
	my @attribs = $cgi->param();
	foreach my $attr (@attribs)
	{
		my $value = $cgi->param($attr);
		$ENV{$attr} = $value;
	}
}

sub create_script
{
	my ($file, $script) = @_;

	open(FILE, $file) or die("can't get file $file");
	open(SCRIPT, ">$script") or die("can't make script");

	print SCRIPT <<END;
#! /bin/ksh

. $lib

run_query -Uguest -SSYBASE_1 <<-SCRIPT_END | remove_sp_returns

	use $db
	go

END

	my $reset_title = 1;
	LINE: while ( <FILE> )
	{
		if ( /--\s*TITLE:\s*(.*)\s*/ )
		{
			$title = $1 and $reset_title = 0 if $reset_title;
			next LINE;
		}
		if ( /--\s*ALSO RUN WITH:\s*(.*)\s*/ )
		{
			my @params = split(/&/, $1);
			foreach my $param (@params)
			{
				my ($name, $val) = $param =~ /(.*)=(.*)/;
				debug("checking to see if $name = $val");
				next LINE if $cgi->param($name) ne $val;
			}
			$reset_title = 1 and next LINE;
		}

		# check for "only if this var is set" lines
		# format: any line containing a token like this:
		#		{?var}					(depracated form: ??var)
		# will be removed unless "var" is set; if "var" _is_ set, the
		# "conditional" token is removed and the line is processed normally
		while (s/{\?(\w+)}// or s/\?\?(\w+)//)
		{
								debug("got conditional $1");
			next LINE unless defined $ENV{$1};
								debug("will process this line");
		}
		# check for "only if this var is _not_ set" lines
		# format: any line containing a token like this:
		#		{!var}					(depracated form:: ?!var)
		# will be removed if "var" is set; if "var" is _not_ set, the
		# conditional token is removed and the line is processed normally
		while (s/{!(\w+)}// or s/\?!(\w+)//)
		{
								debug("got not conditional $1");
			next LINE if defined $ENV{$1};
								debug("will process this line");
		}
		# check for var substitutions
		# format: any token like this:
		#		{var}					(depracated form: [var])
		# will be replaced with the value of "var"; there can be any number
		# of these "substitution" tokens on a given line; it is an error
		# if "var" is not defined (but see conditional tokens, above)
		while (/{(.*?)}/ or /\[(.*?)\]/)
		{
								debug("substituting var $1");
			my $var = $1;
			if (!$ENV{$var})
			{
				error("$var variable not set");
				return 0;
			}
								debug("before substitution: $_");
			s/\Q$&\E/$ENV{$var}/;
								debug("after substitution: $_");
		}
		print SCRIPT;
	}

	print SCRIPT "\nSCRIPT_END\n";

	close(FILE);
	close(SCRIPT);
	chmod 0777, $script;
	return 1;
}

sub error
{
	my ($msg) = @_;

	$msg =~ s/\n/<BR>/g;
	print $cgi->h1("ERROR"), "\n";
	print "<P>", $cgi->strong("Your request has the following error!");
	print "<BR>\n", "$msg</P>\n";
	print $debug_string if DEBUG;
}

sub debug
{
	my ($msg) = @_;

	$msg =~ s/\n/<BR>/g;
	$debug_string .= "<P>$msg</P>\n";
}
