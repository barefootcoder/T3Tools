#! /usr/bin/perl -w

use strict;

#use Barefoot::debug;						# comment out for production

use CGI;

use Barefoot::base;
use Barefoot::string;

use Barefoot::T3::base;


my $cgi = new CGI;
my $cookie_array = [];
my $debug_string = "" if DEBUG;
my $vars = {
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
my @admin_users = ('christy', 'buddy');

my $title = 'TIMER Reports';
my $scripturlpath = "/cgi-bin/timer/scripts";
my $scriptpath = "/home/httpd" . $scripturlpath; 
my $basepath = DEBUG ? "/proj/$ENV{REMOTE_USER}/t3/timerweb/reports"
		: T3::config(T3::WREPORTDIR_DIRECTIVE);

							debug("env has cookies $ENV{HTTP_COOKIE}");


my $var;
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
linkjava();
print $cgi->center($cgi->h1($title)), "\n";
text_form();
print "<HR>\n";

my %report_groups;
my $admin = is_admin_user();
my $file;

debug($cgi->a({-href=>"test.cgi"}, "test"));

processdir("reprt");
processdir("script");

print "<multicol cols=3>\n";
foreach my $group (keys %report_groups)
{
	next if ($group eq "Administrative Updates"
			and not is_admin_user());
	print "<P>", $cgi->h3($group), "\n";
	foreach my $report (sort {$a->{title} cmp $b->{title}}
			@{$report_groups{$group}})
	{
		# Needed to skip blank entries 
		next if $report->{title} eq "";
		my @variables = $report->{vars};
		if ($report->{params} eq "script")
		{
			print $cgi->a(
					{
						-href => "$scripturlpath/$report->{file}?"
								   . "admin=$admin",
						-onMouseover => "showtip(this,event,'$report->{vars}')",
						-onMouseout => "hidetip()"
					},
					$report->{title} . " [NOT YET UPDATED]"
			), $cgi->br;
		} 
		elsif ($report->{params})
		{
			print $cgi->a(
					{
						-href => "sqlcgi.pl?sqlfile=$report->{file}&"
								. "$report->{params}",
						-onMouseover => "showtip(this,event,'$report->{vars}')",
						-onMouseout => "hidetip()",
					},
					$report->{title}
							. ($report->{updated} ? "" : " [NOT YET UPDATED]")
			), $cgi->br;  
		}
		else
		{
			print $cgi->a(
					{
						-href => "sqlcgi.pl?$report->{file}",
						-onMouseover => "showtip(this,event,'$report->{vars}')",
						-onMouseout => "hidetip()"
					},
					$report->{title}
							. ($report->{updated} ? "" : " [NOT YET UPDATED]")
			),  $cgi->br; 
		}
		print "\n";
	}
}
print "</multicol>\n";

print $debug_string if DEBUG;
print $cgi->end_html();


###########################
# SUBROUTINES
###########################


sub param_to_cookie
{
	my ($name) = @_;
	my $value;

	$value = $cgi->param($name);
	$value = uc($value) if exists $vars->{$name}->{options} and $vars->{$name}->{options} =~ /(^|,)upper(,|$)/;
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
	my ($name, $size);

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
	if (DEBUG)
	{
		my ($msg) = @_;

		$msg =~ s/\n/<BR>/g;
		$debug_string .= "<P>$msg</P>\n";
	}
}


sub linkjava
{
	print <<END;

		<script>
			if (!document.layers && !document.all)
				event='test';

			function showtip (current,e,text)
			{
				if (document.all)
				{
					thetitle=text.split('<br>');
					if (thetitle.length>1)
					{
						thetitles='';
						for (i=0;i<thetitle.length;i++)
						thetitles+=thetitle[i];
						current.title=thetitles
					}
					else 
						current.title=text
				}
				else if (document.layers)
				{
					document.tooltip.document.write(
							'<layer bgColor="white" '
							+ 'style="border:1px solid black;font-size:12px">'
							+ text + '</layer>'
					);
					document.tooltip.document.close();
					document.tooltip.left=e.pageX+5;
					document.tooltip.top=e.pageY+5;
					document.tooltip.visibility='show'
				}
			}

			function hidetip ()
			{
				if (document.layers)
					document.tooltip.visibility='hidden'
			}

		</script>
		<div id='tooltip' style='position:absolute;visibility:hidden'></div>

END
}


sub processdir
{
	my ($dirtype) = @_;
	my ($path, $searchopt, $searchreq);

	if ($dirtype eq "reprt")
	{
		$path = $basepath;
	}
	else
	{
		$path = $scriptpath; 
	}

	for $file ( glob("$path/*") )
	{
		my ($group, $updated, $alt_params, $variables, $title);
		my ($required, $optional, $basefile);
		my (%parameters, %tparam, %tgroup);

		$basefile = $file;
		$basefile =~ s@^$path/@@;

		open(FILE, $file) or next;
		while ( <FILE> )
		{
			if ( /(--)\s*SORT GROUP:\s*(.*)\s*/
					or /(\#)\s*SORT GROUP:\s*(.*)\s*/)
			{
				$updated = $1 eq '#';
				$group = $2;
				if (not exists $report_groups{$group})
				{
					$report_groups{$group} = [];
				}
			}

			if ( /--\s*TITLE:\s*(.*)\s*/ or /\#\s*TITLE:\s*(.*)\s*/)
			{
											debug("report is $1");
				$title = $1;
				$tgroup{$title} = $group;
				$tparam{$title} = $alt_params;
			}

			if ( /--\s*ALSO RUN WITH:\s*(.*)\s*/ or 
				/\#\s*ALSO RUN WITH:\s*(.*)\s*/)
			{
				$alt_params = $1;
											debug("alt report for $file");
			}

			# places variable in hash with an O if it's optional
			# Even if the variable is in the hash, it will assigned O
			while (s/{\?(\w+)}// or s/\?\?(\w+)// or s/{\!(\w+)}// or
					s/\#\?(\w+)\s*// or s/\#\!(\w+)\s*//)
			{
				my $key = $1;
				$parameters{$key} = "O" if ($key !~ /[A-Z]/);
			}
			
			# if variable doesn't exist in the hash it sets it to "R"
			if ($dirtype eq "reprt")
			{
				while (s/{(.*?)}// or s/\[(.*?)\]//)
				{
					my $key = $1;
					if ($key !~ /[A-Z]/)
					{
						$parameters{$key} = "R" unless 
							exists($parameters{$key});
					}
				}
			}
			else
			{
				while (s/$cgi->cookie\(\'(.*?)\'//)
				{
					my $key = $1;
					if ($key !~ /[A-Z]/)
					{
						$parameters{$key} = "R" unless
							exists($parameters{$key});
					}
				}
			}
		}	

		my $key;
		foreach $key (keys (%parameters))
		{
			if ($parameters{$key} eq "R")
			{
				if ($required)
				{
					$required = $required . ", " . $key;
				}
				else
				{
					$required = $required . $key;
				}
			}
			else
			{
				if ($optional)
				{
					$optional = $optional . ", " . $key;
				}
				else
				{
					$optional = $optional . $key;
				}
			}
		}

		
		$variables = "REQ: " . $required if $required;
		$variables = $variables . " <br>" if $variables;
		$variables = $variables . "OPT: " . $optional if $optional;
		$variables = "No Variables Required" unless $variables;
		

		foreach my $title (keys (%tgroup))
		{
			my $report = {};
			$report->{file} = $basefile;
			$report->{title} = $title;
			$report->{updated} = $updated;
			$report->{params} = $dirtype eq "reprt"
					? $tparam{$title} : "script";
			$report->{vars} = $variables;
			push @{$report_groups{$tgroup{$title}}}, $report;
		}
	}
}
