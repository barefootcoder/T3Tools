#! /usr/bin/perl

# $Header$
# $Log$
# Revision 1.6  1999/05/27 20:41:20  buddy
# added proj to variables
# set sort order for variables
# added check for certain variables if not admin user
#
# Revision 1.5  1999/05/26 19:09:02  buddy
# added check_date variable to allow marking payrolls as done
#
# Revision 1.4  1999/05/13 14:35:43  buddy
# divided reports into groups
# sorted reports within groups
# made special group (Administrative Updates) only accessible by certain users
#     (list is currently hard-coded)
# added invoice num to variables
# added size to variable so all fields aren't the same (huge) width
#
# Revision 1.3  1999/02/18 06:11:19  buddy
# now calls correct version of sqlcgi.pl
#
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
	start_date	=>	{
						sort	=>	1,
						value	=>	"",
						size	=>	10,
						admin	=>	0,
					},
	end_date	=>	{
						sort	=>	2,
						value	=>	"",
						size	=>	10,
						admin	=>	0,
					},
	user		=>	{
						sort	=>	3,
						value	=>	"",
						size	=>	30,
						admin	=>	0,
					},
	client		=>	{
						sort	=>	4,
						value	=>	"",
						size	=>	3,
						admin	=>	0,
					},
	proj		=>	{
						sort	=>	5,
						value	=>	"",
						size	=>	3,
						admin	=>	0,
					},
	invoice		=>	{
						sort	=>	6,
						value	=>	"",
						size	=>	7,
						admin	=>	1,
					},
	check_date	=>	{
						sort	=>	7,
						value	=>	"",
						size	=>	10,
						admin	=>	1,
					},
	inv_paydate	=>	{
						sort	=>	8,
						value	=>	"",
						size	=>	10,
						admin	=>	1,
					},
};
@admin_users = ('tweber', 'christy', 'buddy');

$title = 'TIMER Reports';
$basepath = "/home/httpd/sybase/timer_reports";

							debug("env has cookies $ENV{HTTP_COOKIE}");
foreach $var (keys %$vars)
{
	$vars->{$var}->{value} = $cgi->cookie($var);
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

my %report_groups;

debug($cgi->a({-href=>"test.cgi"}, "test"));
for $file ( < $basepath/* > )
{
	$basefile = $file;
	$basefile =~ s?^$basepath/??;
	my ($group);

	open(FILE, $file) or next;
	while ( <FILE> )
	{

		if ( /--\s*SORT GROUP:\s*(.*)\s*/ )
		{
			$group = $1;
			if (not exists $report_groups{$group})
			{
				$report_groups{$group} = ();
			}
		}

		if ( /--\s*TITLE:\s*(.*)\s*/ )
		{
										debug("report is $1");
			#print $cgi->a({-href=>"sqlcgi.pl?$basefile"}, $1), "<BR>\n";
			my $report = {};
			$report->{file} = $basefile;
			$report->{title} = $1;
			push @{$report_groups{$group}}, $report;
			last;
		}
	}
}

print "<multicol cols=2>\n";
foreach my $group (keys %report_groups)
{
	next if ($group eq "Administrative Updates"
			and not is_admin_user());
	print "<P>", $cgi->h3($group);
	foreach my $report (sort {$a->{title} cmp $b->{title}}
			@{$report_groups{$group}})
	{
		print $cgi->a({-href=>"sqlcgi.pl?$report->{file}"},
				$report->{title}), "<BR>\n";
	}
}
print "</multicol>\n";

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
		$vars->{$name}->{value} = $value;
	}
}

sub text_form
{
	print $cgi->startform(), "<P>\n";
	foreach $var (sort {$vars->{$a} <=> $vars->{$b}} keys %$vars)
	{
		next if $vars->{$var}->{admin} and not is_admin_user();
		$name = $var;
		$size = $vars->{$var}->{size};
		print "<NOBR>$name:";
		html_spaces(2);
		print $cgi->textfield(
				-name=>$var,
				-default=>$vars->{$var}->{value},
				-size=>$size,
				-maxlength=>$size
		);
		html_spaces(5);
		print "</NOBR>\n";
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

sub is_admin_user
{
	return grep { $_ eq $ENV{REMOTE_USER} } @admin_users;
}

sub debug
{
	my ($msg) = @_;

	$msg =~ s/\n/<BR>/g;
	$debug_string .= "<P>$msg</P>\n";
}
