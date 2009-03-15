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
#  --  Thu May 29 20:20:06 2008
#

package WakeUpManager::WWW::Page::BootHost;

use strict;
use Carp qw(cluck confess);

use WakeUpManager::Agent::Connector;
use WakeUpManager::WWW::Utils;

my $messages = { # {{{
	booting_host => {
		en => "Booting host <i>%s</i>.",
		de => "Rechner <i>%s</i> wird gestartet.",
	},
}; # }}}

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

	# Pull DB handle but don't check it here!
	my $host_db_h = $args->{host_db_h};

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		host_db_h => $host_db_h,

		params => $params,
	}, $class;

	#
	# Get CGI parameters
	$obj->{user} = $params->get_auth_info()->{user};
	$obj->{host_id} = $params->get_http_param ('host_id');
	$obj->{lang} = $params->get_lang ();

	return $obj;
} #}}}

sub get_header_elements () {
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_header_elements(): Has to be called on bless'ed object\n";
	}

	my $lang = $self->{params}->get_lang ();
	my $h2 = "Boot host";
	if ($lang eq 'de') {
		$h2 = "Rechner starten";
	}

	return {
		h2 => $h2,

		header_opt => "<script src=\"/ui/inc/BootHost.js\" type=\"text/javascript\"></script>",
	};
}

sub get_content_elements () {
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->run(): You may want to call me on an instantiated object.\n";
	}

	# Check for db_h and report error if not there
	if (! $self->{host_db_h}) {
		return { PageERROR => $self->{error_message} = "No connection to database.\n" };
	}

	my $content_elements = {};

	#
	# Get CGI parammeters
	my $user = $self->{user};
	my $host_id = $self->{host_id};

	my $bootable_hostgroups = $self->{host_db_h}->hostgroups_user_can_boot ($user);
	my $bootable_hosts = $self->{host_db_h}->hosts_user_can_boot ($user);

	# The really cool version of output formatting[tm]
	my $ALL_hostgroup_id = $self->{host_db_h}->get_hostgroup_id ('ALL');
	if ($ALL_hostgroup_id) {
		my $hostgroup_tree = $self->{host_db_h}->get_hostgroup_tree_below_group ($ALL_hostgroup_id);
		$content_elements->{hostgroup_loop} = WakeUpManager::WWW::Utils->gen_pretty_hostgroup_tree_select ($hostgroup_tree, $bootable_hostgroups);
	}

	if ($bootable_hosts) {
		$content_elements->{host_loop} = WakeUpManager::WWW::Utils->gen_pretty_host_select ($bootable_hosts);
	}

	#
	# If the user submitted the form, let's go
	#
	if (defined $host_id) {
		my $result_hash = $self->_boot_host ();

		foreach my $key (keys %{$result_hash}) {
			$content_elements->{$key} = $result_hash->{$key};
		}

		$content_elements->{result} = 1;
	}

	return $content_elements;
}


sub ajax_call ($) {
	my $self = shift;

	my $ajax_func_name = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! defined $ajax_func_name);

	if ($ajax_func_name eq 'boot_host') {
		return $self->_boot_host ();
	} else {
		return undef;
	}
}


################################################################################
#				internal routintes			       #
################################################################################


sub _boot_host () {
	my $self = shift;

	my $host_id = $self->{host_id};
	my $user = $self->{user};
	my $lang = $self->{lang};

	my $content_elements = {};


	if (! $self->{host_db_h}->is_valid_host ($host_id)) {
		return {
			error => 1,
			invalid_host_id => 1,
		};
	}

	my $host_name = $self->{host_db_h}->get_host_name ($host_id) || "#$host_id";

	if (! $self->{host_db_h}->user_can_boot_host ($user, $host_id)) {
		return {
			error => 1,
			user_not_allow_to_boot_host => $host_name,
		};
	}

	my $agent_conn = WakeUpManager::Agent::Connector->new (host_db_h => $self->{host_db_h});
	if (! $agent_conn) {
		return {
			error => 1,
			no_agent => 1,
		};
	}

	if ($agent_conn->boot_host ($host_id)) {
		return {
			content => sprintf ($messages->{booting_host}->{$lang}, $host_name),
		};
	} else {
		my $error_msg = $agent_conn->get_errormsg ();

		if ($error_msg) {
			return {
				error => 1,
				error_on_agent => $error_msg,
			};
		} else {
			return {
				error => 1,
				unknown_error => 1,
			};
		}
	}
}

1;

# vim:foldmethod=marker
