#! /usr/local/bin/perl -w

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::DataStore::display
#
###########################################################################
#
# The display() function accepts a file which contains mostly basic SQL
# commands, with the possible addition of some more sophisticated formatting
# options, and produces a string which is (hopefully) ready for printing.
#
# Example:
#
#		print DataStore::display($ds, $filename);
#
# #########################################################################
#
# In general, the file is processed moderately simply.  Blank lines (this
# includes lines containing only whitespace) are ignored in every case
# except the &print command (see below).  From the first occurence of a #
# to the end of that line is considered a comment, and is removed, except
# in the ->format section (see below).  A semicolon on a line by itself,
# or on a line with nothing other than whitespace, terminates the current
# command in every case (no exceptions).
#
# There are several kinds of commands allowed in the file.  Here are some
# examples:
#
#			select *
#			from my_table
#			;
#
# This is a simple SQL query.  Since there is no ->format section, you
# will get default output: for select's, a simple double header row (column
# names followed by dashes), each row lined up with the headers, and a
# footer row like: "(6 rows returned)"; for insert's, update's, and delete's,
# a single row like: "(6 rows affected)".  If the data store returns an
# error, the error is output instead.  The width of a column is the width
# of its largest data memeber, or its header, whichever is longer.  All
# columns are left justified and no attempt is made to line up decimals
# or reformat dates.
#
# To get more control over the output of a select, you could do this:
#
#			select *
#			from my_table
#		->format
#			H->@<<<  @|||  @>>>>
#			H->----  ----  =====
#			B->@<<<  @|||  @#.##
#			F=>(%R rows)
#		;
#
# The ->format introduces a section which lasts up until the terminating
# semicolon.  A format consists of three subsections: H (header), B (body),
# and F (footer).  The body format is output once for every row of output;
# the others are output once only.  If any of the three subsections is
# omitted, there will be no output for that section.  For each subsection,
# you may describe the output in one of three ways: -> (a Perl format with
# default values), -> followed by /> (a Perl format with specified values),
# or => (a "literal" which will allow some simple substitutions).  A ->
# or => line extends from the next character after the > up to (and
# including) the newline (which means it's not possible to specify format
# lines that don't end in newlines).  Multiple lines beginning with the
# same characters (like the two H-> lines above) get concatenated together,
# but don't try to mix and match types (for instance, a H-> and H=> in the
# same ->format section wouldn't work, but obviously -> and /> are the
# exception).  Completely blank lines are ignored, as they are almost
# everywhere else, but you can get a blank line in your format by just
# putting the intro characters on a line by themselves.  For instance, this
# would give you a blank line between the data rows and the main footer
# row:
#
#			select *
#			from my_table
#		->format
#			H->@<<<  @|||  @>>>>
#			H->----  ----  =====
#			B->@<<<  @|||  @#.##
#			F=>
#			F=>(%R rows)
#		;
#
# The /> lines are parsed differently: whitespace is completely ignored,
# and the line is split on commas into fields.  Each field could be a
# literal in quotes (for instance, having a "@" in the field list is the
# only way to get a literal @ in your format line, as is true in Perl
# itself).  More likely, it is a database field, which is a % followed by
# either a number or a name which indicates which column from the select
# statement you want.  In the header, database fields get replaced by the
# column names (which makes %name type fields somewhat useless there); in
# the body, database fields get replaced by the values of the columns.
# Using database fields in the footer is an error.  There is also a special
# field, %R, which represents the total number of rows in either the header
# or footer, or the current row number in the body.  These fields may be
# used in /> lines or => lines.  When using -> lines, however, it is
# extremely common that your /> line will consist of %1, %2, %3 etc until
# all fields are exhausted.  Since this is the most common case, it is the
# default: a -> line with no following /> line acts in this way (except in
# footer subsections, where that wouldn't make any sense).  However, if you
# wanted to add the row number to the body, you'd need to specify all the
# fields.  Here is an example:
#
#			select *
#			from my_table
#		->format
#			H-> #  @<<<  @|||  @>>>>
#			H->--- ----  ----  =====
#			B->@>> @<<<  @|||  @#.##
#			B/>%R,  %1,   %2,   %3
#			F=>(%R rows)
#		;
#
# Note that the whitespace between the database fields is irrelevant to the
# parsing, and that the header is still using the default values.
#
# While ->format sections are generally only useful for select statements,
# you could use a F=> subsection to change the output of an insert, update,
# or delete.  Header and body subsections in non-select's are ignored.
#
# Sometimes you may not want to see any output at all if there are no rows
# in the data.  With or without a ->format, you would still see the header
# and footer lines (unless you have a ->format that has no header or footer).
# If this is undesireable, you may use something like the following:
#
#			select *
#			from my_table
#		->suppress_empty
#		;
#
# This would work with a ->format section as well.
#
# If you just need to print some text, with no SQL involved, you can use a
# &print command, as follows:
#
#			&print Here is some text
#
# This is the one time you do not need a semicolon terminator.  Any
# whitespace between the &print and the text, or between the text and the
# newline is stripped; whitespace inside the text, and the newline itself,
# are preserved.  If you need to print more than one line at a time, you
# may do this:
#
#			&print
#				This gets printed exactly, including leading whitespace.
#				Trailing whitespace would be preserved as well.
#
#				There is a blank line above this.
#			;
#
# Note that this is the only time that blank lines are preserved.  Do not
# try to mix these methods; the example below yields an error.
#
#			&print Some text here ...
#				And more down here ...
#				This is an error.
#			;
#
# You can call "stored procedures" by using the &proc command:
#
#			&proc my_procedure
#
#				where something
#
#			;
#
# All stored procedures take a chunk of text, which they typically interpret
# as a piece of a SQL query.  Whatever text they return is output.  Some
# stored procedures are contained in DataStore::procs (which see), but others
# may be added by your own modules.  The key is that they must "register"
# themselves with the DataStore (see DataStore/procs.pm for examples).
#
# You can have the parser ignore large chunks of text like this:
#
#			&ignore
#
#				# here's some old SQL we don't want to run any more,
#				# but we don't want to get rid of it either
#				select *
#				from my_table
#			;
#
# Don't forget that # comments get stripped out by the parser.  Comments
# such as /* */ surrounded comments would get passed on to the SQL query
# (or & command, if they were inside one of those).  But a terminator is
# absolute, so this is going to get you into trouble:
#
#			/*
#				select *
#				from my_table
#				;
#			*/
#
# Best to stick with # comments only if you can.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

