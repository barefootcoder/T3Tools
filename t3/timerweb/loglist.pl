#! /usr/bin/perl

# SORT GROUP: Employee Reports
# TITLE: Modify Time Log Comments


use strict;

use CGI;
use Barefoot::timerdata;

use constant BREAK => "<BR>\n";
use constant LOGID => 15125;
use constant DEBUG => 0;

my $urlpath = DEBUG ? "http://www.barefoot.net/cgi-bin/$ENV{REMOTE_USER}test/timer" 
	: "http://www.barefoot.net/cgi-bin/timer";

		
my $cgi = new CGI;

#hack alert -- fix this better later
$::ENV{PATH} .= ":/opt/sybase/bin:/usr/local/sybutils";
$::ENV{HOME} = "/home/www";
$::ENV{SYBASE} = "/opt/sybase";


# Read Cookies
my @cookies = $cgi->cookie();
foreach my $name (@cookies)
{
   my $value = $cgi->cookie($name);
   $ENV{$name} = $value;
}

# Set up variables
my $user = $cgi->param('admin') ? $ENV{user}:$ENV{REMOTE_USER};
if (not $user)
{
	$user = $ENV{REMOTE_USER};
}
my $emp_id = timerdata::emp_number($user);
my $start_date = $ENV{start_date};
my $end_date = $ENV{end_date};
my $client = $ENV{client};
my $proj = $ENV{proj};


# Main Section
timerdata::set_connection("SYBASE_1","timertest");

checkchange();
print_header();
print_form();
print_footer();




## Begin subroutines


sub checkchange
{
    if ($cgi->param('Back to Reports'))
    {
        my $link = "$urlpath/showreports.pl";
        print $cgi->redirect(-url=>"$link");
    }
}




sub print_header
{
	my $dateline;
	my $clientline;
	my $projline;

	# Sets up header lines
	if ($start_date)
	{
		$dateline = $dateline . "from $start_date";
	}
	if ($end_date)
	{
		$dateline = $dateline . " to $end_date";
	}
	if ($client)
	{
		my $cl = timerdata::client_name($client); 
		$clientline = $clientline .  "for client $cl";
	}
	if ($proj)
	{
		my $pr = timerdata::proj_name($client,$proj); 
		$projline = $projline .  "on Project $pr";
	}

	# Start header
	print $cgi->header();
    print $cgi->start_html(-title=>"List of comments"), "\n";
    print $cgi->center($cgi->h1("List of Log Comments for $user")), "\n";
    print $cgi->center($cgi->h2("$dateline")), "\n";
    print $cgi->center($cgi->h2("$clientline")), "\n";
    print $cgi->center($cgi->h2("$projline")), "\n";
}


sub print_form
{
	my $comments;
	my $i = 0;
	
	# Debug Section
	#print "user=$user<BR>";
	#print "emp_id=$emp_id<BR>";
	#print "start_date=$start_date<BR>";
	#print "end_date=$end_date<BR>";
	#print "client=$client<BR>";
	#print "proj=$proj<BR>";


	$comments = timerdata::query_results(create_query()); 
	my $t= @$comments;

	print $cgi->startform();
	print "<CENTER>",$cgi->submit('Back to Reports'),"</CENTER>";
	print $cgi->endform();
	print "<TABLE ALIGN=CENTER BORDER=1 WIDTH=100%>";
	print "<TR><TH>Log_Id</TH><TH>Date</TH><TH>Client</TH>
			<TH>Proj</TH><TH>Phase</TH><TH>Comments</TH></TR>";
	while ($i<=$t)
	{
	  my $log_id = $comments->[$i]->[0]; 
	  my $date = $comments->[$i]->[1]; 
	  my $client = $comments->[$i]->[2]; 
	  my $proj = $comments->[$i]->[3]; 
	  my $phase = $comments->[$i]->[4]; 
	  my $comment = $comments->[$i]->[5]; 
	  my $admin = $cgi->param('admin');
	  
	  print "<TR><TD>",
	  	$cgi->a({-href=>"changetext.pl?logid=$log_id&admin=$admin"},
					"$log_id"),"</A>";
	  print "<TD>$date<TD>$client<TD>$proj<TD>$phase<TD>$comment</TR>";
	  $i++;
	}
	print "</TABLE>";
}


sub print_footer
{
	print $cgi->end_html();
}


sub create_query
{
	my $qstring;

	$qstring = "select log_id,date,client,proj,phase,comments
       			from time_log
       			where emp='$emp_id'";
	if ($start_date) 
	{
		$qstring = $qstring . " and date>='$start_date'";
	}
	if ($end_date) 
	{
		$qstring = $qstring . " and date<='$end_date'";
	}
	if ($client) 
	{
		$qstring = $qstring . " and client = '$client'";
	}
	if ($proj)
	{
		$qstring = $qstring . " and proj = '$proj'";
	}
	$qstring = $qstring . " order by date";

    #print "$qstring<BR>";

	return $qstring;
}

