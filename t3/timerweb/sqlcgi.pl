#! /usr/bin/perl

# $Header$
# $Log$

use Env;
$| = 1;
if ($ARGV[0])
{
	$basepath = "/usr/local/WWW/apache1.2/sybase/timer_reports/";
	$file=$basepath . $ARGV[0];

	open(FILE, $file) or die("can't get file");
	while ( <FILE> )
	{
		if ( /--\s*TITLE:\s*(.*)\s*/ )
		{
			$title = $1;
			last;
		}
	}
	close(FILE);
}

print "Content-type: text/html\n\n";
if ($title)
{
	print "<CENTER><H1>$title</H1></CENTER>\n";
}
print "<PRE>";
$ENV{PATH} .= ":/opt/sybase/bin:/usr/local/sybutils:/opt/sybase:.";
$ENV{SYBASE} = "/opt/sybase";
$ENV{HOME} = "/home/www" if !$ENV{HOME};
@runq = ("run_query", "-Uguest", "-SSYBASE_1", "-f $file");
system (@runq) == 0 or die "system \@args failed: $?";
print "</PRE>";

