#! /usr/bin/perl

# NOTES:
# Dedicated component that resides in server and processes message requests
# Adapted from Jay's code, which was Copyright 1998-2000 Oaesys Corporation.

# this app expects messages to have "to", "from", and "status" attributes in the
# first 3 attribute positions for one-element messages, and that these attrbs
# have certain predefined values, but makes no other
# assumptions about the xml message format

# ---------------------------------------------------------------------------

package Barefoot::T3Timer;

use strict;

1;

use Env qw(TIMERDIR HOME USER);
use Storable;
#use Barefoot::debug;							# comment out for production

#use Barefoot::timerdata;
use Barefoot::config_file;
use Barefoot::file;
use Barefoot::array;
use Barefoot::date;
use Barefoot::range;


# Timer constants

use constant CONFIG_FILE => '/etc/t3.conf';

use constant DBSERVER_DIRECTIVE => 'DBServer';
use constant DATABASE_DIRECTIVE => 'Database';
use constant TIMERDIR_DIRECTIVE => 'TimerDir';
use constant TALKERPATH => "./talker/";     # where message box files are found
use constant USER_FILE => TALKERPATH . "users.dat";

use constant TIMEFILE_EXT => '.timer';
use constant HISTFILE => 'timer.history';

use constant SAMBAGRP => 'guestpc';

use constant DEFAULT_WORKGROUP => 'Barefoot';
#use constant DEFAULT_WORKGROUP => 'TestCompany';
use constant FALLBACK_TIMER => '';   #'default';

# Timer command map

use constant TIMER_COMMANDS =>
    ("START", \&start,
     "PAUSE", \&pause,
	 "CANCEL", \&cancel,
	 "DONE", \&done,
	 "LIST", \&list,
	 "RENAME", \&rename);

my @VALID_COMMANDS =
	("START", 
	 "PAUSE", 
	 "CANCEL", 
	 "LIST", 
	 "RENAME");




#functions

sub processMessage;

# ------------------------------------------------------------
# Main Procedures
# ------------------------------------------------------------

sub processMessage
{
	my ($message) = @_;

    my $cfg_file = config_file->read(CONFIG_FILE);
    my $timerinfo = {};

	my %commands = TIMER_COMMANDS;
    my $workgroup = defined($::ENV{T3_WORKGROUP})
            ? $::ENV{T3_WORKGROUP} : DEFAULT_WORKGROUP;
	my $send;
	#my $ping;

	eval
	{
		#die "FAIL:name = $message->{name}";
		setuptimer($timerinfo, $message,$cfg_file,$workgroup);	
		readfile($timerinfo);
		die "FAIL:Command not supported" if 
			!Barefoot::array::in(@VALID_COMMANDS, $message->{command}, 's');

#    timerdata::set_connection($cfg_file->lookup($workgroup, DBSERVER_DIRECTIVE),
#            $cfg_file->lookup($workgroup, DATABASE_DIRECTIVE));

		$send = &{$commands{$message->{command}}}($timerinfo,$message);
		$send = $send . "\n" . ping($timerinfo);
	};

	$@ =~ s/(.*?)\s+at.*/$1/;
	$send = ack($message->{command},$message->{name},$@) . "\n" . 
			ping($timerinfo) if $@;

	return($send);
}    


sub setuptimer						# Set up
{
	my ($timerinfo,$message,$cfg_file,$workgroup) = @_;
	my $users = retrieve(USER_FILE);
	my $username = "";	
	
    foreach my $userid (keys %$users)
    {
		# replace nickname with username
        $username = $users->{$userid}->{username} and last 
				if $users->{$userid}->{nickname} eq $message->{user};
    }
	die "FAIL:Invalid user.  Change username or talk to administrator."
			if $username eq "";

    $timerinfo->{user} = $username;
    $timerinfo->{giventimer} = $message->{name}
            ? $message->{name} : FALLBACK_TIMER;
    $timerinfo->{halftime} = $message->{halftime};
    $timerinfo->{client} = $message->{client};
    $timerinfo->{project} = $message->{project};
    $timerinfo->{phase} = $message->{phase};
    $timerinfo->{newname} = $message->{_DATA_};
    $timerinfo->{tdir} = $cfg_file->lookup($workgroup, TIMERDIR_DIRECTIVE);
    $timerinfo->{tfile} = "$timerinfo->{tdir}/$timerinfo->{user}"
            . TIMEFILE_EXT;
    $timerinfo->{hfile} = "$timerinfo->{tdir}/" . HISTFILE;
    $timerinfo->{timers} = {};
}

