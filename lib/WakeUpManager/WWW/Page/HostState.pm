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
#  --  Mon 02 Jun 2008 11:16:40 AM CEST
#

package WakeUpManager::WWW::Page::HostState;

use strict;
use Carp qw(cluck confess);

use WakeUpManager::WWW::Utils;

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

	my $params = $args->{params};
	if (! $params || ref ($params) ne 'WakeUpManager::WWW::Params') {
		confess __PACKAGE__ . "->new(): No or invalid 'params' argument.";
	}

	# Pull DB handle but don't check it *here*
	my $host_db_h = $args->{host_db_h};

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		host_db_h => $host_db_h,

		params => $params,
	}, $class;

	return $obj;
} #}}}

sub get_header_elements () {
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_header_elements(): Has to be called on bless'ed object\n";
	}

	my $h2 = "Host activation state";
	my $lang = $self->{params}->get_lang ();
	if ($lang eq 'de') {
		$h2 = "Aktivierungsstatus";
	}

	return {
		h2 => $h2,

		header_opt => "<script src=\"inc/HostState.js\" type=\"text/javascript\"></script>",
	};
}

sub get_content_elements () {
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->run(): You may want to call me on an instantiated object.\n";
	}

	if (! $self->{host_db_h}) {
		return { PageERROR => "No connection to database." };
	}

	my $content_elements = {};

	my $user = $self->{params}->get_auth_info()->{user};

	my $allowed_hostgroups = $self->{host_db_h}->hostgroups_user_can_read_config ($user);
	my $allowed_hosts = $self->{host_db_h}->hosts_user_can_read_config ($user);

	# The really cool version of output formatting[tm]
	my $ALL_hostgroup_id = $self->{host_db_h}->get_hostgroup_id ('ALL');
	if ($ALL_hostgroup_id) {
		my $hostgroup_tree = $self->{host_db_h}->get_hostgroup_tree_below_group ($ALL_hostgroup_id);
		$content_elements->{hostgroup_loop} = WakeUpManager::WWW::Utils->gen_pretty_hostgroup_tree_select ($hostgroup_tree, $allowed_hostgroups);
	}

	$content_elements->{host_loop} = WakeUpManager::WWW::Utils->gen_pretty_host_select ($allowed_hosts);

	my $host_id = $self->{params}->get_http_param ('host_id');
	my $update =  $self->{params}->get_http_param ('update');
	if ($host_id) {
		my $result;

		if (! defined $update) {
			$result = $self->_get_host_state ();
		} else {
			$result = $self->_set_host_state ();
		}

		foreach my $key (keys %{$result}) {
			$content_elements->{$key} = $result->{$key};
		}

		$content_elements->{result} = 1;
	}

	return $content_elements;
}


sub ajax_call ($) {
	my $self = shift;

	my $func_name = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! defined $func_name);

	if ($func_name eq 'get_host_state') {
		return $self->_get_host_state ();
	} elsif ($func_name eq 'set_host_state') {
		return $self->_set_host_state ();
	} else {
		return undef;
	}
}


sub _get_host_state () {
	my $self = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	my $host_db_h = $self->{host_db_h};
	if (! $host_db_h) {
		return {
			error => 1,
			no_db_conn => 1,
		};
	}

	# Get options
	my $host_id = $self->{params}->get_http_param ('host_id');
	my $user = $self->{params}->get_user ();
	my $lang = $self->{params}->get_lang ();

	#
	# Validate input
	if (! $host_db_h->is_valid_host ($host_id)) {
		return {
			error => 1,
			invalid_host_id => 1,
		};
	}

	my $host_name = $host_db_h->get_host_name ($host_id);
	if (! $host_name) {
		$host_name = "#$host_id";
	}

	#
	# Check if user is allow to show host config
	if (! $host_db_h->user_can_read_host_config ($user, $host_id)) {
		return {
			error => 1,
			user_not_allow_to_view_state => $host_name,
		};
	}

	#
	# Query DB for boot times
	my $host_state = $host_db_h->get_host_state ($host_id);
	if (ref ($host_state) ne 'HASH') {
		return {
			error => 1,
			unknown_error => 1,
		};
	}

	return {
		box_head_name => 1,
		host_state => $host_name,
		host_id => $host_id,
		host_state_boot => $host_state->{boot_host},
		host_state_shutdown => $host_state->{shutdown_host},
		host_state_writeable => $host_db_h->user_can_write_host_config ($user, $host_id),
	};
}


sub _set_host_state () {
	my $self = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	# Get host_id
	my $host_id = $self->{params}->get_http_param ('host_id');

	# Get host_state
	my $args = {};
	foreach my $arg (qw(boot_host shutdown_host)) {
		my $arg_val = $self->{params}->get_http_param ($arg);
		$args->{$arg} = (defined $arg_val) ? 1 : 0;
	}

	my $user = $self->{params}->get_auth_info ()->{user};
	my $lang = $self->{params}->get_lang ();

	# Check DB connection
	my $host_db_h = $self->{host_db_h};
	if (! $host_db_h) {
		return {
			error => 1,
			no_db_conn => 1,
		};
	}

	# Validate input
	if (! $host_db_h->is_valid_host ($host_id)) {
		return {
			error => 1,
			invalid_host_id => 1,
		};
	}

	my $host_name = $host_db_h->get_host_name ($host_id);
	if (! $host_name) {
		$host_name = "#$host_id";
	}

	#
	# Check if user is allow to show host config
	if (! $host_db_h->user_can_write_host_config ($user, $host_id)) {
		return {
			error => 1,
			user_not_allow_to_update_state => $host_name,
		};
	}

	if (! $host_db_h->set_host_state ($host_id, $args->{boot_host}, $args->{shutdown_host})) {
		return {
			error => 1,
			host_state_error => 1,
		};
	}

	return {
		host_state_updated => 1,
	};
}

1;

# vim:foldmethod=marker
