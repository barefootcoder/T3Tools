#! /usr/bin/perl

# $Header$
# $Log$
# Revision 1.5  1999/06/03 16:13:09  buddy
# added "not" conditional tags (?!)
#
# Revision 1.4  1999/05/27 20:44:55  buddy
# added check for conditional tokens
# added some comments
#
# Revision 1.3  1999/02/18 06:28:55  buddy
# changed web base path
# synced to work with new showreports.pl
#
# Revision 1.2  1999/02/18 06:16:52  buddy
# changed to handle cookies turned into environment variables
# now builds ksh script so can use kshlib functions as well
#
# Revision 1.1  1998/12/30 06:24:55  buddy
# Initial revision
#

use CGI;
$| = 1;

$cgi = new CGI;
$script = "/tmp/sqlcgi$$.ksh";
$basepath = "/home/httpd/sybase/timer_reports/";
$title = "";
$debug_string = "";

set_environment();
print $cgi->header();

if ($ARGV[0])
{
	$file=$basepath . $ARGV[0];

	if (create_script($file, $script))
	{
		print $cgi->start_html(-title=>$title);
		if ($title)
		{
			print $cgi->center($cgi->h1($title)), "\n";
		}

		print "<PRE>\n";
		system ("ksh", "-c", $script) == 0 or die "system \@args failed: $?";
		print "</PRE>\n";
		# print $debug_string;
		print $cgi->end_html();
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

run_query -Uguest -SSYBASE_1 <<-SCRIPT_END | remove_sp_returns

END

	while ( <FILE> )
	{
		if ( /--\s*TITLE:\s*(.*)\s*/ )
		{
			$title = $1;
		}
		# check for "only if this var is set" lines
		# format: any line containing a token like this:
		#		??var
		# will be removed unless "var" is set; if "var" _is_ set, the
		# "conditional" token is removed and the line is processed normally
		if (s/\?\?(\w+)//)
		{
								debug("got conditional $1");
			next unless defined $ENV{$1};
								debug("will process this line");
		}
		# check for "only if this var is _not_ set" lines
		# format: any line containing a token like this:
		#		?!var
		# will be removed if "var" is set; if "var" is _not_ set, the
		# conditional token is removed and the line is processed normally
		if (s/\?!(\w+)//)
		{
								debug("got not conditional $1");
			next if defined $ENV{$1};
								debug("will process this line");
		}
		# check for var substitutions
		# format: any token like this:
		#		[var]
		# will be replaced with the value of "var"; there can be any number
		# of these "substitution" tokens on a given line; it is an error
		# if "var" is not defined (but see conditional tokens, above)
		while (/\[(.*?)\]/)
		{
			$var = $1;
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

sub debug
{
	my ($msg) = @_;

	$msg =~ s/\n/<BR>/g;
	$debug_string .= "<P>$msg</P>\n";
}
