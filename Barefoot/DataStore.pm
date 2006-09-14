###########################################################################
#
# Barefoot::DataStore
#
###########################################################################
#
# This package provides a moderately thin layer around DBI to aid in
# RDBMS independence and legibility.  SQL passed through a DataStore
# is trivially translated for some simple substitutions.  Server name
# and database name, as well as any other connection parameters, are
# saved as a permanent part of the data store.  Once the data store is
# created, all the user needs is a data store name and a user name.
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2002-2006 Barefoot Software, Copyright (c) 2004-2006 ThinkGeek
#
###########################################################################

package DataStore;

### Private ###############################################################

use strict;
use warnings;

use DBI;
use Carp;
use Storable;

use Barefoot;
use Barefoot::exception;
use Barefoot::DataStore::DataSet;


use constant EMPTY_SET_OKAY => 'EMPTY_SET_OKAY';

use constant PASSWORD_FILE => '.dbpasswd';

my $HASH_PH = qr/(?:\(\s*)?\Q???\E(?:\s*\))?/;
my $ARR_PH = $HASH_PH;
my $VAR_VALUE = qr/^\{.+\}$/;


# load_table is just an alias for load_data
# it's just there for people who feel more comfortable matching it up
# with replace_table and append_table
*load_table = \&load_data;


our $data_store_dir = DEBUG ? "." : "/etc/data_store";

our $base_types =
{
		Sybase		=>	{
							date		=>	'datetime',
							boolean		=>	'numeric(1)',
						},
		Oracle		=>	{
							int			=>	'number(10)',
							boolean		=>	'number(1)',
							money		=>	'number(19,4)',
							text		=>	'varchar2(2000)',
						},
		mysql		=>	{
							money		=>	'decimal(17,2)',
							boolean		=>	'bool',
						},
};

our $column_attributes =
{
		mysql		=>	{
							identity	=>	'not null auto_increment',
						},
};

our $constants =
{
		Sybase		=>	{
							BEGINNING_OF_TIME	=>	"1/1/1753",
							END_OF_TIME			=>	"12/31/9999",
						},
		Oracle		=>	{
							BEGINNING_OF_TIME	=>	"01-JAN-0001",
							END_OF_TIME			=>	"31-DEC-9999",
						},
		mysql		=>	{
							BEGINNING_OF_TIME	=>	"1000-01-01",
							END_OF_TIME			=>	"9999-12-31",
						},
};

our $funcs =
{
		Sybase		=>	{
							curdate			=>	sub { "getdate()" },
													# "dateadd(hour, 1,
													# 		getdate())"
													# },
							ifnull			=>	sub { "isnull($_[0], $_[1])" },
							drop_index		=>	sub {
													"drop index $_[0].$_[1]"
												},
							place_on		=>	sub { "on $_[0]" },
						},
		Oracle		=>	{
							curdate			=>	sub { "sysdate" },
							ifnull			=>	sub { "nvl($_[0], $_[1])" },
							drop_index		=>	sub { "drop index $_[1]" },
							place_on		=>	sub { "tablespace $_[0]" },
						},
		mysql		=>	{
							curdate			=>	sub { "curdate()" },
							ifnull			=>	sub { "ifnull($_[0], $_[1])" },
							drop_index		=>	sub {
													"drop index $_[1] on $_[0]"
												},
							# no way to really implement this one AFAIK
							place_on		=>	sub { '' },
						},
};

our $procs = {};				# we don't use this, but someone else might

our %_query_cache;				# this is only used by _transform_query


#
# Subroutines:
#


# helper methods


