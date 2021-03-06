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
#  --  Fri May 30 05:42:08 2008
#

package WakeUpManager::WWW::Utils;

use strict;
use base 'Exporter';
use Carp;

our @EXPORT = qw(gen_pretty_hostgroup_tree_select gen_pretty_hostlist p_error);


# No prottyping here...
sub _gen_pretty_hostgroup_tree_select_worker { # _gen_pretty_hostgroup_tree_select_worker (\@relust_list, \%hostgroup_tree, $depth, $first_print_level; \%hostgroup_whitelist) : {{{
	my $result_list = shift;

	my $rec_hostgroup_tree = shift;
	my $depth = shift;
	my $first_print_level = shift;

	my $hostgroup_whitelist = shift;

	my $print_level = 0;
	if (! $hostgroup_whitelist || ($hostgroup_whitelist && $hostgroup_whitelist->{$rec_hostgroup_tree->{id}})) {
		$print_level = 1;

		if (! defined $first_print_level) {
			$first_print_level = $depth;
		}
		my $indent = ($depth - $first_print_level) * 2;

		push @{$result_list}, { key => $rec_hostgroup_tree->{id}, val => "&nbsp;"x$indent . "&sdot;" . $rec_hostgroup_tree->{name} };
	}

	foreach my $key (keys %{$rec_hostgroup_tree->{members}}) {
		my $subgroup = $rec_hostgroup_tree->{members}->{$key};

		_gen_pretty_hostgroup_tree_select_worker ($result_list, $rec_hostgroup_tree->{members}->{$key}, $depth + $print_level, $first_print_level, $hostgroup_whitelist);
	}
} # }}}

sub gen_pretty_hostgroup_tree_select ($;$) { # gen_pretty_hostgroup_tree_select (\%hostgroup_tree ; \%hostgroup_whitelist) : \@hostgroup_list {{{
	my $self = shift;

	our $top_hostgroup_tree = shift;

	my $hostgroup_whitelist = shift;

	my @hostgroup_list;

	if (! $top_hostgroup_tree || ref ($top_hostgroup_tree) ne 'HASH') {
		confess __PACKAGE__ . "->pp_hostgroup_tree(): No or invalid 'hostgroup_tree' parameter.\n";
	}

	# All
	push @hostgroup_list, { key => 'ALL', val => 'ALL' };

	my $first_print_level = undef;
	if (! $hostgroup_whitelist || ($hostgroup_whitelist && $hostgroup_whitelist->{$top_hostgroup_tree->{id}})) {
		push @hostgroup_list, { key => $top_hostgroup_tree->{id}, val => $top_hostgroup_tree->{name} };
		$first_print_level = 0;
	}


	# XXX sorting?
	foreach my $key (keys %{$top_hostgroup_tree->{members}}) {
		_gen_pretty_hostgroup_tree_select_worker (\@hostgroup_list, $top_hostgroup_tree->{members}->{$key}, 1, $first_print_level, $hostgroup_whitelist);
	}

	return \@hostgroup_list;
} # }}}


sub gen_pretty_host_select ($;$) { # gen_pretty_host_select (\%hosts) : \@hostlist {{{
	my $self = shift;

	my $hosts = shift;
	my $append_host_state = shift;

	if (ref ($hosts) ne 'HASH') {
		return undef;
	}

	my @host_list;
	foreach my $key (sort {$hosts->{$a}->{name} cmp $hosts->{$b}->{name}} keys %{$hosts}) {
		my $val = "$hosts->{$key}->{name}";

		if ($append_host_state) {
			$val .= " (";
			$val .= ($hosts->{$key}->{boot_host}) ? "B" : "-";
			$val .= ($hosts->{$key}->{shutdown_host}) ? "S" : "-";
			$val .= ")";
		}

		push @host_list, { key => $key, val => $val };
	}

	return \@host_list;
} # }}}

sub p_error ($) {
	my $error_msg = shift;

	return "<p class=\"error\">$error_msg</p>";
}

1;

# vim:foldmethod=marker
