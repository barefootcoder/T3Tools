#! /usr/local/bin/perl

# For RCS:
# $Date$
# $Log$
#
# $Id$
# $Revision$

###########################################################################
#
# html_menu
#
###########################################################################
#
# This package generates rather simple menus in HTML.  The menus are
# expected to be defined in a file provided by the user.  Within this file,
# the following structure is expected:
#
#		# lines beginning with # are comments and are ignored
#		# blank lines are also ignored
#
#		# variables are ways to change the menu's appearance
#		# variables are always optional
#		# the format is VARNAME=VALUE
#		# no whitespace is allowed either preceding or following the =
#		# however, whitespace _is_ allowed in the VALUE
#		# only certain VARNAMES are recognized; those are listed below
#		INDENT=&nbsp;&nbsp;&nbsp;
#		# the value of INDENT is printed once for every "level" deep
#		# the menu has become; so, e.g., a top level menu item does
#		# not have anything printed in front of it, a submenu has INDENT
#		# printed once in front of it, a sub-submenu has INDENT printed
#		# twice in front of it, etc (our example is 3 "hard" spaces)
#		BULLET=(*)
#		# the value of BULLET is printed directly in front of a menu item
#		# (after INDENT) ... it can be text, as in our example, or it
#		# could be something more complicated, like ...
#		BULLET=<IMG SRC="images/menu_bullet.gif" ALIGN="BOTTOM" ALT="bullet">
#		# note that this second definition overrides the first
#		MENU_ATTRIBS=USER,DATABASE
#		# this specifies that when the url's are built for submenu links, the
#		# comma-separated list of attributes given will be "passed through"
#		# (i.e., whatever their value is when the script is called will be
#		# passed to the script when it is reinvoked)
#		EXEC_ATTRIBS=USER,DATABASE
#		# ditto for links that are built for menu executions (see below)
#		EXEC_URL= TARGET="data_frame"
#		# anything that must be put into *every* execute url
#		# if you need something to be in some url's but not others, you
#		# have to specify it in each "exec" action for which it's needed
#		# note that it starts with a space; this is probably what you
#		# want for most applications
#		PASS_MENU_TEXT=MENU_NAME
#		# if you wish the text of the menu item to be passed to all CGI's
#		# that the menu executes, put the attribute name that you want used
#		# as the value of this variable
#		# of course, the value must be a valid URI attribute name
#		# the attribute will be passed to all CGI's, but it may be ignored
#		# the text will be appropriately escaped (space == %20, etc)
#
#		# now the menu items are listed
#		# the top level menu is predefined, and is named _TOP
#		# any submenus must be defined in the file
#		# the order that menu items are listed in is significant: the
#		# items will appear on the menu on that order
#		# it is not necessary, however, to keep all the items for a given
#		# menu together (see examples)
#
#		_TOP:Configuration:menu CONFIG
#		_TOP:Edit:menu EDIT
#		_TOP:Calculate:menu CALC
#		# menu items are defined by menu name, menu text (which will be the
#		# link), and the action that the link will perform
#		# in this menu, all the items are defined together
#		# each menu item will call a submenu when its link is clicked
#		# although our example only defines the CONFIG menu, in a real
#		# file, the EDIT and CALC menus would also have to be defined
#
#			CONFIG:Change Printer:execute printer.cgi
#			# note that leading whitespace is stripped
#			# this menu item will execute a different CGI when it is clicked
#			CONFIG:Set Options:menu OPT
#				OPT:Change user:execute user.cgi
#				OPT:Change form colors:execute color.cgi?ACTION=form
#				# note that the execute link can have parameters
#				OPT:Change background colors:execute color.cgi?ACTION=bg
#				OPT:Change options for current database:execute db.cgi?DB=$DB
#				# if you need to pass a CGI parameter to only one execute
#				# action, you can use a dollar sign and the parameter name
#				# (if you need to pass it to all actions, use EXEC_ATTRIBS)
#				OPT:Change screen resolution:raw_execute screen.exe
#				# a raw_execute program is _not_ passed any extra parameters
#				# specified by EXEC_URL, EXEC_ATTRIBS, or PASS_MENU_TEXT;
#				# other than that, it is identical to "execute"
#			CONFIG:Set refresh time:execute refresh.cgi
#			# note that the OPT menu is defined right in the middle of the
#			# CONFIG menu ... this is okay
#
# For each menu item that refers to a submenu, clicking on the link will
# reinvoke the script.  Upon reinvokation, that submenu will be expanded.
# If the link is clicked again, the submenu will be collapsed upon
# reinvokation.  For each menu item that refers to an execution, the program
# or web page will be executed when the link is clicked.
#
# In order to make all this functional, the calling script has to abide by a
# few rules.  First, it is expected to instantiate a CGI.pm object (which it
# should do anyway, since it is also expected to handle the HTML header and
# <BODY> opening and closing).  Secondly, it is expected to figure out its
# own name so that html_menu.pm knows how to reinvoke itself (this could be
# accomplished with either the url() or self_url() method of CGI.pm, for
# example).  Here is a simplistic example of how html_menu might be used:
#
#		use CGI;
#		use html_menu;
#		my $cgi = new CGI;
#		print $cgi->header();
#		# code to print any HTML elements which precede the menu
#		html_menu::display("menu.dat", $cgi, $cgi->url() . "?");
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 1999 Barefoot Software.
#
###########################################################################