package DataStore;

### Private ###############################################################

use strict;

# don't try to turn on debugging here; do it in DataStore.pm instead

use Barefoot::base;
use Barefoot::range;
use Barefoot::string;
use Barefoot::format;
use Barefoot::DataStore;
use Barefoot::T3::TimerProcs;
use Barefoot::DataStore::procs;


our %format_place =
(
	H	=>		'header',
	B	=>		'body',
	F	=>		'footer',
);

our %format_type =
(
	'-'	=>		'format',
	'='	=>		'literal',
	'/'	=>		'values',
);


1;


#
# Subroutines:
#


# the main event
# (helper routines are below)
sub display
{
	my ($ds, $filename) = @_;

	croak("cannot display with no data store")
			unless $ds and $ds->isa("DataStore");

	my ($display, $query, $command, $command_arg) = ("", "", "", "");
	my $format = {};
	my $exact = false;
	my $if_status = -1;

	CORE::open(IN, $filename) or croak("display: cannot open file $filename");
	while ( <IN> )
	{
		# remove comments unless in format
		s/ \# .* $ //x unless exists $format->{output};
		# skip blank lines unless exact mode is on
		next if /^\s*$/ and not $exact;

		if ( / ^ \s* ; \s* $ /x )			# end of query or command arg
		{
			# not allowed to terminate a command inside a conditional
			_fatal("found terminator before endif") unless $if_status == -1;

			if ($command)					# must be end of command arg
			{
				$display .= $command->($ds, $command_arg);
				$command = "";				# reset command
			}
			else							# must be end of query
			{
				# get output unless entire query is blank
				$display .= _process($ds, $query, $format)
						unless $query =~ /^\s*$/;
				$display .= "\n" unless substr($display, -2) eq "\n\n";
				$query = "";				# reset the query
			}
			$exact = false;					# reset exact mode
			$format = {};					# reset format itself
			next;
		}

		print STDERR "about to check $_ for conditional\n" if DEBUG >= 5;
		if ( / ^ \s* { \s* if \s+ ( ! | (?:not \s) )? \s* (\w+) \s* } \s* $ /x )
		{
			# can't start an if inside another if
			_fatal("cannot nest conditionals") unless $if_status == -1;

			my $negative = defined $1;
			my $varname = $2;
			print STDERR "doing conditional on $varname\n" if DEBUG >= 2;

			$if_status = exists $ds->{vars}->{$varname};
			$if_status = not $if_status if $negative;
			next;
		}

		if ( / ^ \s* { \s* endif \s* } \s* $ /x )
		{
			# can't allow endif's without an if
			_fatal("endif outside of conditional") if $if_status == -1;

			$if_status = -1;
			next;
		}

		# if_status must either be true (1) or not applicable (-1)
		next unless $if_status;

		if (exists $format->{output})
		{
			_fatal("illegal format line") unless / ^ \s* ([HBF]) ([=-]) > /x;

			my $place = $format_place{$1};
			my $type = $format_type{$2};

			# remove leader which tells us where and what kind of format it is
			s/$&//;

			# check for "shorcuts"
			# for instance @<x20 turns into @<<<<<<<<<<<<<<<<<<<
			# (note that 20 is the total length of the field, and
			# *not* the number of < characters)
			s/\@(.)x(\d+)/ '@' . $1 x ($2 - 1) /eg;

			$format->{ "${place}_${type}" } .= $_;
			next;
		}

		# check for output options
		if ( / ^ \s* ->(\w+) \s* $ /x )
		{
			if ($1 eq 'format')
			{
				# make sure we have a query happening
				# (formats should be between the main SQL of the query
				# and the terminating semicolon)
				_fatal("can't create a format with no query pending")
						if $query =~ /^\s*$/;

				$format->{output} = true;
			}
			elsif ($1 eq 'suppress_empty')
			{
				$format->{suppress_empty} = true;
			}
			else
			{
				_fatal("unknown output option $1");
			}
			next;
		}

		# only check for special commands if $query is blank
		print STDERR "line is $_ and query is $query\n" if DEBUG >= 4;
		if ( / ^ \s* & (\w+) (?: \s+ (.*?) )? \s* $ /x and not $query )
		{
			# again, can't start a command inside a conditional
			_fatal("can't call a command inside a conditional")
					unless $if_status == -1;

			$command = $1;
			print STDERR "processing command $command\n" if DEBUG >= 2;

			# each command is potentially different, so figure out which one
			if ($command eq 'proc')
			{
				print STDERR "proc is $2\n" if DEBUG >= 2;

				# $2 should be our proc name, so let's double check that
				_fatal("unknown procedure call: $2")
						unless exists $DataStore::procs->{$2};

				# okay, now we'll need the SQL clause for this procedure,
				# so we'll let the loop build up $command_arg and then
				# call it
				$command = $DataStore::procs->{$2};
			}
			elsif ($command eq 'print')
			{
				# there are two possibilities here:

				# 1) single line print
				# Ex:	&print some text
				if ($2)
				{
					$display .= "$2\n";
					$command = "";
				}
				# 2) multi-line print
				# Ex:	&print
				#		some text
				#		;
				else
				{
					$exact = true;			# preserve blank lines
					$command = sub
						{
							# have to hand this to the data store
							# for translation of variables, schemas, etc
							my ($ds, $message) = @_;
							return $ds->_transform_query($message);
						};
				}
			}
			elsif ($command eq 'ignore')
			{
				# we want to ignore everything up until the next ;
				# so we'll just let it collect in $command_arg,
				# and provide a "do nothing" subroutine to call
				$command = sub { return "" };
			}
			else
			{
				_fatal("unknown command: $command");
			}

			# if we get this far, that means somebody wants to build up
			# $command_arg.  so we'll reset it and then loop around again
			$command_arg = "";
			next;
		}

		# if we've survived this far, we need to tack the current line onto
		# something.  if there's a current command, tack it onto the command
		# argument.  otherwise, tack it onto the query
		if ($command)
		{
			$command_arg .= $_;
		}
		else
		{
			$query .= $_;
		}
	}
	close(IN);

	return $display;
}


