#! /usr/bin/perl

# $Header$
# $Log$
# Revision 1.2  1999/02/18 05:59:44  buddy
# generalized vars into a hash
# consolidated text inputs into one form
# fixed web base path
#
# Revision 1.1  1998/12/31 20:02:13  buddy
# Initial revision
#
# Revision 1.1  1998/12/31 20:00:43  buddy
# Initial revision
#

use CGI;

$cgi = new CGI;
$cookie_array = [];
$debug_string = "";
$vars = {
	user		=>	"",
	client		=>	"",
	start_date	=>	"",
	end_date	=>	"",
};

$title = 'TIMER Reports';
$basepath = "/home/httpd/sybase/timer_reports";

							debug("env has cookies $ENV{HTTP_COOKIE}");
foreach $var (keys %$vars)
{
	$vars->{$var} = $cgi->cookie($var);
							debug("$var is $var->{$var} from cookie");
}

if ($cgi->request_method() eq 'POST')
{
	foreach $var (keys %$vars)
	{
		param_to_cookie($var);
	}
}
			debug("cookie array has " . scalar(@$cookie_array) . " elements");

print $cgi->header(-cookie=>$cookie_array);
print $cgi->start_html($title);
print $cgi->center($cgi->h1($title)), "\n";
text_form();
print "<HR>\n";

debug($cgi->a({-href=>"test.cgi"}, "test"));
for $file ( < $basepath/* > )
{
	$basefile = $file;
	$basefile =~ s?^$basepath/??;

	open(FILE, $file) or next;
	while ( <FILE> )
	{
		if ( /--\s*TITLE:\s*(.*)\s*/ )
		{
										debug("report is $1");
			print $cgi->a({-href=>"sqlcgi.pl?$basefile"}, $1),
					"<BR>\n";
			last;
		}
	}
}

# print $debug_string;
print $cgi->end_html();

sub param_to_cookie
{
	my ($name) = @_;

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
		$vars->{$name} = $value;
	}
}

sub text_form
{
	print $cgi->startform(), "<P>\n";
	foreach $var (keys %$vars)
	{
		$name = $var;
		$size = 30;
		print "$name:";
		html_spaces(2);
		print $cgi->textfield(
				-name=>$var,
				-default=>$vars->{$var},
				-size=>$size,
				-maxlength=>$size
		);
		html_spaces(5);
		print "\n";
	}
	print "\n<BR>", $cgi->submit('Set Variables');
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
