#! /usr/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# T3
#
###########################################################################
#
# Common Perl routines for accessing T3 Tools stuff.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package T3;

### Private ###############################################################

use strict;

use Carp;

use CGI;
use Barefoot::file;
use Barefoot::html_menu;
use Barefoot::config_file;

use constant CONFIG_FILE => '/etc/t3.conf';
use constant SERVER_FILE => '/etc/t3.servers';
use constant DEFAULT_WORKGROUP => 'Barefoot';

use vars qw($server_url $username);

use constant LOGON_MESSAGE		=> 'LOGON';
use constant LOGOFF_MESSAGE		=> 'LOGOFF';
use constant ID_MESSAGE			=> 'ID';
use constant USER_ON_MESSAGE	=> 'IMON';
use constant USER_OFF_MESSAGE	=> 'IMOFF';
use constant BUSY_MESSAGE		=> 'IMBUSY';
use constant TALKER_MESSAGE		=> 'NORMAL';
use constant NOREPLY_MESSAGE	=> 'NO_REPLY';
use constant ERROR_MESSAGE		=> 'ERROR';
use constant INFO_MESSAGE		=> 'INFO';
use constant DELIVERED_MESSAGE	=> 'NORMAL_DLVD';
use constant READ_MESSAGE		=> 'NORMAL_READ';
use constant RECEIVED_MESSAGE	=> 'NORMAL_RCVD';

our $cfg_file = config_file->read(CONFIG_FILE);

our $username = defined($::ENV{T3_USER})
		? $::ENV{T3_USER} : $::ENV{USER};
our $workgroup = defined($::ENV{T3_WORKGROUP})
		? $::ENV{T3_WORKGROUP} : DEFAULT_WORKGROUP;
our $server_url = workgroup_server($workgroup);

1;


#
# Subroutines:
#

sub set_workgroup
{
	my ($new_wg) = @_;

	$workgroup = $new_wg;
	$server_url = workgroup_server($workgroup);
}

sub get_workgroup
{
	return $workgroup;
}

sub set_server
{
	my ($new_server) = @_;

	$server_url = $new_server;
}

sub get_server
{
	return $server_url;
}

sub workgroup_server
{
	my ($find_wg) = @_;

	my $wg_server;

	open(SVR, SERVER_FILE) or croak("cannot open server file " . SERVER_FILE);
    while ( <SVR> )
	{
		my ($wgroup, $url) = /^(\w+)=(.*)$/;
		$wg_server = $url and last if $wgroup eq $find_wg;
	}
	close (SVR);
    
	return $wg_server;
}

sub config_param
{
	my ($directive) = @_;

	return $cfg_file->lookup($workgroup, $directive);
}

sub build_message
{
 	my ($status, $from, $to, $id, $location, $subject, @messages) = @_;

	# put the lines together
	my $message = join('', @messages);

	# It seems that one single layer of encoding isn't gonna cut it; the windows
	# client requires escaped HTML (the &#decimal; format, or words like &gt; ),
	# but the server CGI decodes as well (the %02X format). So we need to
	# double-encode.
	
	$message = CGI::escapeHTML($message);

	# Also, we need to handle newlines and slashes.  Since any character can be
	# escaped in this fashion, I suppose we could theoretically escape *every*
	# character, and do this in one line (actually, two, the newlines would still
	# have to be separate, wouldn't they?) instead of three, but that would require
	# a lot of space in history (five times as much per character).

	$message =~ s/\n/&#13;&#10;/g;
	$message =~ s/\//&#47;/g;
	
	# To match the windows client, the command-line client will have to
	# call CGI::unescapeHTML.  That will decode the newlines and slashes as well.
	
	# Ok, now HMTL encode the special chars for the server CGI.
	$message = html_menu::_escape_uri_value($message);

 	my $url = $server_url . 'DATA=<MESSAGE'
 			. '+status="' . $status . '"'
 			. '+from="' . $from . '"'
 			. '+to="' . $to . '"'
 			. '+id="' . $id . '"'
 			. '+location="' . $location . '"'
 			. '+subject="' . $subject . '"'
 			. '>' . $message . '</MESSAGE>';
	return $url;
}

sub send_message
{
	my ($message) = @_;

	# a lynx source dump will give us the output back
	my @lines = `lynx -source '$message'`;
	croak("can't start lynx: $?") if $?;
	chomp @lines;

	# remove blank lines on the way out
	return grep { ! /^\s*$/ } @lines;
}

sub parse_message
{
	my ($element) = @_;

	my ($open_tag) = $element =~ m{ < ([^/].*?) > }x;

	# read attributes
	my $attr;
	$attr->{$1} = $2 while $open_tag =~ m{ (\w+) = "(.*?)" }xg;

	($attr->{_DATA_}) = $element =~ m{ <.*?> (.*?) </.*> }x;

	return $attr;
}
