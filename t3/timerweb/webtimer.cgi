#! /usr/bin/perl

use CGI;
$| = 1; # I tend to do this out of a strange habit. 
sub do_timer; # the function that does tries to run timer. But you knew
		      #	that.

$ENV{PATH} .= ":/export/projdata/proj/timer/:/export/usr/:.";
$timer = new CGI; # create the $timer object
$this_cgi = $timer->self_url; # this is here in case I need it.

print $timer->header,
	  $timer->start_html('Timer on the web'),
      $timer->h1('Timer web interface');

print <<'EndOfHunk';
USER BEWARE: There is CURRENTLY no taint-checking, though this will be added
very soon. YOU MUST USE YOUR UNIX USERNAME or it will crap out. To make it
work, it needs the -f switch, which means, make sure you do things
correctly, or it won't give a crap and blindly do what you asked (how Unix
of it). These and many more all-important features will be added at some
point, so be cool and patient. <A HREF="mailto:gregg@barefoot.net">Mail me
with comments and stuff.</A>
EndOfHunk

# begin the form; this is ugly and needs improvement 
# (notice switching back and forth between OO and procedural styles.)
# I love perl!!

print $timer->startform;
print "User name?";
print $timer->textfield(-name=>'user',
						-default=>'Gilbert',
						-size=>10,
						-maxlength=>20);
print "<BR>";

print $timer->radio_group(-name=>'action',
						  -values=>['start', 'pause', 'cancel'],
						  -default=>'start');
print "<BR>";

print "Timer name (default)?";
print $timer->textfield(-name=>'name',
						-default=>'default',
						-size=>10,
						-maxlength=>25);
print "<BR>";

print $timer->submit; # The submit button. Neato.
print $timer->reset;  # The reset button. Neato as well.
print $timer->defaults;  # The defaults button. worship me, fools.
print"<P>";

do_timer($timer); # this is the fucking hard part, the rest is just chrome

print  $timer->end_html;

sub do_timer
{
	my($timer) = @_;
	$username = $timer->param("user");
	$timer_type = $timer->param("action");
	$timer_name = $timer->param("name");
	if ($timer_type =~ /start/)
		{
			$timer_do = "-sf";
		}
		elsif ($timer_type =~ /pause/)
		{
			$timer_do = "-pf";
		}
		elsif ($timer_type =~ /cancel/)
		{
			$timer_do = "-cf";
		}

	$ENV{TIMERDIR} = "/export/usr/www";
	$ENV{USER} = "www";
	$timer_user = "-u$username";
	$timer_exe = "perl /export/projdata/proj/timer/timer";
#	print STDERR `id`;
	@timer_args = qq($timer_exe $timer_user $timer_do $timer_name);
	system(@timer_args) == 0 || die "system @timer_args failed : $!";
}

