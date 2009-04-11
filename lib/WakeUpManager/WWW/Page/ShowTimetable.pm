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

package WakeUpManager::WWW::Page::ShowTimetable;

use strict;
use Carp qw(cluck confess);

use WakeUpManager::WWW::Utils;
use WakeUpManager::WWW::GraphLib;

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

	my $h2 = 'Show host timetable';
	my $lang = $self->{params}->get_lang ();
	if ($lang eq 'de') {
		$h2 = "Zeitplan anzeigen";
	}

	return {
		h2 => $h2,

		header_opt => "<script src=\"inc/ShowTimetable.js\" type=\"text/javascript\"></script>",
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

	our $allowed_hostgroups = $self->{host_db_h}->hostgroups_user_can_read_config ($user);
	our $allowed_hosts = $self->{host_db_h}->hosts_user_can_read_config ($user);

	# The really cool version of output formatting[tm]
	my $ALL_hostgroup_id = $self->{host_db_h}->get_hostgroup_id ('ALL');
	if ($ALL_hostgroup_id) {
		my $hostgroup_tree = $self->{host_db_h}->get_hostgroup_tree_below_group ($ALL_hostgroup_id);
		$content_elements->{hostgroup_loop} = WakeUpManager::WWW::Utils->gen_pretty_hostgroup_tree_select ($hostgroup_tree, $allowed_hostgroups);
	}

	if ($allowed_hosts) {
		$content_elements->{host_loop} = WakeUpManager::WWW::Utils->gen_pretty_host_select ($allowed_hosts);
	}

	my $host_id = $self->{params}->get_http_param ('host_id');
	if (defined $host_id) {
		my $result_hash = $self->_show_timetable ();
		foreach my $key (keys %{$result_hash}) {
			$content_elements->{$key} = $result_hash->{$key};
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

	if ($func_name eq 'show_timetable') {
		return $self->_show_timetable ();
	} else {
		return undef;
	}
}


sub _show_timetable () {
	my $self = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	my $host_db_h = $self->{host_db_h};
	if (! $host_db_h) {
		return {
			error => 1,
			no_db_conn => 1,
		};
	}

	my $host_id = $self->{params}->get_http_param ('host_id');
	if (! $host_db_h->is_valid_host ($host_id)) {
		return {
			error => 1,
			invalid_host_id => 1,
		};
	}

	# Try to get users preference for timetable
	my $orientation = $self->{params}->get_cookie ('timetable_orientation');
	if (! defined $orientation || ($orientation ne 'horizontal' && $orientation ne 'vertical')) {
		$orientation = 'horizonal';
	}

	my $user = $self->{params}->get_user ();
	my $lang = $self->{params}->get_lang ();

	my $gl = WakeUpManager::WWW::GraphLib->new ();

	my $host_name = $host_db_h->get_host_name ($host_id);
	if (! $host_name) {
		$host_name = "#$host_id";
	}

	#
	# Check if user is allow to show host config
	if (! $host_db_h->user_can_read_host_config ($user, $host_id)) {
		return {
			error => 1,
			user_not_allow_to_view_timetable => 1,
		};
	}

	#
	# Query DB for boot times
	my $boot_times = $host_db_h->get_times_of_host ($host_id);
	if (! $boot_times || ref ($boot_times) ne 'HASH') {
		return {
			error => 1,
			unknown_error => 1,
		};
	}

	if (! keys %{$boot_times}) {
	}

	my $times_list = WakeUpManager::Common::Utils::get_times_list ($boot_times);

	my $result = "<img src=\"ajax/get_time_table_for_host_png?host_id=$host_id\" alt=\"\" usemap=\"#timetable\">\n";

	if ($orientation eq 'vertical') {
		$result .= $gl->get_timetable_vertical_map ($times_list, $host_id, $host_db_h->user_can_write_host_config ($user, $host_id));
	} else {
		$result .= $gl->get_timetable_horizontal_map ($times_list, $host_id, $host_db_h->user_can_write_host_config ($user, $host_id));
	}

	return {
		box_head_name => 1,
		timetable => $host_name,
		content => $result,
	};
}

1;

# vim:foldmethod=marker
