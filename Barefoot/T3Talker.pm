#! /usr/bin/perl

# NOTES:
# Dedicated component that resides in server and processes message requests
# Adapted from Jay's code, which was Copyright 1998-2000 Oaesys Corporation.

# this app expects messages to have "to", "from", and "status" attributes in the
# first 3 attribute positions for one-element messages, and that these attrbs
# have certain predefined values, but makes no other
# assumptions about the xml message format

# ---------------------------------------------------------------------------

package Barefoot::T3Talker;

use strict;

#use Barefoot::debug;							# comment out for production

use Storable;
use Barefoot::file;
use Barefoot::array;

use Barefoot::T3;

# T3 constants

# Test Workgroup... comment out for production.
#BEGIN
#{
#T3::set_workgroup("TestCompany");
#}

# Talker constants
use constant TALKERPATH      => T3::config_param('TalkerDir') . "/";

use constant HISTORY_FILE    => TALKERPATH . "history";
use constant CLIENTID_FILE   => TALKERPATH . "client_id";
use constant USER_FILE       => TALKERPATH . "users.dat";
use constant BOX_FILE_EXT    => ".box";
use constant ACTIVE_FILE_EXT => ".active";

use constant ST_INFO_REQUEST => 'INFO';
use constant ST_USER_OFF     => 'IMOFF';
use constant ST_USER_ON      => 'IMON';
use constant ST_USER_BUSY    => 'IMBUSY';
use constant ST_MESSAGE      => 'NORMAL';
use constant ST_NO_REPLY     => 'NO_REPLY';
use constant ST_LOGON        => 'LOGON';
use constant ST_LOGOFF       => 'LOGOFF';
use constant ST_DELIVERED    => 'NORMAL_DLVD';
use constant ST_READ         => 'NORMAL_READ';

use constant M_ACK =>
		'<MESSAGE from="" to="" status="ACK">ACKNOWLEDGED</MESSAGE>';
use constant M_ID =>
		'<MESSAGE from="" to="" status="ID" id="HEX_ID">ID</MESSAGE>';
use constant M_STATUS =>
		'<MESSAGE from="FROM" status="STATUS">CONTENT</MESSAGE>';
use constant M_RECEIVED =>
		'<MESSAGE from="FROM" to="TO" status="NORMAL_RCVD" id="HEX_ID">NORMAL_RCVD</MESSAGE>';

# Status arrays

# Valid statuses
my @valid_status    = (ST_INFO_REQUEST, ST_LOGON, ST_LOGOFF,
                    ST_USER_ON, ST_USER_BUSY, ST_MESSAGE,
                    ST_DELIVERED, ST_READ,
                    ST_USER_OFF,
                    ST_NO_REPLY);

# Processing statuses
my @update_status   = (ST_LOGOFF, ST_USER_ON,
                        ST_USER_OFF,
                        ST_USER_BUSY);
my @message_status  = (ST_MESSAGE, ST_NO_REPLY, ST_DELIVERED, ST_READ);
my @history_status  = (ST_MESSAGE, ST_NO_REPLY);
my @receipt_status  = (ST_MESSAGE);

# Reply type statuses
my @rollcall_status = (ST_INFO_REQUEST, ST_USER_ON, ST_USER_BUSY,
                        ST_MESSAGE, ST_DELIVERED, ST_READ);
my @getmail_status  = (ST_USER_ON, ST_USER_BUSY, ST_MESSAGE,
                        ST_DELIVERED, ST_READ);
my @clientid_status = (ST_LOGON);
my @acknow_status   = (ST_LOGOFF);
my @nothing_status  = (ST_NO_REPLY);

my $users = retrieve(USER_FILE);

# functions:
sub processMessage;
sub addToBox;
sub addToHistory;
sub touchActiveFile;
sub updateActiveFile;
sub saveMessage;
sub getClientID;
sub test_user;

# ---------------------------------------------------------------------------

sub processMessage
{
	my ($attr) = @_;
	my $message = $attr->{_FULL_};

#file::append_lock("/tmp/t3.debug", "Processing talker message.\n");

	# Test for valid talker status
	if (!Barefoot::array::in(@valid_status, $attr->{status}, 's'))
    {
		die "Invalid status for talker message.";
    }

#	if ($attr->{from} eq "")
#	{
#		die "Talker messages must have a from user specified.";
#	}

#	test_user($users, $attr->{from}) or die "Unknown sender, permission denied.\n";

	# Process user status

	if (Barefoot::array::in(@update_status, $attr->{status}, 's'))
	{
		# save into users.roll if status message
		updateActiveFile($attr->{from}, $attr->{status}, $attr->{_DATA_});
		addToBox($attr);	# forces box creation if new user
	}
	else 
	{
		# if not status message, "from" user is still active, touch their file.
		touchActiveFile($attr->{from});
	}

	# Generate reply

	my $reply = "";
	
	if (Barefoot::array::in(@clientid_status, $attr->{status}, 's'))
	{
		# ID message will always be first, if not only, line
		$reply = M_ID;

		my $id = getClientID();
		my $idstring = "$id" . "00000000";
		$reply =~ s/HEX_ID/$idstring/;
	}

	if (Barefoot::array::in(@rollcall_status, $attr->{status}, 's'))
	{
		foreach my $file (glob(TALKERPATH . "*" . ACTIVE_FILE_EXT))
		{
			my $active = file::get_lock($file);
			$active =~ s/LOGOFF/IMOFF/g;
			
			$reply .= $active;
		}
	}

	if (Barefoot::array::in(@getmail_status, $attr->{status}, 's'))
	{
		# get user's existing mail
		# should execute before any new mail is saved, so the user
		# can send messages to self
		my $user_box_filename = TALKERPATH . $attr->{from} . BOX_FILE_EXT;
		my $lh = file::open_lock($user_box_filename);
		$reply .= file::get($lh);

		file::store($lh, undef);		# blanks the file
	}

	if (Barefoot::array::in(@message_status, $attr->{status}, 's'))
	{
#	test_user($users, $attr->{to}) or die "Unknown message recipient.\n";
		# save and build reply for normal talker message
		$reply .= saveMessage($attr);
	};

	if (Barefoot::array::in(@acknow_status, $attr->{status}, 's'))
	{
		$reply .= M_ACK;
	}

	return($reply);
}
# ---------------------------------------------------------------------------