# ------------------------------------------------------------
# Command Procedures
# ------------------------------------------------------------


sub start                   # start a timer
{
	my ($timerinfo,$message) = @_;
	my $timersent = $timerinfo->{giventimer};

	my $func = $message->{command};

    if ($timerinfo->{giventimer} ne $timerinfo->{curtimer})
    {
    	$timerinfo->{timers}->{$timerinfo->{curtimer}}->{time} .= time . ','
        	    if $timerinfo->{curtimer};
    	$timerinfo->{timers}->{$timerinfo->{giventimer}}->{time} .=
        	    ($timerinfo->{halftime} ? "2/" : "") . time . '-';
    	$timerinfo->{timers}->{$timerinfo->{giventimer}}->{client}
        	    = $message->{client};
    	$timerinfo->{timers}->{$timerinfo->{giventimer}}->{project}
        	    = $message->{project};
    	$timerinfo->{timers}->{$timerinfo->{giventimer}}->{phase}
        	    = $message->{phase};
  	  	$timerinfo->{curtimer} = $timerinfo->{giventimer};

    	writefile($timerinfo);
		return(ack("START",$timersent,"OK"));
	}
	else
	{
		# $halftime indicates if timer is currently running in halftime mode
		# $givenhalftime indicates if halftime is begining requested

		my $halftime = ($timerinfo->{timers}->{$timerinfo->{curtimer}}->{time}
				=~ m{2/\d+-$}) ? 1:0;
		my $givenhalftime = ($timerinfo->{halftime} eq "YES") ? 1:0; 

		if ($halftime != $givenhalftime)
		{
    		$timerinfo->{timers}->{$timerinfo->{curtimer}}->{time} 
					.= time . ',';
    		$timerinfo->{timers}->{$timerinfo->{giventimer}}->{time} .=
        		    ($timerinfo->{halftime} ? "2/" : "") . time . '-';

    		writefile($timerinfo);
			return(ack("START",$timersent,"OK"));
		}
		else
		{
			return(ack("START",$timersent,
					"FAIL: Timer already started in that mode"));
		}
	}
}


sub pause                   # pause all timers
{
	my ($timerinfo) = @_;
	my $timersent = $timerinfo->{giventimer};

    if (!$timerinfo->{curtimer})
    {
		return(ack("PAUSE",$timersent,"FAIL:No timer is running"));
    }


    $timerinfo->{timers}->{$timerinfo->{curtimer}}->{time} .= time . ',';
    delete $timerinfo->{curtimer};

    writefile($timerinfo);
	return(ack("PAUSE", $timersent, "OK"));
}


sub cancel                   # cancel a timer
{
	my ($timerinfo) = @_;
	my $timersent = $timerinfo->{giventimer};

   	if (!exists $timerinfo->{timers}->{$timerinfo->{giventimer}})
    {
		return(ack("CANCEL",$timersent,
				"FAIL:Can't cancel; No such timer."));
    }

    save_history($timerinfo, "cancel");
    delete $timerinfo->{timers}->{$timerinfo->{giventimer}};
    delete $timerinfo->{curtimer}
            if $timerinfo->{curtimer} eq $timerinfo->{giventimer};

    writefile($timerinfo);
	return(ack("CANCEL",$timersent,"OK"));
}


sub done                   # done with a timer
{
	my ($timerinfo) = @_;

    if (!exists $timerinfo->{timers}->{$timerinfo->{giventimer}})
    {
		return(ack("DONE",$timerinfo->{curtimer},
				"FAIL:No such timer as $timerinfo->{giventimer}"));
        #error(1, "no such timer as $timerinfo->{giventimer}\n");
    }

    #my $thistimer = $timerinfo->{timers}->{$timerinfo->{giventimer}};
    #my $minutes = calc_time($thistimer->{time});
    #my $hours = range::round($minutes / 60, range::ROUND_DOWN),
    #my $date = calc_date($thistimer->{time});
    #my $client = $thistimer->{client};
    #print "\ntotal time is $minutes mins ($hours hrs ", $minutes - $hours * 60,
    #    " mins) on $date for $client\n";
    #print "please remember this in case there is a problem!\n\n";

    log_to_sybase($timerinfo, $timerinfo->{giventimer});

    save_history($timerinfo, "done");
    delete $timerinfo->{timers}->{$timerinfo->{giventimer}};

    if ($timerinfo->{curtimer} eq $timerinfo->{giventimer})
    {
        undef($timerinfo->{curtimer});
    }

    writefile($timerinfo);
	return(ack("DONE",$timerinfo->{giventimer},"OK"));
}