sub _login
{
	my $this = shift;

	if (exists $this->{config}->{connect_string})
	{
		my $server = $this->{config}->{server};
		debuggit(3 => "attempting to get password for server", $server, "user", $this->{user});

		debuggit(4 => "environment for dbpasswd: user", $ENV{USER}, "home", $ENV{HOME}, "path", $ENV{PATH});
		my $passwd;
		my $pwerror = "";
		try
		{
			$passwd = get_password($server, $this->{user});
		}
		catch
		{
			$pwerror = " ($_)";
		};
		croak("can't get db password" . $pwerror) unless defined $passwd;

		# connect to database via DBI
		# note that some attributes to connect are RDBMS-specific
		# this is okay, as they will be ignored by RDBMSes they don't apply to
		debuggit(4 => "connecting via:", $this->{config}->{connect_string});
		$this->{dbh} = DBI->connect($this->{config}->{connect_string},
				$this->{user}, $passwd,
				{
					PrintError => 0,
					# Sybase specific attributes
					syb_failed_db_fatal => 1,
					syb_show_sql => 1,
				});
		croak("can't connect to data store as user $this->{user}")
				unless $this->{dbh};
		debuggit(5 => "successfully connected");

		if (exists $this->{initial_commands})
		{
			foreach my $command (@{$this->{initial_commands}})
			{
				debuggit(1 => "now trying to perform command: $command");
				my $res = $this->do($command);
				debuggit(1 => "results has", $res->{rows}, "rows");
				debuggit(1 => "last error was", $this->{last_err});
				debuggit(1 => "statement handle isa", ref $res->{sth});
				croak("initial command ($command) failed for data store $this->{name}") unless defined $res;
			}
		}
	}
}


sub _initialize_vars
{
	my $this = shift;

	$this->{vars} = {};
	if (exists $this->{config}->{translation_type})
	{
		my $constant_table
				= $constants->{$this->{config}->{translation_type}};
		$this->{vars}->{$_} = $constant_table->{$_}
				foreach keys %$constant_table;
	}
	# _dump_attribs($this, "after var init");
}


sub _make_schema_trans
{
	my $this = shift;

	$this->{schema_translation}
				= sub { eval $this->{config}->{schema_translation_code} }
			if exists $this->{config}->{schema_translation_code};
}


# used only by _transform_query (below) while checking for ??? (non-scalar placeholders)
sub _check_for_variable
{
	my ($which, $value) = @_;

	my $is_var = defined $value && $value =~ /$VAR_VALUE/;
	debuggit(4 => "found that", $value, $is_var ? "is" : "is not", " a variable");
	if ($which eq 'PLACEHOLDER')
	{
		# if it's a variable, just return it back; otherwise return a ? placeholder
		return $is_var ? $value : '?';
	}
	elsif ($which eq 'BIND_VAL')
	{
		# if it's a variable, then there will be no bind val, so return an empty list (else return the value)
		return $is_var ? () : $value;
	}
	else
	{
		die("don't know what to return when checking for variable ($which)");
	}
}