#####
# Helper Routines
#####


# handle fatal errors in mini-parser
sub _fatal
{
	my ($msg) = @_;

	croak("display: $msg (line $.)");
}


# got a query, now handle it
sub _process
{
	my ($ds, $query, $format) = @_;

	my $res = $ds->do($query);
	return $ds->last_error() unless $res;

	if (not $res->{sth}->{NUM_OF_FIELDS})	# it's not a select query
	{
		# rows_affected will return "0E0" (zero-but-true) if there was
		# no error, but zero rows; we'll add 0 to that to make it just "0"
		my $rows = $res->rows_affected() + 0;

		return "" if exists $format->{suppress_empty} and $rows == 0;
		if (exists $format->{output})
		{
			return _build_footer($rows, undef, undef, $format);
		}
		else
		{
			return $rows == -1 ? "" : "($rows rows affected)\n";
		}
	}

	# loop through columns and get names
	my @colnames = ();
	my @widths = ();
	my $numcols = $res->num_cols();
	for (my $x = 0; $x < $numcols; ++$x)
	{
		my $name = $res->colname($x);
		push @colnames, $name;
		# we only need to collect widths if there's no format
		push @widths, [ length($name) ] unless exists $format->{output};
	}

	# loop through rows and get data
	my $rowcount = 0;
	my @rows = ();
	while ($res->next_row())
	{
		my @cols = $res->all_cols();
		# again, only collect widths if there's no format
		unless (exists $format->{output})
		{
			for (my $x = 0; $x < $numcols; ++$x)
			{
				push @{$widths[$x]}, length($cols[$x]) if $cols[$x];
			}
		}
		push @rows, [ @cols ];
	}
	continue
	{
		++$rowcount;
	}

	if (exists $format->{suppress_empty})
	{
		return "" if @rows == 0;
		delete $format->{suppress_empty};
	}

	# get header rows
	my $output = "";
	$output .= _build_header(\@colnames, \@widths, $format);

	# get data rows
	$output .= _build_body(\@rows, \@widths, $format);

	# get footer row(s)
	$output .= _build_footer($rowcount, \@colnames, \@widths, $format);

	return $output;
}


