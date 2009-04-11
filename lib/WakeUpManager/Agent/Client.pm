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
#  This class is the client to talk to the WakeUpManager::Agent::Daemon.
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Mon 26 May 2008 05:12:16 PM CEST
#

package WakeUpManager::Agent::Client;

use strict;
use Carp;

use WakeUpManager::RPC::Utils;

use Net::CIDR;
use Frontier::Client;

#
# Connect to agents on this port
my $default_agent_port = 2342;


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

	# Get the IP of the agent to connect to
	my $agent_ip = $args->{agent_ip};
	if (! defined $agent_ip || ! Net::CIDR::cidrvalidate ($agent_ip)) {
		confess __PACKAGE__ . "->new(): Error: No or invalid 'agent_ip' paramter given.\n";
	}

	# Maybe a port has been specified
	my $agent_port = (defined $args->{debug}) ? $args->{debug}: $default_agent_port;
	if ($agent_port < 0 || $agent_port > 65535) {
		confess __PACKAGE__ . "->new(): Error: Invalid 'agent_port' parameter given.\n";
	}

	# Try to connect to given Agent
	my $agent_h = Frontier::Client->new (url => "http://$agent_ip:$agent_port/RPC2");

	if (! $agent_h) {
		# XXX Logging?
		confess __PACKAGE__ . "->new(): Could not connect to agent at $agent_ip:$agent_port.\n";
		return undef;
	}

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		agent_ip => $agent_ip,
		agent_port => $agent_port,
		agent_h => $agent_h,
	}, $class;

	return $obj;
} #}}}

#
# Tell the agent we are connected to, to send a magic packet to the host
# with the given. Use the given ip_address to figure out which interface
# to use to send out the magic packet.
#
sub boot_pc ($$) { # boot_pc (mac_address, ip_address) : 0/1
	my $self = shift;

	my $mac_addr = shift;
	my $ip_addr = shift;

	# Called on blessed object?
	return undef if (ref ($self) ne __PACKAGE__);

	# Strip any trailing CIDR netmask from the IP
	$ip_addr =~ s/\/[0-9]{1,2}$//;

	#
	# eval'uate the agent call as it will 'die' on error...
	my $result = undef;
	eval {
		$result = $self->{agent_h}->call ('wakeUpManager.agent.bootUp',
		                                  $mac_addr,
		                                  $ip_addr);
	};

	# Check the result of the RPC call
	if (! defined $result || ! rpc_result_ok ($result)) {
print STDERR "Error while running call on agent at $self->{agent_ip}:$self->{agent_port}.\n";
print STDERR " Agent reported:" . rpc_get_errmsg ($result) . "\n" if (defined $result);
		return 0;
	} else {
		return 1;
	}
}

1;

# vim:foldmethod=marker