# handle all substitutions on queries
sub _transform_query
{
	my $this = shift;

	# pull out any hash or array placeholders (a.k.a. "non-scalar placeholders")
	my @ns_placeholders;
	for (0..$#_) { push @ns_placeholders, $_[$_] and splice @_, $_, 1 if ref $_[$_] };
	debuggit(4 => "built ns_placeholders with", scalar(@ns_placeholders), "elements");

	my ($query, %temp_vars) = @_;
	my @vars = ();
	my $calc_funcs = {};

	debuggit(5 => "at top of transform:", $this->ping() ? "connected" : "NOT CONNECTED!");

	# it's a bad idea to allow queries while the data store is modified.
	# the biggest reason is that the result set returned by do() contains
	# a reference to the data store, so if the result sets remain in scope
	# for some reason, the destructor won't save the data store (in fact,
	# it won't even get called, because there's still an outstanding
	# reference--or more--to the object).  this could produce weird results,
	# including trying to save the same data store twice (or more) in a row
	# with different modifications.  for that reason, we just disallow it
	# altogether.  and since this function gets called by every main
	# subroutine that calls queries, this is a good common place to check.
	if ($this->{modified})
	{
		croak("can't execute query with config's pending; run commit_configs()");
	}

	$this->_dump_attribs("before SQL preproc") if DEBUG >= 5;
	debuggit(5 => "about to check for vars in", $query);
	# variables and constants
	while ($query =~ / { (\w+) } | (values) \s+ $HASH_PH | (set) \s+ $HASH_PH /iox)
	{
		if ($1)															# just a variable
		{
			my $variable = $&;
			my $varname = $1;

			my $value;
			if (exists $temp_vars{$varname})
			{
				# temp_vars override previously defined vars
				$value = $temp_vars{$varname};
			}
			elsif (exists $this->{vars}->{$varname})
			{
				$value = $this->{vars}->{$varname};
			}
			else
			{
				croak("variable/constant unknown: $varname");
			}

			# for variable substitution, we use placeholders and return the var values
			# the funky substring is pretty much straight out of the perlvar manpage
			# it avoids the use of $& (which causes severe performance penalties), _and_ it's faster for this
			# operation anyways, because using $& would involve a s//, which is going to be slower than using
			# substr() as an lvalue
			substr($query, $-[0], $+[0] - $-[0]) = '?';
			push @vars, $value;
		}
		elsif ($2)														# values ???
		{
			my $hash = shift @ns_placeholders;

			substr($query, $-[0], $+[0] - $-[0]) = '(' . join(', ', sort keys %$hash) . ') values (' .
					join(',', map { _check_for_variable(PLACEHOLDER => $hash->{$_}) } sort keys %$hash) . ')';

			push @vars, map { _check_for_variable(BIND_VAL => $hash->{$_}) } sort keys %$hash;
		}
		elsif ($3)														# set ???
		{
			my $hash = shift @ns_placeholders;

			substr($query, $-[0], $+[0] - $-[0]) = 'set ' .
					join(', ', map { "$_ = " . _check_for_variable(PLACEHOLDER => $hash->{$_}) } sort keys %$hash);

			push @vars, map { _check_for_variable(BIND_VAL => $hash->{$_}) } sort keys %$hash;
		}
	}

	my $sth;		# statement handle for us to return at the end of it all

	# check to see if we have this query cached
	# note: the "raw" query isn't quite raw: it's the query after variable
	# substitutions (only).  variables could change, but it's assumed that
	# aliases, schema names, etc, will NOT change.  you're going to get
	# funky results if you try to change them in the middle of querying.
	my $raw_query = $query;
	# do *not* return a cached statement handle that is still active!
	# this could screw up pathological cases
	if (exists $_query_cache{$raw_query} and not $_query_cache{$raw_query}->{Active})
	{
		$sth = $_query_cache{$raw_query};
		print "DataStore current query:\n  cached version of\n$query\n" if $this->{show_queries};
	}
	else											# do it the hard way
	{
		debuggit(3 => "about to check for curly braces in query", $query);
		# this outer if protects queries with no substitutions from paying
		# the cost for searching for the various types of sub's
		if ($query =~ /{/)	# if you want % to work in vi, you need a } here
		{

			# alias translations
			while ($query =~ / {\@ (\w+) } /x)
			{
				my $alias = $&;
				my $alias_name = $1;
				my $table_name = $this->{config}->{aliases}->{$alias_name};
				croak("unknown alias: $alias_name") unless $table_name;
				$query =~ s/$alias/$table_name/g;
			}

			# schema translations
			while ($query =~ / {~ (\w+) } \. /x)
			{
				my $schema = $&;
				my $schema_name = $1;
				my $translation = $this->{schema_translation}->($schema_name);
				# print STDERR "schema: $schema, s name: $schema_name, ";
				# print STDERR "translation: $translation\n";
				$query =~ s/$schema/$translation/g;
			}

			debuggit(5 => "about to check for functions in", $query);
			# function calls
			while ($query =~ / {\& (\w+) (?: \s+ (.*?) )? } /x)
			{
				my $function = quotemeta($&);
				my $func_name = $1;
				my @args = ();
				@args = split(/,\s*/, $2) if $2;

				debuggit(4 => "translating function", $func_name);
				croak("no translation scheme defined")
						unless exists $this->{config}->{translation_type};
				my $func_table = $funcs->{$this->{config}->{translation_type}};
				croak("unknown translation function: $func_name")
						unless exists $func_table->{$func_name};

				my $func_output = $func_table->{$func_name}->(@args);
				$query =~ s/$function/$func_output/g;
			}

			debuggit(5 => "about to check for calc cols in", $query);
			# calculated columns
			while ($query =~ / { \* (.*?) \s* = \s* (.*?) } /sx)
			{
				my $field_spec = quotemeta($&);
				my $calc_col = $1;
				my $calculation = $2;
				debuggit(4 => "found a calc column:", $calc_col, "=", $calculation);
				debuggit(5 => "going to replace <<", $field_spec, ">> with <<1 as \"*$calc_col\">> in query <<",
						$query, ">>");

				while ($calculation =~ /%(\w+)/)
				{
					my $col_ref = $1;
					my $spec = quotemeta($&);

					debuggit(4 => "found col ref in calc:", $col_ref);
					debuggit(5 => "going to sub", $spec, "with", qq/\$_[0]->col($col_ref)/);
					$calculation =~ s/$spec/\$_[0]->col("$col_ref")/g;
				}

				while ($calculation =~ /\$([a-zA-Z]\w+)/)
				{
					my $varname = $1;
					my $spec = quotemeta($&);

					$calculation =~ s/$spec/\${\$_[0]}->{vars}->{$varname}/g;
				}

				debuggit(2 => "going to evaluate calc func:", "sub { $calculation }");
				my $calc_function = eval "sub { $calculation }";
				croak("illegal syntax in calculated column: $field_spec ($@)") if $@;
				$calc_funcs->{$calc_col} = $calc_function;

				$query =~ s/$field_spec/1 as "*$calc_col"/g;
				debuggit(5 => "after calc col subst, query is <<", $query, ">>");
			}
		}

		debuggit(4 => "after transform:", $query);
		print "DataStore current query:\n$query\n" if $this->{show_queries};

		debuggit(5 => "before preparing query:", $this->ping() ? "connected" : "NOT CONNECTED!");

		$sth = $this->{dbh}->prepare($query);
		unless ($sth)
		{
			$this->{last_err} = $this->{dbh}->errstr();
			debuggit(5 => "prepare bombed:", $this->{last_err});
			return wantarray ? () : undef;
		}
		debuggit(5 => "successfully prepared query");

		# cache the sth for next time
		$_query_cache{$raw_query} = $sth;
	}

	debuggit(5 => "at bottom of transform:", $this->ping() ? "connected" : "NOT CONNECTED!");

	if (wantarray)
	{
		return ($sth, $calc_funcs, @vars);
	}
	else
	{
		carp("calculated columns are being lost") if %$calc_funcs;
		return $sth;
	}
}


# for debugging
sub _dump_attribs
{
	my $this = shift;
	my ($msg) = @_;

	foreach (keys %{$this->{config}})
	{
		print STDERR "  $msg: config->$_ = $this->{config}->{$_}\n";
	}

	foreach (keys %{$this->{vars}})
	{
		print STDERR "  $msg: vars->$_ = $this->{vars}->{$_}\n";
	}

	foreach (keys %$this)
	{
		print STDERR "  $msg: $_ = $this->{$_}\n" unless $_ eq 'config' or $_ eq 'vars';
	}
}


# interface methods


sub get_password
{
	my ($find_server, $find_user) = @_;
	my $pwfile = "$ENV{HOME}/" . PASSWORD_FILE;
	debuggit(4 => "password file is", $pwfile);

	croak("must have a $pwfile file in your home directory")
			unless -e $pwfile;
	my $pwf_mode = (stat _)[2];				# i.e., the permissions
	croak("$pwfile must be readable and writable only by you")
			if $pwf_mode & 077;

	open(PW, $pwfile) or croak("can't read file $pwfile");
	while ( <PW> )
	{
		chomp;

		my ($server, $user, $pass) = split(/:/);
		if ($server eq $find_server and $user eq $find_user)
		{
			close(PW);
			debuggit(4 => "get_password: returning password", $pass);
			return $pass;
		}
	}
	close(PW);

	debuggit(4 => "get_password: couldn't find password");
	return undef;
}


sub open
{
	my $class = shift;
	my ($data_store_name, $user_name) = @_;

	my $ds_filename = "$data_store_dir/$data_store_name.dstore";
	debuggit(3 => "file name is", $ds_filename);
	croak("data store $data_store_name not found") unless -e $ds_filename;

	my $this = {};
	$this->{name} = $data_store_name;
	eval { $this->{config} = retrieve($ds_filename); };
	croak("read error opening data store") unless $this->{config};

	# supply user name for this session
	croak("must specify user to data store") unless $user_name;
	$this->{user} = $user_name;

	# eval schema translation code if it's there
	_make_schema_trans($this);

	# set up variable space; fill it with constants if any
	_initialize_vars($this);

	# mark unmodified
	$this->{modified} = false;
	$this->{show_queries} = false;

	_dump_attribs($this, "in open") if DEBUG >= 5;

	bless $this, $class;
	$this->_login();
	debuggit(4 => "this is a", ref $this, "for ds", $data_store_name);
	return $this;
}


sub create
{
	my $class = shift;
	my ($data_store_name, %attribs) = @_;

	# error check potential attributes
	foreach my $key (keys %attribs)
	{
		croak("can't create data store with unknown attribute $key")
				unless grep { /$key/ } (
					qw<connect_string initial_commands server user>,
					qw<translation_type>
				);
	}

	my $this = {};
	$this->{name} = $data_store_name;

	# user has to be present, and should be moved out of config section
	croak("must specify user to data store") unless exists $attribs{user};
	$this->{user} = $attribs{user};
	delete $attribs{user};

	$this->{config} = \%attribs;
	$this->{config}->{name} = $data_store_name;
	$this->{modified} = true;
	$this->{show_queries} = false;

	_initialize_vars($this);

	bless $this, $class;
	$this->_login();

	return $this;
}


sub DESTROY
{
	my $this = shift;
	# $this->_dump_attribs("in dtor");

	$this->commit_configs();
}


sub commit_configs
{
	my $this = shift;

	if ($this->{modified})
	{
		$this->{modified} = false;

		my $data_store_name = $this->{config}->{name};
		my $ds_filename = "$data_store_dir/$data_store_name.dstore";
		# print STDERR "destroying object, saving to file $ds_filename\n";

		croak("can't save data store specification")
				unless store($this->{config}, $ds_filename);
	}
}


sub ping
{
	my $this = shift;
	return $this->{dbh}->ping();
}


sub last_error
{
	my $this = shift;

	return $this->{last_err};
}


sub show_queries
{
	my $this = shift;
	my $state = defined $_[0] ? $_[0] : true;

	$this->{show_queries} = $state;
}


sub do
{
	# query etc not needed here; just pass thru to _transform_query below
	my ($this) = @_;

	# handle substitutions
	# (note & form of sub call, which just passes our args through w/o copying)
	my ($sth, $calc_funcs, @vars) = &_transform_query or return undef;

	my $rows = $sth->execute(@vars);
	unless ($rows)
	{
		$this->{last_err} = $sth->errstr();
		return undef;
	}
	debuggit(5 => "successfully executed query");

	my $results = {};
	$results->{ds} = $this;
	$results->{rows} = $rows;
	$results->{sth} = $sth;
	$results->{calc_funcs} = $calc_funcs;
	bless $results, 'DataStore::ResultSet';

	return $results;
}


sub execute
{
	my $this = shift;
	my ($sql_text, %params) = @_;
	my $delim = exists $params{delim} ? $params{delim} : ";";

	my $report = "";
	foreach my $query (split(/\s*$delim\s*\n/, $sql_text))
	{
		next if $query =~ /^\s*$/;			# ignore blank queries

		my $res = $this->do($query);
		return undef unless defined $res;
		if (exists $params{report})
		{
			my $rows = $res->rows_affected();
			if ($res->{sth}->{NUM_OF_FIELDS})
			{
				$rows = 0;
				++$rows while $res->next_row();
			}
			if ($rows >= 0)
			{
				$report .= $params{report};
				$report =~ s/%R/$rows/g;
			}
		}
	}

	return $report ? $report : true;
}


sub begin_tran
{
	my $this = shift;

	unless ($this->{dbh}->begin_work())
	{
		$this->{last_err} = $this->{dbh}->errstr;
		croak("cannot start transaction");
	}

	return true;
}


sub commit
{
	my $this = shift;

	unless ($this->{dbh}->commit())
	{
		$this->{last_err} = $this->{dbh}->errstr;
		croak("cannot commit transaction");
	}
}


sub rollback
{
	my $this = shift;

	unless ($this->{dbh}->rollback())
	{
		$this->{last_err} = $this->{dbh}->errstr;
		croak("cannot rollback transaction");
	}

	return true;
}


# the primary difference between load_data and other methods such as do()
# is that load_data returns a DataSet, whereas do() et al return a ResultSet
# with a DataSet, all the data is in memory at once (not so with a ResultSet)
# NOTE: load_table is an alias for load_data
sub load_data
{
	# just pass all parameters straight through to do
	my $res = &do;
	return undef unless $res;

	return DataStore::DataSet->new($res->{sth});
}


# for append_table, you need to send it a DataSet
# your best bet is to only use a structure returned from load_data()
sub append_table
{
	my $this = shift;
	my ($table, $data, $empty_set_okay) = @_;
	if ($empty_set_okay and $empty_set_okay != EMPTY_SET_OKAY)
	{
		$this->{last_err} = "illegal option sent to append_table";
		return undef;
	}

	# make sure we have at least one row, unless empty sets are okay
	unless (@$data)
	{
		if ($empty_set_okay)
		{
			# looks like they don't care that there's no data; just return
			return true;
		}
		else
		{
			$this->{last_err} = "no rows passed to append_table";
			return undef;
		}
	}

	# build an insert statement
	my @colnames = $data->colnames();
	debuggit(3 => "column names are:", @colnames);
	my $columns = join(',', @colnames);
	my $placeholders = join(',', ("?") x scalar(@colnames));
	my $query = "insert $table ($columns) values ($placeholders)";
	my ($sth) = $this->_transform_query($query) or return undef;

	foreach my $row (@$data)
	{
		if (DEBUG >= 4)
		{
			print STDERR "row: $_ => $row->{$_}\n" foreach @colnames;
			print STDERR "sending bind values: @$row\n"
		}
		my $rows = $sth->execute(@$row);
		unless ($rows)
		{
			$this->{last_err} = $sth->errstr();
			return false;
		}
	}

	return true;
}


# replace_table just deletes all rows from the table, then calls
# append_table for you.  THIS CAN BE VERY DESTRUCTIVE! (obviously)
# please use with caution
sub replace_table
{
	my $this = shift;
	my ($table, $data, $empty_set_okay) = @_;

	return undef unless $this->do("delete from $table");

	return $this->append_table($table, $data, $empty_set_okay);
}


sub overwrite_table
{
	my $this = shift;
	my ($table_name, $columns) = @_;

	return false unless $table_name and $columns and @$columns;

	my $pk;
	my $column_list = "(";
	foreach my $col (@$columns)
	{
		my ($name, $type, $attributes) = @$col;
		$attributes = lc($attributes);

		# translate user-defined types
		if (exists $this->{config}->{user_types})
		{
			$type = $this->{config}->{user_types}->{$type}
					if exists $this->{config}->{user_types}->{$type};
		}

		# translate base types
		if (exists $this->{config}->{translation_type})
		{
			my $trans_table = $base_types->{
					$this->{config}->{translation_type}
			};
			$type = $trans_table->{$type} if exists $trans_table->{$type};
		}

		# identity columns have to generate primary keys
		if ($attributes eq 'identity')
		{
			croak("can't have multiple IDENTITY columns") if $pk;
			$pk = $name;
		}

		# translate attributes
		if (exists $this->{config}->{translation_type})
		{
			my $trans_table = $column_attributes->{
					$this->{config}->{translation_type}
			};
			$attributes = $trans_table->{$attributes} if exists $trans_table->{$attributes};
		}

		$column_list .= ", " if length($column_list) > 1;
		$column_list .= "$name $type $attributes";
	}
	$column_list .= ", primary key ($pk)" if $pk;
	$column_list .= ")";
	debuggit(3 => "final column list is", $column_list);

	if ($this->do("select 1 from $table_name where 1 = 0"))
	{
		$this->do("drop table $table_name") or return false;
	}
	$this->do("create table $table_name $column_list") or return false;
	#$this->do("grant select on $table_name to public") or return false;

	return true;
}


sub configure_type
{
	my $this = shift;
	my ($user_type, $base_type) = @_;

	$this->{config}->{user_types}->{$user_type} = $base_type;
	$this->{modified} = true;
}


sub configure_alias
{
	my $this = shift;
	my ($alias, $table_name) = @_;

	$this->{config}->{aliases}->{$alias} = $table_name;
	$this->{modified} = true;
}


sub configure_schema_translation
{
	my $this = shift;
	my ($trans_code) = @_;

	$this->{config}->{schema_translation_code} = $trans_code;
	$this->_make_schema_trans();
	$this->{modified} = true;
}


sub define_var
{
	my $this = shift;
	my ($varname, $value) = @_;

	$this->{vars}->{$varname} = $value;
}



###########################################################################
# The DataStore::ResultSet "subclass"
###########################################################################

package DataStore::ResultSet;

use Carp;

use Barefoot::base;
use Barefoot::DataStore::DataRow;


sub _get_colnum
{
	return $_[0]->{currow}->_get_colnum($_[1]);
}


sub _get_colval
{
	return $_[0]->{currow}->[$_[1]];
}


sub next_row
{
	my $this = shift;

	my $row = $this->{sth}->fetchrow_arrayref();
	unless ($row)
	{
		# just ran out of rows?
		return 0 if not $this->{sth}->err();

		# no, i guess it's an error
		$this->{ds}->{last_err} = $this->{sth}->errstr();
		return undef;
	}
	$this->{currow} = DataStore::DataRow->new(
			$this->{sth}->{NAME}, $this->{sth}->{NAME_hash}, $row,
			$this->{calc_funcs}, $this->{ds}->{vars}
	);

	return $this->{currow};
}


sub rows_affected
{
	return $_[0]->{rows};
}


sub num_cols
{
	return $_[0]->{sth}->{NUM_OF_FIELDS};
}


sub colnames
{
	return @{ $_[0]->{sth}->{NAME} };
}


sub col
{
	return $_[0]->{currow}->col($_[1]);
}


sub colname
{
	my ($this, $colnum) = @_;

	return $this->{sth}->{NAME}->[$colnum];
}


sub all_cols
{
	return @{ $_[0]->{currow} };
}


sub count
{
	my $this = shift;
	$this->next_row() or return undef;
	return $this->{currow}->col(0);
}


###########################
# Return a true value:
###########################

1;
