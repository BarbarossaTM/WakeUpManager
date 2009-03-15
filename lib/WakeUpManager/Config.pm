#!/usr/bin/perl -WT
#
#   WakeUpManager suite
#
#   Copyright (C) 2008-2009 Maximilian Wilhelm <max@rfc2324.org>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along
#   with this program; if not, write to the Free Software Foundation, Inc.,
#   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Sun 02 Dec 2007 07:21:22 AM CET
#

package WakeUpManager::Config;

use strict;
use Carp;

my $default_config_file = "/etc/wum/wum.conf";

##
# Little bit of magic to simplify debugging
sub _options(@) { #{{{
	my %ret = @_;

	if ( $ret{debug} ) {
		foreach my $opt (keys %ret) {
			print STDERR __PACKAGE__ . "->_options: $opt => $ret{$opt}\n";
		}
	}

	return \%ret;
} #}}}


sub new () { # new () :  {{{
	my $self = shift;
	my $class = ref ($self) || $self;

	# Make life easy
	my $args = &_options (@_);

	# Verbosity
	my $debug = (defined $args->{debug}) ? $args->{debug} : 0;
	my $verbose = (defined $args->{verbose}) ? $args->{verbose} : $debug;

	my $config_file = $args->{config_file} || $default_config_file;

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		errno => 0,
		errstr => undef,
	}, $class;

	$obj->{config} = $obj->read_config ($config_file);
	if (! $obj->{config}) {
		confess __PACKAGE__ . "->new(): Error: $obj->{errno}: $obj->{errstr}\n";
	}

	return $obj;
} #}}}

sub _clear_err () {
	my $self = shift;

	return if (ref ($self) ne __PACKAGE__);

	$self->{errno} = 0;
	$self->{errstr} = undef;
}

sub _set_err ($$) {
	my $self = shift;

	my $errno = shift || '1';
	my $errstr = shift || 'unknown';
	chomp $errstr;

	return undef if (ref ($self) ne __PACKAGE__);

	$self->{errno} = $errno;
	$self->{errstr} = "$errstr\n";

	return undef;
}

sub err () {
	my $self = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	return $self->{errno};
}

sub errstr () {
	my $self = shift;

	return 'errstr() has to be called on blessed class\n' if (ref ($self) ne __PACKAGE__);

	return $self->{errstr};
}

sub read_config (;$) { # read_config ([config_file]) : \%cofig {{{
	my $self = shift;

	$self->_clear_err ();

	my $config_file = shift;
	if (! defined $config_file) {
		$config_file = $default_config_file;
	}

	# Check for file
	if (! -f $config_file) {
		$self->_set_err (1, "Config file \"$config_file\" does not exist");
		return undef;
	}

	# Is config file readable?
	if (! require ($config_file)) {
		$self->_set_err (2, "Failed to read configuration from \"$config_file\".");
		return undef;
	}

	# Check for global file interna
	if (! defined $WakeUpManager::Main::Config::config) {
		$self->_set_err (3, "Missing hash_ref \$config in config file \"$config_file\".");
		return undef;
	}
	my $config = $WakeUpManager::Main::Config::config;

	if (ref ($config) ne 'HASH') {
		$self->_set_err (4, "Invalid \$config parameter in config file \"$config_file\". Has to be hash_ref but isn't");
		return undef;
	}

	return $config;
} # }}}

sub get_dbi_param ($) { # get_dbi_param (DB_name) : \@dbi_param {{{
	my $self = shift;

	my $db = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	return undef if (! defined $db);
	return undef if (! defined $self->{config}->{DB}->{$db}->{DBI_param});

	return $self->{config}->{DB}->{$db}->{DBI_param};
} # }}}

sub get_cron_opts () { # get_cron_opts () : \%cron_opts {{{
	my $self = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	return $self->{config}->{Cron};
} # }}}

sub get_ui_opts () { # get_ui_opts () : \%ui_opts {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_rpc_url(): Has to be called on bless'ed object.\n";
	}

	return $self->{config}->{UI};
} # }}}

sub get_client_opts () { # get_client_opts () : \%client_opts {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_rpc_url(): Has to be called on bless'ed object.\n";
	}

	return $self->{config}->{CLIENT};
} # }}}

sub get_agent_opts () { # get_agent_opts () : \%agent_opts {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_agent_opts(): Has to be called on bless'ed object.\n";
	}

	return $self->{config}->{Agent};
} # }}}

sub get_mgnt_opts () { # get_mgnt_opts () : \%mgnt_opts {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_agent_opts(): Has to be called on bless'ed object.\n";
	}

	return $self->{config}->{USER_MGNT};
} # }}}

sub get_WWW_opts () { # get_WWW_opts () : \%WWW_opts {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_WWW_opts(): Has to be called on bless'ed object.\n";
	}

	return $self->{config}->{WWW};
} # }}}

sub get_extension_opts ($) { # get_extension_opts (Extension_name) : \%options {{{
	my $self = shift;

	my $ext_name = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	return undef if (! defined $ext_name);
	return undef if (! defined $self->{config}->{extensions}->{$ext_name});
	return undef if (ref ($self->{config}->{extensions}->{$ext_name}) ne 'HASH');

	return $self->{config}->{extensions}->{$ext_name};
} # }}}

1;

# vim:foldmethod=marker
