#! /usr/bin/perl

use CGI;
use Barefoot::string;

use constant DEBUG => 0;

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
						options	=>	'upper',
						size	=>	3,
						admin	=>	0,
					},
	invoice		=>	{
						sort	=>	6,
						value	=>	"",
						size	=>	7,
						admin	=>	0,
					},
	check_date	=>	{
						sort	=>	7,
						value	=>	"",
						size	=>	10,
						admin	=>	0,
					},
	inv_paydate	=>	{
						sort	=>	8,
						value	=>	"",
						size	=>	10,
						admin	=>	1,
					},
};
@admin_users = ('christy', 'buddy');

my $debug_user;
($debug_user) = $ENV{SCRIPT_FILENAME} =~ m@/([^/]*?)test/@ if DEBUG;

$title = 'TIMER Reports';
$scripturlpath = "/cgi-bin/timer/scripts";
$scriptpath = "/home/httpd$scripturlpath"; 
$basepath = DEBUG ? "/proj/$debug_user/t3/timerweb/reports"
		: "/home/httpd/sybase/timer_reports";

							debug("env has cookies $ENV{HTTP_COOKIE}");


if ($cgi->param('Clear Variables'))
{
	foreach $var (keys %$vars)
	{
		$cgi->param($var,"");
	}
}
							
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
my $admin = is_admin_user();

debug($cgi->a({-href=>"test.cgi"}, "test"));

# Read Report Directory
for $file ( < $basepath/* > )
{
	$basefile = $file;
	$basefile =~ s?^$basepath/??;
	my ($group, $alt_params);

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
			my $report = {};
			$report->{file} = $basefile;
			$report->{title} = $1;
			$report->{params} = $alt_params;
			push @{$report_groups{$group}}, $report;
		}

		if ( /--\s*ALSO RUN WITH:\s*(.*)\s*/ )
		{
			$alt_params = $1;
										debug("alt report for $file");
		}
	}
}


# Read Script Directory
for $file ( < $scriptpath/* > )
{
	$basefile = $file;
	$basefile =~ s?^$scriptpath/??;
	my ($group, $alt_params);

	open(FILE, $file) or next;
	while ( <FILE> )
	{
		if ( /#\s*SORT GROUP:\s*(.*)\s*/ )
		{
			$group = $1;
			if (not exists $report_groups{$group})
			{
				$report_groups{$group} = ();
			}
		}

		if ( /#\s*TITLE:\s*(.*)\s*/ )
		{
										debug("report is $1");
			my $report = {};
			$report->{file} = $basefile;
			$report->{title} = $1;
			$report->{params} = "script";
			push @{$report_groups{$group}}, $report;
		}

	}
}

print "<multicol cols=3>\n";
foreach my $group (keys %report_groups)
{
	next if ($group eq "Administrative Updates"
			and not is_admin_user());
	print "<P>", $cgi->h3($group);
	foreach my $report (sort {$a->{title} cmp $b->{title}}
			@{$report_groups{$group}})
	{
		if ($report->{params} eq "script")
		{
			print $cgi->a({-href=>"$scripturlpath/$report->{file}?
					admin=$admin"}, $report->{title}), "<BR>\n";
		} elsif ($report->{params})
		{
			print $cgi->a({-href=>"sqlcgi.pl?sqlfile=$report->{file}&"
					. "$report->{params}"}, $report->{title}), "<BR>\n";
		}
		else
		{
			print $cgi->a({-href=>"sqlcgi.pl?$report->{file}"},
					$report->{title}), "<BR>\n";
		}
	}
}
print "</multicol>\n";

print $debug_string if DEBUG;
print $cgi->end_html();

sub param_to_cookie
{
	my ($name) = @_;

	$value = $cgi->param($name);
	$value = string::upper($value)
			if exists $vars->{$name}->{options}
			and $vars->{$name}->{options} =~ /(^|,)upper(,|$)/;
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

	foreach $var (
			sort {$vars->{$a}->{sort} <=> $vars->{$b}->{sort}} keys %$vars
		)
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
	print "\n    ", $cgi->submit('Clear Variables');

	print "</P>\n";
	print $cgi->endform(), "\n";
}

sub html_spaces
{
	my ($how_many) = @_;

	print "&nbsp;" x $how_many;
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