sub touchActiveFile
{
	my ($user) = @_;

	# append only (automatically creates if does not exist)

	my $path = TALKERPATH . $user . ACTIVE_FILE_EXT;

	my $now = time;
	utime $now, $now, $path
		or open TMP, ">>$path"
		or warn "Couldn't touch $path: $!\n";
}
# ---------------------------------------------------------------------------

sub saveMessage
{
	my ($attr) = @_;

	addToBox($attr);
	addToHistory($attr);

	my $reply = "";
	if (Barefoot::array::in(@receipt_status, $attr->{status}, 's'))
	{
		$reply = M_RECEIVED;
		$reply =~ s/FROM/$attr->{to}/;
		$reply =~ s/TO/$attr->{from}/;
		$reply =~ s/HEX_ID/$attr->{id}/;
	};

	return($reply);
}
# ---------------------------------------------------------------------------

sub addToBox
{
	my ($message) = @_;

	my @addressees;

	if ($message->{to} eq 'ALL')
	{
		opendir(TDIR, TALKERPATH) or die("can't open talker directory");
		foreach my $box (readdir(TDIR))
		{
			my $fileext = "(.*?)\Q" . BOX_FILE_EXT . "\E\$";

			push(@addressees, $box =~ m/$fileext/);
		}
		closedir(TDIR);
	}
	else
	{
		@addressees = (split(',', $message->{to}));
	}

	foreach my $user (@addressees)
	{
		my $path = TALKERPATH . $user . BOX_FILE_EXT;
		my $found = 0;

		if (defined $message->{_FULL_})
		{
			my @currentmail = file::get_lock($path);

			foreach my $mail (@currentmail)
			{
				my $attr = getAttrs($mail);
				next unless ($attr->{id} eq $message->{id}
					&& $attr->{status} eq $message->{status});
				$found = 1 and last;      # found it, no need to check further
			}
		}

		# append only (automatically creates if does not exist)
		file::append_lock($path, $message->{_FULL_}) if not $found;
	}
}
# ---------------------------------------------------------------------------

sub updateActiveFile
{
	my ($user, $status, $data) = @_;

	# put together a generic-looking status message
	my $statusmsg = M_STATUS;
	$statusmsg =~ s/FROM/$user/;
	$statusmsg =~ s/STATUS/$status/;
	$statusmsg =~ s/CONTENT/$data/;

	my $path = TALKERPATH . $user . ACTIVE_FILE_EXT;

	my $success = file::store_lock($path, "$statusmsg\n");
}
# ---------------------------------------------------------------------------

sub addToHistory
{
	my ($attr) = @_;

	if (Barefoot::array::in(@history_status, $attr->{status}, 's'))
	{
		file::fastio_append_record(HISTORY_FILE, $attr->{id},
			$attr->{from}, $attr->{to}, $attr->{time}, $attr->{_DATA_});
	}
}
# ---------------------------------------------------------------------------

sub getClientID
{
	my $lh = file::open_lock(CLIENTID_FILE);
	my $id = file::get($lh);

	my $nextid = sprintf "%lx", (hex($id) + 1);

	file::store($lh, $nextid);

	return($id)
}
# ---------------------------------------------------------------------------

sub test_user
{
	my ($user_hash_ref, $user) = @_;

	my $found = 0;
	foreach my $userid (keys %$user_hash_ref)
	{
		$found = 1 and last if $user_hash_ref->{$userid}->{nickname} eq $user;
	}

	return ($found);
}
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

sub getAttrs
{
	my ($element) = @_;

	# Replace %hex values with actual ASCII chars
	# Now automatically handled by CGI library
	#$element =~ s/%(\w\w)/chr(hex($1))/ge;

	my ($open_tag) = $element =~ /<([^\/].*?)>/;

	# read attributes
	my $attr;
	$attr->{$1} = $2 while $open_tag =~ m/(\w+)="(.*?)"/g;

	($attr->{_DATA_}) = $element =~ /<.*?>(.*?)<\/.*>/;
	$attr->{_FULL_} = $element;

	return $attr;
}
# ---------------------------------------------------------------------------