sub list
{
	my ($timerinfo) = @_;

	return(ack("LIST",$timerinfo->{giventimer},"OK"));
}


sub rename                   # new name for a timer
{
	my ($timerinfo) = @_;
	my ($func) = 0;
	my $timersent = $timerinfo->{giventimer};
 
    # just a shortcut here
    my $oldname = $timerinfo->{giventimer};
    if (!exists $timerinfo->{timers}->{$oldname})
    {
		return(ack("RENAME",$timersent,
				"FAIL:Can't rename, no such timer."));
    }

    my $newname;
    if ($timerinfo->{newname})
    {
        $newname = $timerinfo->{newname};
    }
    else
    {
		return(ack("RENAME",$timersent,
				"FAIL:New name not specified"));
    }

    # if we're renaming ...
    if ($newname ne $oldname)
    {
        if (exists $timerinfo->{timers}->{$newname})
        {
			return(ack("RENAME",$timersent,
					"FAIL:That timer already exists"));
        }

        $timerinfo->{timers}->{$newname} = $timerinfo->{timers}->{$oldname};
        delete $timerinfo->{timers}->{$oldname};
        # got to do this so get_client() (below) will work
        $timerinfo->{giventimer} = $newname;
    }

    # but of course we might just be changing the client
	# not checking client with database
    #$timerinfo->{timers}->{$newname}->{client} = get_client($func, $timerinfo);
    $timerinfo->{timers}->{$newname}->{client} = $timerinfo->{client}
			if $timerinfo->{client} ne "";
    $timerinfo->{timers}->{$newname}->{project} = $timerinfo->{project}
			if $timerinfo->{project} ne "";
    $timerinfo->{timers}->{$newname}->{phase} = $timerinfo->{phase}
			if $timerinfo->{phase} ne "";

    $timerinfo->{curtimer} = $newname if $timerinfo->{curtimer} eq $oldname;
	
    writefile($timerinfo);
	return(ack("RENAME",$timersent,"OK"));
}



# ------------------------------------------------------------
# File manipulation Procedures
# ------------------------------------------------------------

sub readfile
{
    my ($timerinfo) = @_;

    open(TFILE, $timerinfo->{tfile}) or return 0;
    while ( <TFILE> )
    {
        chomp;
        my ($key, $time, $client, $project, $phase) = split(/\t/);
        my $curtimer = {};
        $curtimer->{time} = $time;
        $curtimer->{client} = $client;
        $curtimer->{project} = $project;
        $curtimer->{phase} = $phase;
        $timerinfo->{timers}->{$key} = $curtimer;
        $timerinfo->{curtimer} = $key if ($time =~ /-$/);
    }
	close(TFILE);
}


sub writefile
{
    my ($timerinfo) = @_;

    open(TFILE, ">$timerinfo->{tfile}") or die "can't open timer file";
    my $timer;
    foreach $timer (keys %{$timerinfo->{timers}})
    {
       my $timerstuff = $timerinfo->{timers}->{$timer};
       print TFILE $timer, "\t", $timerstuff->{time}, "\t",
                $timerstuff->{client}, "\t", $timerstuff->{project},
				"\t", $timerstuff->{phase}, "\n";
    }
    close(TFILE);

    # if these don't work, no big deal, but if running under Linux, they
    # should reset the file to be accessible from 4DOS/Win95
    eval { chown -1, scalar(getgrnam(SAMBAGRP)), $timerinfo->{tfile} };
    eval { chmod 0660, $timerinfo->{tfile} };
}


sub save_history
{
    my ($timerinfo, $func) = @_;
    my $timerstuff = $timerinfo->{timers}->{$timerinfo->{giventimer}};

    open(HIST, ">>$timerinfo->{hfile}") or die("couldn't open history file");
    local ($,) = "\t";              # put tabs between elements
    print HIST $timerinfo->{user}, $::USER, $func, $timerinfo->{giventimer},
            $timerstuff->{time}, $timerstuff->{client}, "\n";
    close(HIST);
}

# ------------------------------------------------------------
# Support Procedures
# ------------------------------------------------------------

