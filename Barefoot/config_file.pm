#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# config_file
#
###########################################################################
#
# This module handles config files of the style currently used by Apache
# and many other programs.  The basic format is described below.
#
#		# comments begin with pound
#
#			# blank lines and leading whitespace are ignored
#
#		GlobalOption		value
#
#		<Section>
#			SectionOption		value
#		</Section>
#
#		<AnotherSection>
#			<NestedSection>
#				SectionOption		value
#			</NestedSection>
#		</AnotherSection>
#
# Note that the option names can be the same as long as they are in different
# sections.  The same is true of nested sections.  Sections can be nested
# as deeply as desired.  If two sections or options at the same level of
# nesting are given the same name, the second will override the first.
#
# To parse the file, call read() with an argument of the filename.  After
# this, use the returned object with the lookup() function to retrieve
# the values.  Here's an example which would retrieve each of the values
# in the file show above:
#
#		my $cfg = config_file->read("foo.conf");
#		my $val1 = $cfg->lookup("GlobalOption");
#		my $val2 = $cfg->lookup("Section", "SectionOption");
#		my $val3 = $cfg->lookup("AnotherSection", "NestedSection",
#				"SectionOption");
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package config_file;

### Private ###############################################################

use strict;

use Carp;

1;


#
# Subroutines:
#

sub read
{
	my ($class, $filename) = @_;

	my $this = {};
	bless $this, $class;

	my (@namestack, @valstack);
	my $cursec = "";
	open(CFG, $filename) or croak("cannot open config file $filename");
	while ( <CFG> )
	{
		chomp;
		# remove leading spaces
		s/^\s+//;
		# ditch comments
		s/#.*$//;
		# throw away blank lines
		next if /^\s*$/;

		# end of a section; check for error and pop the old hash
		# (have to check for closing tag before opening)
		if ( /<\/(.*?)>/ )
		{
			croak("mismatched closing tag $1") unless $cursec eq $1;
			$cursec = pop @namestack;
			$this = pop @valstack;
		}

		# a new section; push the old hash and set to a new one
		elsif ( /<(.*?)>/ )
		{
			push @valstack, $this;
			push @namestack, $cursec;
			$cursec = $1;
			$this->{$cursec} = {} unless exists $this->{$cursec};
			$this = $this->{$cursec};
		}

		# option with optional value; store it
		elsif ( /(.*?)\s+(.*)?/ )
		{
			$this->{$1} = $2;
		}

		# don't know what this is; shouldn't be possible
		else
		{
			croak("unrecognized line: $_");
		}
	}
	close(CFG);

	return $this;
}

sub _print
{
	my $this = shift;
	_print_level($this, 0);
}

sub _print_level
{
	my ($level, $count) = @_;
	foreach my $key (keys %$level)
	{
		print "\n", "\t" x $count, $key;
		if (ref $level->{$key})
		{
			_print_level($level->{$key}, $count + 1);
		}
		else
		{
			print "=$level->{$key}\n";
		}
	}
}

sub lookup
{
	my $this = shift;

	my $curlevel = $this;
	while (@_)
	{
		my $section_or_option = shift;
		croak("section or option $section_or_option does not exist")
				unless exists $curlevel->{$section_or_option};
		$curlevel = $curlevel->{$section_or_option};
	}
	croak("can't get value for section") if ref $curlevel;
	return $curlevel;
}
