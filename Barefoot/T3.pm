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

use Barefoot::html_menu;
use Barefoot::config_file;

use constant CONFIG_FILE => '/etc/t3.conf';
use constant DEFAULT_WORKGROUP => 'Barefoot';

use constant INI_FILE => 'timer.ini';

use constant SERVER_URL_DIRECTIVE => 'server_url';
use constant USERNAME_DIRECTIVE => 'user_name';
use constant CLIENT_TIMEOUT_DIRECTIVE => 'server_refresh_interval';
use vars qw($server_url $username $client_timeout);

use constant LOGON_MESSAGE => 'IMON';
use constant LOGOFF_MESSAGE => 'IMOFF';
use constant BUSY_MESSAGE => 'IMBUSY';
use constant TALKER_MESSAGE => 'NORMAL';
use constant ERROR_MESSAGE => 'ERROR';
use constant INFO_MESSAGE => 'INFO';
use constant NOREPLY_MESSAGE => 'NO_REPLY';

my $cfg_file = config_file->read(CONFIG_FILE);
my $workgroup = defined($::ENV{T3_WORKGROUP})
		? $::ENV{T3_WORKGROUP} : DEFAULT_WORKGROUP;

1;


#
# Subroutines:
#

sub set_workgroup
{
	my ($new_wg) = @_;

	$workgroup = $new_wg;
}

sub initialize
{
	my ($dir) = @_;

	# get ini file parameters
	my $ini_file = "$dir/" . INI_FILE;
	open(INI, $ini_file) or croak("can't get initialization from $ini_file");
	while ( <INI> )
	{
		chomp;
		s/\r$//;								# might be DOS format
		s/;.*$//;								# get rid of comments
		next if /^\s*$/;						# skip blank lines
		my ($var, $val) = /^(.*?)=(.*)$/;
		if ($var eq SERVER_URL_DIRECTIVE)
		{
			$server_url = $val;
		}
		elsif ($var eq USERNAME_DIRECTIVE)
		{
			$username = $val;
		}
		elsif ($var eq CLIENT_TIMEOUT_DIRECTIVE)
		{
			$client_timeout = $val;
		}
	}
	close(INI);
}

sub config_param
{
	my ($directive) = @_;

	return $cfg_file->lookup($workgroup, $directive);
}

sub build_message
{
	my ($from, $to, $status, @messages) = @_;

	# put the lines together
	my $message = join('', @messages);
	# encode special chars
	$message = html_menu::_escape_uri_value($message);
	# windows client apparently doesn't like spaces encoded the "right" way
	$message =~ s/%20/+/g;
	# windows client also apparently doesn't care for not having ^M's
	$message =~ s/%0A/%0D$&/g;

	my $url = $server_url . '<MESSAGE+subject=""+location=""+from="' . $from . '"+to="'
			. $to . '"+status="' . $status . '">' . $message . '</MESSAGE>';
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