sub ack
{
	my ($command, $name, $result) = @_;

	my $sendback = '<MESSAGE module="TIMER" command="' . $command 
			. '" name="' . $name . '">' . $result . '</MESSAGE>';

	return ($sendback);
}

sub ping
{
	my ($timerinfo) = @_;

	my $timers = $timerinfo->{timers};
	my $lines;
	
	#close(TFILE);

	foreach my $key (keys (%$timers))
	{
		my $thistimer  = $timers->{$key};
		
		my $line = '<MESSAGE module="TIMER"';

# debugging lines
#		$line = $line . ' tfile="' . $timerinfo->{tfile} .'"';
#		$line = $line . ' newname="' . $timerinfo->{newname} .'"';

		$line = $line . ' user="' . $timerinfo->{user} .'"';
		$line = $line . ' name="' . $key .'"';
		$line = $line . ' client="' . $thistimer->{client} . '"' 
				if $thistimer->{client};
		$line = $line . ' project="' . $timers->{$key}->{project} . '"' 
				if $thistimer->{project};
		$line = $line . ' phase="' . $timers->{$key}->{phase} . '"' 
				if $thistimer->{phase};
				
		if ($thistimer->{time} =~ /-$/)
		{
			$line = $line . ' status="ACTIVE"';
		}

		$line = $line . ' date="' 
			. calc_date($thistimer->{time}) . '"';
		$line = $line . ' halftime="YES"' if $thistimer->{time} =~ m{/\d+-$};
		$line = $line . ' elapsed="' . calc_time($thistimer->{time}) . '"';

		# Not sending BD-DATA anymore 
		#$line = $line . '>' . $thistimer->{time} . '</MESSAGE>';
		$line = $line . '></MESSAGE>' . "\n";

		$lines = $lines . $line;
	}

	return ($lines);
}

sub get_client
{
    my ($func, $timerinfo) = @_;
    # a little shortcut here
    my $giventimer = $timerinfo->{timers}->{$timerinfo->{giventimer}};

    # this is somewhat complicated ...  we need to figure out what the
    # proper client should be, and then use it as the default ... now,
    # we have three possible places to get the potential client from:
    # the default client for this user (out of Sybase), the client
    # already set for a pre-existing timer, or the client specified on
    # the command line (if given) ... for starting a timer, the priority
    # is: pre-existing, command line, default ... for renaming a timer,
    # the priority is command line, pre-existing, default ... now! if -f
    # (force) was specified, we can quit right here ... also, if we're
    # _start_ing a pre-existing timer, the user isn't allowed to change
    # the client, so we quit in that case too ...

    # got it? here we go ...
    my $defclient;
    if ($func ne 'RENAME')                           # anything but new name
    {                                           # (probably start)
        if (exists $giventimer->{client})       # pre-existing client first
        {
            $defclient = $giventimer->{client};
        }
        elsif ($timerinfo->{client})            # then -C option
        {
            $defclient = $timerinfo->{client};
        }
        else                                    # defclient from Sybase
        {
            $defclient = timerdata::default_client($timerinfo->{user});
        }
    }
    else                                        # must be new name
    {
        if ($timerinfo->{client})               # -C option first
        {
            $defclient = $timerinfo->{client};
        }
        elsif (exists $giventimer->{client})    # then pre-existing client
        {
            $defclient = $giventimer->{client};
        }
        else                                    # defclient from Sybase
        {
            $defclient = timerdata::default_client($timerinfo->{user});
        }
    }
    return $defclient if $timerinfo->{force}
            or ($func eq 'START' and exists $giventimer->{client});

    my $client;
    # make a block so redo will work
    CLIENT: {
        print "which client is this for? ($defclient)  ";
        $client = <STDIN>;
        chomp $client;
        $client = $defclient if not $client;    # use default if not specified
        my $fullname = timerdata::client_name($client);
        if (defined($fullname))
        {
            print "illegal client number!\n" and redo CLIENT if not $fullname;
            print "client is $client: $fullname; is this right? (y/N)  ";
        }
        else
        {
            print "can't verify client number! are you sure you want to ",
                    "proceed? (y/N)  ";
        }
        redo CLIENT unless <STDIN> =~ /^y/i;
    }
    return $client;
}