package html_menu;

### Private ###############################################################

use strict;

use CGI;


my %menus;									# lists of menus
my %menuconfig;								# configuration variables
my @display_list;							# submenus to be expanded

1;


#
# Subroutines:
#


sub _escape_uri_value
{
	my ($value) = @_;
	return "" unless defined $value;

	# the search is a negated char class containing the only valid chars
	# the replacement is an expression to turn the char into a hex string
	$value =~ s/[^A-Za-z0-9_.!~*()-]/'%' . sprintf('%x',ord($&))/eg;
	return $value;
}

sub _read_menufile
{
	my ($filename) = @_;

	open(MENU, $filename) or die("can't open menu file");
	ITEM: while ( <MENU> )
	{
		chomp;									# kill trailing newline
		s/^\s*//;								# remove leading whitespace
		next ITEM if /^$/;						# skip blank lines
		next ITEM if /^#/;						# skip comments

		# check for variable
		if (/^(\w+?)=(.*)/)
		{
			my $varname = $1;
			my $value = $2;
			$menuconfig{$varname} = $value;

			next ITEM;
		}

		my ($menuname, $text, $action) = split(':');
		my $menu = {
			name	=>	$menuname,
			text	=>	$text,
			action	=>	$action,
		};
		push @{$menus{$menuname}}, $menu;
	}
	close(MENU);

	die("no top level menu") unless exists $menus{_TOP};
}

sub _display_menu
{
	my ($cgi, $self_url, $menuname, $level, @menu_list) = @_;
	$level = 0 if !defined($level);

	my $menulist = $menus{$menuname};
	foreach my $menu (@$menulist)
	{
		my ($type, $result) = split(' ', $menu->{action}, 2);

		# allow substitution of parameter names with dollar sign
		$result =~ s/\$(\w+)/ _escape_uri_value($cgi->param($1)) /eg;

		print $menuconfig{INDENT} x $level, $menuconfig{BULLET}, " ";

		# need to figure out whether menu is already expanded
		my $expanded = grep {$_ eq $result} @display_list;

		if ($type eq 'menu')
		{
			# only add submenu to display list if not already expanded
			print " <A HREF=${self_url}DISPLAY_SUBS=",
					join(",", @menu_list, $expanded ? () : $result);
			if (exists $menuconfig{MENU_ATTRIBS})
			{
				my @attribs = split(',', $menuconfig{MENU_ATTRIBS});
				foreach my $attrib (@attribs)
				{
					print "&$attrib=", _escape_uri_value($cgi->param($attrib));
				}
			}
			print ">";
			print $menu->{text}, "</A><BR>\n";

			# now check if this submenu needs to be displayed
			# see if the submenu is in the display list
			if ($expanded)
			{
				# it is, so display it
				_display_menu($cgi, $self_url,
						$result, $level + 1, @menu_list, $result);
			}
		}
		elsif ($type eq 'execute' or $type eq 'raw_execute')
		{
			print " <A HREF=$result";
			unless ($type eq 'raw_execute')
			{
				my @attribs;
				if (exists $menuconfig{PASS_MENU_TEXT})
				{
					push @attribs, $menuconfig{PASS_MENU_TEXT} . "=" .
							_escape_uri_value($menu->{text});
				}
				if (exists $menuconfig{EXEC_ATTRIBS})
				{
					foreach my $attrib (split(',', $menuconfig{EXEC_ATTRIBS}))
					{
						my $value = _escape_uri_value($cgi->param($attrib));
						push @attribs, "$attrib=$value";
					}
				}
				print join('&', @attribs);
				print $menuconfig{EXEC_URL} if exists $menuconfig{EXEC_URL};
			}
			print ">", $menu->{text}, "</A><BR>\n";
		}
	}
}

sub display
{
	my ($filename, $cgi, $self_url) = @_;

	# get the menus and their actions from the menu data file
	_read_menufile($filename);

	# build the display list by parsing the DISPLAY_SUBS parameter
	@display_list = split(',', $cgi->param('DISPLAY_SUBS'));

	# start it off by displaying the top level menu
	_display_menu($cgi, $self_url, '_TOP');
}