sub _build_header
{
	my ($colnames, $colsizes, $format) = @_;

	my $header = "";
	if (exists $format->{output})
	{
		if (exists $format->{header_format})
		{
			$header = swrite($format->{header_format}, @$colnames);
		}
		elsif (exists $format->{header_literal})
		{
			$header = $format->{header_literal};

			if ( $header =~ /%default\n/ )
			{
				_fatal("cannot specify default header without a -> style "
						. "body format") unless exists $format->{body_format};

				my $top_line = $format->{body_format};
				my $bottom_line = $format->{body_format};

				my $start_pos = 0;
				foreach my $name (@$colnames)
				{
					last unless substr($top_line, $start_pos)
							=~ / \@ ( <+ | >+ | \|+ | [#.]+ ) /x;
					$start_pos = $start_pos + $-[0];
					my $len = length($&);
					my $namelen = length($name);

					substr($top_line, $start_pos, $len) =
							$namelen > $len
								? substr($name, 0, $len)
								: $name . ' ' x ($len - $namelen);
					substr($bottom_line, $start_pos, $len) = '-' x $len;

					$start_pos += $len;
				}

				$header =~ s/%default\n/$top_line$bottom_line/;
			}
		}
	}
	else
	{
		my ($nameline, $separator_line) = ("", "");
		for (my $x = 0; $x < @$colnames; ++$x)
		{
			my $width = range::max(@{$colsizes->[$x]});
			$colsizes->[$x] = $width;

			$nameline .= " " if $x;
			$separator_line .= " " if $x;
			$nameline .= string::pad($colnames->[$x], $width);
			$separator_line .= "-" x $width;
		}
		$header = "$nameline\n$separator_line\n";
	}

	return $header;
}

sub _build_body
{
	my ($colvalues, $colsizes, $format) = @_;

	my $body = "";
	foreach my $row (@$colvalues)
	{
		if (exists $format->{output})
		{
			if (exists $format->{body_format})
			{
				$body .= swrite($format->{body_format}, @$row);
			}
			elsif (exists $format->{body_literal})
			{
				my $line = $format->{body_literal};

				# there's a few acrobatics we have to go through to make
				# sure this doesn't blow up if the field contains a string
				# which looks like a field specifier:
				# basically, pos() contains the position in the string
				# where the next match will pick up.  however, modifying
				# the string resets pos().  therefore, we set it ourselves,
				# to the point at the end of our substitute string
				while ( $line =~ /%(\d+)/g )
				{
					# have to subtract one because %1 is $row->[0]
					my $col_value = $row->[$1 - 1];

					my $start_back_pos = pos($line)
							+ (length($col_value) - length($&));
					$line =~ s/$&/$col_value/;
					pos($line) = $start_back_pos;
				}

				$body .= $line;
			}
		}
		else
		{
			for (my $x = 0; $x < @$colsizes; ++$x)
			{
				$body .= " " if $x;
				$body .= string::pad($row->[$x], $colsizes->[$x]);
			}
			$body .= "\n";
		}
	}

	return $body;
}


sub _build_footer
{
	my ($rowcount, $colnames, $colsizes, $format) = @_;

	if (exists $format->{output})
	{
		if (exists $format->{footer_literal})
		{
			my $footer = $format->{footer_literal};
			$footer =~ s/\%R/$rowcount/g;
			return $footer;
		}
	}
	else
	{
		return "($rowcount rows returned)\n";
	}
}
