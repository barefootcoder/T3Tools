#! /usr/bin/perl

# $Header$
# $Log$
# Revision 1.1  1998/12/30 06:24:55  buddy
# Initial revision
#

use CGI;
$| = 1;

$cgi = new CGI;
$script = "/tmp/sqlcgi$$.ksh";
$basepath = "/usr/local/WWW/apache1.2/sybase/timer_reports/";
$title = "";

print $cgi->header();
set_environment();

if ($ARGV[0])
{
	$file=$basepath . $ARGV[0];

	if (create_script($file, $script))
	{
		if ($title)
		{
			print $cgi->center($cgi->h1($title)), "\n";
		}

		print "<PRE>\n";
		system ("ksh", "-c", $script) == 0 or die "system \@args failed: $?";
		print "</PRE>\n";
	}

	unlink $script;
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
	@cookies = $cgi->cookie();
	foreach $name (@cookies)
	{
		$value = $cgi->cookie($name);
		# print "setting environment value for $name to $value<BR>\n";
		$ENV{$name} = $value;
	}
}

sub create_script
{
	open(FILE, $file) or die("can't get file");
	open(SCRIPT, ">$script") or die("can't make script");

	print SCRIPT <<END;
#! /bin/ksh

. /usr/local/bin/kshlib

run_query -Uguest -SSYBASE_1 <<-SCRIPT_END

END

	while ( <FILE> )
	{
		if ( /--\s*TITLE:\s*(.*)\s*/ )
		{
			$title = $1;
		}
		while (/\[(.*?)\]/)
		{
			$var = uc($1);
			if (!$ENV{$var})
			{
				error("$var variable not set");
				return 0;
			}
			s/\[.*?\]/\${$var}/;
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
}
