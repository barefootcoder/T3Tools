#! /usr/bin/perl

use strict;

use CGI;
use Barefoot::timerdata;

use constant BREAK => "<BR>\n";
use constant DEBUG => 0;

my $listpath = "http://www.barefoot.net/cgi-bin/timer/scripts";
my $urlpath = DEBUG ? "http://www.barefoot.net/cgi-bin/$ENV{REMOTE_USER}test/timer"
    : "http://www.barefoot.net/cgi-bin/timer";


my $cgi = new CGI;

#hack alert -- fix this better later
$::ENV{PATH} .= ":/opt/sybase/bin:/usr/local/sybutils";
$::ENV{HOME} = "/home/www";
$::ENV{SYBASE} = "/opt/sybase";


my $user = $ENV{REMOTE_USER};
my $admin;
my $logid;

# Initilize $logid
if ($cgi->param('SLOGID'))
{
	$logid = $cgi->param('SLOGID');
} else
{
	$logid = $cgi->param('logid');
}

# Initilize $admin
if ($cgi->param('SADMIN'))
{
	$admin = $cgi->param('SADMIN');
} else
{
	$admin = $cgi->param('admin');
}


# Main Program
timerdata::set_connection("SYBASE_1","timer");

checkchange();
print_header();
print_form();
print_footer();



# Subroutines

sub checkchange
{
	if ($cgi->param('Replace'))
	{
		my $text = substr($cgi->param('COMMENT'),0,250);
		my $link = "$listpath/loglist.pl?admin=$admin";
		my $query = "update time_log 
				  set comments='$text' 
				  where log_id=$logid
				  go";
		my $results = timerdata::run_query("$query");
        print $cgi->redirect(-url=>"$link");
 	
		#print "$text<HR>$query<HR>$results";
		#exec ../loglist.pl;
	}

	if ($cgi->param('Back to List'))
	{
		my $link = "$listpath/loglist.pl?admin=$admin";
		print $cgi->redirect(-url=>"$link");
	}
}

sub print_header
{
	print $cgi->header();
    print $cgi->start_html(-title=>"Timer Log - Modify Comment"), "\n";
    print $cgi->center($cgi->h1("Modify Comments for Log ID $logid<HR>")), "\n";
}


sub print_form
{
	# Debug Section
	#print "user name is $user";
	#print "logid is $logid<BR>";
	#print "admin is $admin<BR>";
	#print "url=$listpath/loglist.pl?admin=$admin";

    #my $a = timerdata::run_query("
	#			select user_name(),suser_name(), db_name()
	#			go
	#		");
	my $results = timerdata::query_results
			("
				select comments 
				from time_log 
				where log_id=$logid
			");
    print $cgi->startform(), "\n";
	#print "a=$a<BR>";
	print "<CENTER><B>Previous Comment:</B></CENTER><BR>";
	if (defined($results))
	{
		print "<CENTER>$results->[0]->[0]</CENTER>";
		print "<BR><BR><CENTER><B>Replace Comment with:</B></CENTER><BR>";
		print "<CENTER>";
	}
	else
	{
		print "Error in Query";
	}
	
    text_area("COMMENT", "$results->[0]->[0]");
	hidden_field("SLOGID",$logid);
	hidden_field("SADMIN",$admin);
	
	print "<BR>", $cgi->submit('Replace');
	print $cgi->submit('Back to List');
	print $cgi->reset;
	print $cgi->endform();
	print "</CENTER>";
}


sub print_footer
{
	print $cgi->end_html();
}

sub text_area
{
    my ($name, $default) = @_;

    print $cgi->textarea(
		        -name=>$name,
		        -default=>$default,
				-rows=>5,
				-columns=>80,
				-maxlength=>250
			    );
    print "</NOBR>\n";
}

sub hidden_field
{
	my ($name, $value) = @_;

	print $cgi->hidden(
					-name=>$name,
					-default=>$value
					);
}

