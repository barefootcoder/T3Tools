#! /usr/bin/perl -w

# For RCS:
# $Date$
#
# $Id$
# $Revision$

use strict;

#use Barefoot::debug(1);						# comment out for production

use CGI;

use Barefoot::base;
use Barefoot::exception;
use Barefoot::DataStore;
use Barefoot::DataStore::display;

$| = 1;


my $cgi = new CGI;
my $basepath = DEBUG ? "/proj/$ENV{REMOTE_USER}/t3/timerweb/reports"
		: "/home/httpd/sybase/timer_reports";
my $lib = "/usr/local/bin/kshlib";
my $dsname = DEBUG ? "t3test" : "T3";
my $debug_string = "" if DEBUG;
debug("first dir is $INC[0]");
debug("procs are " . join(",", keys %$DataStore::procs));

set_environment();
print $cgi->header();

my $ds;
try
{
	$ds = DataStore->open($dsname, $ENV{USER});
}
catch
{
	error("cannot open data store: $dsname\n$_");
	exit;
};

$ds->show_queries() if DEBUG >= 2;

my $file = $ARGV[0] ? $ARGV[0] : $cgi->param("sqlfile");
if ($file)
{
	$file = "$basepath/$file";
	debug("file is $file");

	# get cookie values and make them variables for the data store
	foreach my $name ($cgi->cookie())
	{
		my $value = $cgi->cookie($name);
		$ds->define_var($name, $value) if $value;
	}

	my $title = get_title($file);

	print $cgi->start_html(-title=>$title);
	if ($title)
	{
		print $cgi->center($cgi->h1($title)), "\n";
	}

	print "<PRE>\n\n";
	try
	{
		print DataStore::display($ds, $file);
	}
	catch
	{
		DEBUG ? error("$_\n(file $__FILE__, line $__LINE__)") : error($_);
	};
	print "</PRE>\n\n";
	print "<!-- Debugging String -->\n" if DEBUG;
	print "$debug_string\n" if DEBUG;
	print $cgi->end_html(), "\n";
}
else
{
	error("no report specified");
}

sub set_environment
{
	$ENV{PATH} .= ":/opt/sybase/bin:/usr/local/dbutils:/opt/sybase";
	$ENV{SYBASE} = "/opt/sybase";
	$ENV{USER} = "www" unless $ENV{USER};
	$ENV{HOME} = "/home/$ENV{USER}" unless $ENV{HOME};

=comment
	# get CGI attributes and stick them in the environment too
	foreach my $attr ($cgi->param())
	{
		$ENV{$attr} = $cgi->param($attr);
	}
=cut
}

sub get_title
{
	my ($file) = @_;

	my $title = "";
	open(IN, $file) or (error("can't open report $file"), return "");
	while ( <IN> )
	{
		last if /^$/;			# first blank line marks end of header
		$title = $1 if /^#\s*TITLE:\s*(.*)$/;
	}
	close(IN);

	return $title;
}

=comment
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
			$reset_title = 1;
			next LINE;
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
=cut

sub error
{
	my ($msg) = @_;

	$msg =~ s/\n/<BR>\n/g;
	print $cgi->h1("ERROR"), "\n";
	print "<P>", $cgi->strong("Your request has the following error!");
	print "<BR>\n", "$msg</P>\n\n";
	# print $debug_string if DEBUG;
}

sub debug
{
	if (DEBUG)
	{
		my ($msg) = @_;

		$msg =~ s/\n/<BR>/g;
		$debug_string .= "<P>$msg</P>\n";
	}
}
