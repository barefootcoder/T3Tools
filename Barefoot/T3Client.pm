#! /usr/bin/perl

###########################################################################
#
# T3Client
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

package T3Client;

### Private ###############################################################

use strict;

use Carp;

use CGI;
use Barefoot::debug;			# comment out for production

use Barefoot::base;
use Barefoot::html_menu;
use Barefoot::config_file;
use Barefoot::T3;

use constant INI_FILE => 't3client.ini';

use constant SERVER_URL_DIRECTIVE => 'server_url';
use constant USERNAME_DIRECTIVE => 'user_name';
use constant CLIENT_TIMEOUT_DIRECTIVE => 'server_refresh_interval';

our $client_timeout;

1;


#
# Subroutines:
#

sub initialize
{
	my ($dir) = @_;

	# error checks
	my $server_found = false;
	my $user_found = false;
	my $timeout_found = false;

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
			$T3::server_url = $val;
			$server_found = true;
		}
		elsif ($var eq USERNAME_DIRECTIVE)
		{
			$T3::username = $val;
			$user_found = true;
		}
		elsif ($var eq CLIENT_TIMEOUT_DIRECTIVE)
		{
			$client_timeout = $val;
			$timeout_found = true;
		}
	}
	close(INI);

	croak "no server url defined in $ini_file\n" unless $server_found;
	croak "no user name defined in $ini_file\n" unless $user_found;
	croak "no server refresh interval in $ini_file\n" unless $timeout_found;
}