sub calc_time
{
    my ($line) = @_;
    my @times = split(/,/, $line);
    my $total_time = 0;

    my $current_time = 0;
    foreach my $time (@times)
    {
        if ($time =~ /^([+-]\d+)$/)
        {
            $total_time += $1 * 60;
            next;
        }

        my ($divisor, $from, $to) = $time =~ m{(?:(\d+)/)?(\d+)-(\d+)?};
        die "illegal format in time file" unless $from;
        if (!$to)
        {
            die "more than one current time in time file" if $current_time;
            $current_time = 1;
            $to = time;
        }
        $total_time += ($to - $from) / ($divisor ? $divisor : 1);
    }
    return range::round($total_time / 60, range::ROUND_UP);
}


sub calc_date
{
    my ($line) = @_;

    my $seconds;
    if ($line =~ /(\d+),$/)     # ends in a comma, must be paused
    {
        $seconds = $1;
    }
    else                        # must be current
    {
        $seconds = time;
    }

    # adjust for working after midnight ... if the time is before 6am,
    # we'll just subtract a day
    my ($hour) = (localtime $seconds)[2];
    $seconds -= 24*60*60 if $hour < 6;

    my ($day, $mon, $year) = (localtime $seconds)[3..5];
    return ++$mon . "/" . $day . "/" . ($year + 1900);
}


