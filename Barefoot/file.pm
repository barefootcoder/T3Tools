#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# file
#
###########################################################################
#
# A few useful file functions
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package file;

### Private ###############################################################

use strict;

use Carp;
use FileHandle;
use IO::Seekable;
use Fcntl ':flock';

use constant LOCK_HANDLE_CLASS => "file::lock_handle";

use constant FASTIO_FIELD_DELIM => "\cC";
use constant FASTIO_RECORD_DELIM => "\cD";

1;


#
# Subroutines:
#

# get a handle to a locked (via flock()) file
# you can then use get() (below) to retrieve the contents of the file,
# and also store() to put the contents back ... because this is the expected
# use, the file is locked exclusively ... feel free to read to or write from
# the handle yourself, but you probably shouldn't mix such hubris with get()
# and store()
# for this call, you may also optionally specify a timeout ... if you don't
# give one, it will probably block until the lock is achieved
sub open_lock
{
	my ($filename, $timeout) = @_;

	my $fh = new FileHandle("+<$filename");
	my $got_lock = 0;
	if ($timeout)
	{
		my $give_up = time() + $timeout;
		while (time() < $give_up)
		{
			if (flock($fh, LOCK_EX | LOCK_NB))
			{
				$got_lock = 1;
				last;
			}
			sleep 1;
		}
	}
	else
	{
		flock($fh, LOCK_EX);
		$got_lock = 1;
	}

	if ($got_lock)
	{
		bless $fh, LOCK_HANDLE_CLASS;
		return $fh;
	}
	else
	{
		$fh->close();
		return undef;
	}
}

# return entire contents of given file
# if used in a scalar context, entire file is one string
# if used in an array context, uses $/ to read "lines"
# can also provide an alternate delimiter as second argument
# note: if used in a scalar context, any second arg is ignored
# the first argument may either be a filename, or a handle returned by
# open_lock()
sub get
{
	my ($filename, $handle);
	if (ref($_[0]) eq LOCK_HANDLE_CLASS)
	{
		$handle = shift;
	}
	else
	{
		$filename = shift;
	}
	my ($delim) = @_;
	local $/ = $delim if wantarray and defined($delim);
	local $/ = undef if not wantarray;

	my ($contents, @contents);
	if ($filename)
	{
		$handle = new FileHandle;
		$handle->open($filename) or croak("can't open file $filename");
	}
	else							# must be a lock handle
	{
		seek($handle, 0, SEEK_SET);
	}
	wantarray ? (@contents = <$handle>) : ($contents = <$handle>);
	if ($filename)					# not a lock handle, needs to be closed
	{
		$handle->close() or croak("can't close input file $filename");
	}

	return wantarray ? @contents : $contents;
}

# same thing, only using flock() to signal the read to another process
# note that unlike using open_lock() followed by get(), get_lock() provides
# a shared lock ... also, get_lock() currently doesn't accept a timeout value
# naturally, it doesn't make sense to call open_lock() followed by get_lock()
# (so don't do that)
sub get_lock
{
	my ($filename, $delim) = @_;
	local $/ = $delim if wantarray and defined($delim);
	local $/ = undef if not wantarray;

	my ($contents, @contents);
	open(IN, $filename) or croak("can't open file $filename");
	flock(IN, LOCK_SH);
	wantarray ? (@contents = <IN>) : ($contents = <IN>);
	flock(IN, LOCK_UN);				# close() should do this, but let's be safe
	close(IN) or croak("can't close input file $filename");

	return wantarray ? @contents : $contents;
}

# the opposite of get (natch)
# uses _no_ delimiter when printing (i.e., ignores $\)
# returns whatever print returns (which means no one will ever check it)
# note that if you open_lock() (and presumably get()) then store(), the handle
# will be closed and isn't any more use ... so make sure store() is the
# last thing you do ... which makes sense if you think about it:
#		my $lh = file::open_lock("somefile");
#		my @contents = file::get($lh);
#		# change @contents in some way
#		file::store($lh, @contents);
#		# all done now
sub store
{
	my ($filename, $handle);
	if (ref($_[0]) eq LOCK_HANDLE_CLASS)
	{
		$handle = shift;
	}
	else
	{
		$filename = shift;
	}
	my (@contents) = @_;

	if ($filename)
	{
		$handle = new FileHandle;
		$handle->open(">$filename") or croak("can't write to file $filename");
	}
	else							# must be a lock handle
	{
		# jump back to beginning and truncate so new contents will overwrite
		# (even if they're shorter than the old contents)
		seek($handle, 0, SEEK_SET);
		truncate($handle, 0);
	}
	my $success = print $handle @contents;
	# close will automatically release the lock, if there is one
	close($handle) or croak("can't close output file $filename");

	return $success;
}

# the opposite of get_lock (natch)
# again, no way to timeout the lock
# like get_lock(), don't use store_lock() with open_lock()
# basically, store_lock() isn't nearly as useful as the combination of
# open_lock(), get(), and store()
sub store_lock
{
	my ($filename, @contents) = @_;

	open(OUT, ">$filename") or croak("can't write to file $filename");
	flock(OUT, LOCK_EX);
	my $success = print OUT @contents;
	flock(OUT, LOCK_UN);			# again, close() should do it, but ...
	close(OUT) or croak("can't close output file $filename");

	return $success;
}

# just like store_lock, but appends instead of replaces the file
# again, no way to timeout the lock
sub append_lock
{
	my ($filename, @contents) = @_;

	open(OUT, ">>$filename") or croak("can't append to file $filename");
	flock(OUT, LOCK_EX);
	seek(OUT, 0, SEEK_END);			# in case of append while we were waiting
	my $success = print OUT @contents;
	flock(OUT, LOCK_UN);			# again, close() should do it, but ...
	close(OUT) or croak("can't close append file $filename");

	return $success;
}


# FAST IO FUNCTIONS
# these functions are based on the concept that simpler is faster
# the speed is predicated on several things:
#	a) the delimiters (constants above) will be single characters
#	b) you will precheck your data for conflicts with the delimiters
#	c) you will force your data into some reasonable field/record format
#	d) you don't need "column names" (i.e., field order is significant)
#	e) you will read and write your data sequentially, or append data
#	f) you don't mind the fact that the data is unintelligible to less or vi
# if you agree to all these things, these functions are pretty fast for
# raw data transfers

# this function preps an array for fast IO printing
sub fastio_make_record
{
	return join(FASTIO_FIELD_DELIM, @_) . FASTIO_RECORD_DELIM;
}

# this function just calls append_lock and fastio_make_record for you
sub fastio_append_record
{
	my ($filename, @contents) = @_;

	return append_lock($filename, fastio_make_record(@contents));
}
