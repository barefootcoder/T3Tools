#! /usr/bin/perl

# $Header$
# $Log$
# Revision 1.1  1998/12/31 20:00:43  buddy
# Initial revision
#

use CGI;

$cgi = new CGI;
$cookie_array = [];
$debug_string = "";

							debug("env has cookies $ENV{HTTP_COOKIE}");
$user = $cgi->cookie('USER');
							debug("user is $user from cookie");
$start_date = $cgi->cookie('START_DATE');
							debug("start_date is $start_date from cookie");
$end_date = $cgi->cookie('END_DATE');
							debug("end_date is $end_date from cookie");

if ($cgi->request_method() eq 'POST')
{
	param_to_cookie('USER', \$user);
	param_to_cookie('START_DATE', \$start_date);
	param_to_cookie('END_DATE', \$end_date);
}
			debug("cookie array has " . scalar(@$cookie_array) . " elements");

$title = 'TIMER Reports';
$basepath = "/usr/local/WWW/apache1.2/sybase/timer_reports/";

print $cgi->header(-cookie=>$cookie_array);
print $cgi->start_html($title);
print $cgi->center($cgi->h1($title)), "\n";
text_form('User', 20, $user);
text_form('Start Date', 20, $start_date);
text_form('End Date', 20, $end_date);
print "<HR>\n";

for $file ( < $basepath/* > )
{
	$basefile = $file;
	$basefile =~ s?^$basepath/??;

	open(FILE, $file) or next;
	while ( <FILE> )
	{
		if ( /--\s*TITLE:\s*(.*)\s*/ )
		{
			print $cgi->a({-href=>"/cgi-bin/sqlcgi.pl?$basefile"}, $1),
					"<BR>\n";
			last;
		}
	}
}

# print $debug_string;
print $cgi->end_html();

sub param_to_cookie
{
	my ($name, $var_to_set) = @_;

	$value = $cgi->param($name);
	if (defined $value)
	{
										debug("making cookie for $name");
		push @$cookie_array, $cgi->cookie(
				-name=>$name,
				-value=>$value,
				-path=>"/cgi-bin/",
				-domain=>".barefoot.net",
			);
		$$var_to_set = $value;
	}
	return $value;
}

sub text_form
{
	my ($name, $size, $value) = @_;

	print $cgi->startform();
	print "<P>$name:";
	html_spaces(2);
	$name =~ s/ /_/g;
	$name = uc($name);
	print $cgi->textfield(
			-name=>$name,
			-default=>$value,
			-size=>$size,
			-maxlength=>$size
	);
	html_spaces(5);
	print "\n", $cgi->submit('Set');
	print "</P>\n";
	print $cgi->endform(), "\n";
}

sub html_spaces
{
	my ($how_many) = @_;

	for (1..$how_many)
	{
		print "&nbsp;";
	}
}

sub debug
{
	my ($msg) = @_;

	$msg =~ s/\n/<BR>/g;
	$debug_string .= "<P>$msg</P>\n";
}