sub log_to_sybase
{
    my ($timerinfo, $log_timer) = @_;
    # a shortcut
    my $timer = $timerinfo->{timers}->{$log_timer};

    my ($emp, $client, $rounding, $to_nearest, $date, $hours, $proj, $phase,
            $cliproj, $comments);

    # please note that the order you ask for the data elements in is
    # *very* important ... the following things are true:
    #   you have to do employee before you do client
    #   you have to do employee before you do project
    #   you have to do date before you do client
    #   you have to do date before you do project
    #   you have to do client before you do hours
    #   you have to do client before you do project
    #   you have to do client before you do cliproj
    #   you have to do project before you do phase
    #   you have to do project before you do cliproj
    #   you have to do project before you do comments
    # based on this, there is not a whole lot you can do differently in
    # the order chosen below, so DON'T MUCK WITH IT!

    # a bunch of anonymous blocks for purposes of redo
    # (well, they're called "anonymous" even tho they're named ... go figure)
    EMP: {
        my $valid_employees = timerdata::query_results("
                select e.emp, e.fname, e.lname
                from employee e
                order by e.emp
            ");
        $emp = input("Employee number or ? for list:",
                timerdata::emp_number($timerinfo->{user}));
        if ($emp eq "?")
        {
            foreach my $row (@$valid_employees)
            {
                print "  {", $row->[0], " - ",
                        $row->[1], " ", $row->[2], "}\n";
            }
            redo EMP;
        }
        my $fullname = timerdata::emp_fullname($emp);
        print "  {Invalid employee!}\n" and redo EMP unless $fullname;
        print "  {Employee is $fullname}\n";
    }

    DATE: {
        $date = input("Date:", calc_date($timer->{time}));
        print "  {Invalid date!}\n" and redo DATE unless date::isValid($date);
    }

    CLIENT: {
        my $valid_clients = timerdata::query_results("
                select c.client, c.name
                from client c
                where exists
                (
                    select 1
                    from client_employee ce
                    where ce.emp = '$emp'
                    and ce.client = c.client
                    and '$date' between ce.start_date and ce.end_date
                )
            ");
        $client = input("Client number or ? for list:", $timer->{client});
        if ($client eq "?")
        {
            foreach my $row (@$valid_clients)
            {
                print "  {", $row->[0], " - ", $row->[1], "}\n";
            }
            redo CLIENT;
        }
        # check for valid client
        foreach my $row (@$valid_clients)
        {
            if ($client eq $row->[0])
            {
                print "  {Client is ", $row->[1], "}\n";
                ($rounding, $to_nearest) = timerdata::client_rounding($client);
                last CLIENT;
            }
        }
        print "  {Invalid client!}\n";
        redo CLIENT;
    }

    HOURS: {
        $hours = input("Hours:",
                range::round(calc_time($timer->{time}) / 60,
                        $rounding, $to_nearest));
        print "  {Hours must divisible by $to_nearest}\n" and redo HOURS
                unless $hours == range::round($hours,
                    range::ROUND_OFF, $to_nearest);
        print "  {Hours must be greater than zero}\n" and redo HOURS
                unless $hours > 0;
    }

    PROJECT: {
        my $valid_projs = timerdata::query_results("
                select proj, name
                from project p
                where client = '$client'
                and '$date' between start_date and end_date
                and exists
                (
                    select 1
                    from client_employee ce
                    where ce.emp = '$emp'
                    and ce.client = p.client
                    and isnull(ce.proj, p.proj) = p.proj
                    and '$date' between ce.start_date and ce.end_date
                )
            ");
        $proj = input("Project or ? for list:");
        if ($proj eq "?")
        {
            foreach my $row (@$valid_projs)
            {
                print "  {", $row->[0], " - ", $row->[1], "}\n";
            }
            redo PROJECT;
        }
        # uppercase it for 'em
        $proj = string::upper($proj);
        # check for valid project
        foreach my $row (@$valid_projs)
        {
            print "  {Project is ", $row->[1], "}\n" and last PROJECT
                    if $proj eq $row->[0];
        }
        print "  {Invalid project!}\n";
        redo PROJECT;
    }

    my ($phase_needed, $cliproj_needed, $comments_needed)
            = timerdata::proj_requirements($client, $proj, $date);

    PHASE: {
        last PHASE unless $phase_needed;
        my $valid_phases = timerdata::query_results("
                select phase, name
                from phase
            ");
        $phase = input("Phase or ? for list:");
        if ($phase eq "?")
        {
            foreach my $row (@$valid_phases)
            {
                print "  {", $row->[0], " - ", $row->[1], "}\n";
            }
            redo PHASE;
        }
        # uppercase it for 'em
        $phase = string::upper($phase);
        # check for valid phase
        foreach my $row (@$valid_phases)
        {
            print "  {Phase is ", $row->[1], "}\n" and last PHASE
                    if $phase eq $row->[0];
        }
        print "  {Invalid phase!}\n";
        redo PHASE;
    }

    CLIPROJ: {
        last CLIPROJ unless $cliproj_needed;
        my $valid_cliprojs = timerdata::query_results("
                select project_id, name
                from client_project
                where client = '$client'
            ");
        $cliproj = input("Client Project ID or ? for list:");
        if ($cliproj eq "?")
        {
            foreach my $row (@$valid_cliprojs)
            {
                print "  {", $row->[0], " - ", $row->[1], "}\n";
            }
            redo CLIPROJ;
        }
        # uppercase it for 'em
        $cliproj = string::upper($cliproj);
        # check for valid project
        foreach my $row (@$valid_cliprojs)
        {
            print "  {Client project is ", $row->[1], "}\n" and last CLIPROJ
                    if $cliproj eq $row->[0];
        }
        print "  {Invalid client project ID!}\n";
        redo CLIPROJ;
    }

    COMMENTS: {
        last unless $comments_needed;
        print "\nEnter comments below (maximum 255 chars):\n";
        print "  (255 chars is a little over 3 lines if your screen is 80\n";
        print "   columns wide and you don't hit RETURN at all (which you ",
                "shouldn't))\n";
        print "Enter ^D (control-D) on a line by itself to finish the ",
                "comments.\n";
        local ($/) = undef;
        $comments = input();
        while ($comments =~ s/^\s+$//) {};  # no completely blank lines
        while ($comments =~ s/^\n//) {};    # no extra newlines in front
        $comments =~ s/\s*\n+\s*$//;        # none at the end either
        print "  {You must have comments}\n\n" and redo COMMENTS
                if not $comments;
        print "  {Comments too long!}\n\n" and redo COMMENTS
                if length($comments) > 255;
    }

    print "working.....\n";

    # show everything and double check:
    #writeln(Log, $emp, timerdata::emp_fullname($emp),
    #        $client, timerdata::client_name($client), $date,
    #        $proj, timerdata::proj_name($client, $proj),
    #        $phase, timerdata::phase_name($phase), $hours,
    #        $cliproj, timerdata::cliproj_name($client, $cliproj));
    #writeln(Log_Comments, $comments);

    print "\n\nis everything okay? (y/N)  ";
    print "\n  {Try to log this timer out again later.}\n" and exit
            unless <STDIN> =~ /^y/i;

    my $error = timerdata::insert_log($emp, $client, $proj, $phase, $cliproj,
            $date, $hours, $comments);
    if ($error)
    {
        print "\nthere was some error!\n";
        print "{$error}\n";
        print "please report this to a system administrator for resolution\n";
        exit();
    }
    else
    {
        print "\ntime has been logged to Sybase\n\n";
    }
}
