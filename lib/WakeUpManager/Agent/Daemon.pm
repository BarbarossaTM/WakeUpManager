#!/usr/bin/perl -WT
#
#   WakeUpManager suite
#
#   Copyright (C) 2007-2009 Maximilian Wilhelm <max@rfc2324.org>
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
# WakeUpManager Agent
#
# Maximilian Wilhelm <max@rfc2324.org>
#  -- Tue, 30 Oct 2007 02:09:35 +0100
#

package WakeUpManager::Agent::Daemon;

our $VERSION = "0.1";

use strict;
use Carp;
use Net::CIDR;

use WakeUpManager::Config;
use WakeUpManager::Common::Logging;
use WakeUpManager::RPC::Utils;

my $default_configfile = "/etc/wum/agent.conf";

my @utils = ('etherwake');

log_init ("wakeup-agent", "daemon");

#
# Make tainted perl happy!
$ENV{PATH} = "/bin:/sbin:/usr/bin:/usr/sbin";

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

sub new () { # new (configfile => <string>, debug => <int>, verbose => <int>) : \WakeUpManager::Agent::Daemon {{{
	my $self = shift;
	my $class = ref ($self) || $self;

	log_msg ("info", "WakeUpManager Agent Daemon version $VERSION startup...\n");
	# Make life easy

	my $args = &_options (@_);

	# Verbosity
	my $debug = (defined $args->{debug}) ? $args->{debug} : 0;
	my $verbose = (defined $args->{verbose}) ? $args->{verbose} : $debug;

	my $config_file = defined $args->{config_file} ? $args->{config_file} : $default_configfile;

	# Get configuration
	my $config = WakeUpManager::Config->new (
		verbose => $verbose,
		debug => $debug,
		config_file => $config_file);
	if (! $config) {
		log_and_die ("Could not read Agent configuration from \"$config_file)\"! Exiting.\n");
	}
	my $agent_config = $config->get_agent_opts ();

	# Create instance
	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		config => $agent_config,
		configfile => $config_file,
		}, $class;

	$obj->_init_config ();

	# Check if all tools are available
	$obj->_check_utils ();

	$obj->{methods} = {
		'wakeUpManager.agent.bootUp' => sub { $obj->boot_pc (@_) },
	};

	return $obj;
} #}}}


#
# Check if all required tools are available
# Exit program imediatly if one tool is missing, expaining the problem
sub _check_utils () { # _check_tools : <exit> {{{
	my $self = shift;

	foreach my $util (@utils) {
		if (system ("command -v $util >/dev/null 2>/dev/null")) {
			log_and_die  ("Error: Required utility \"$util\" could not be found on your system... Exiting.\n");
		}
	}
} #}}}

sub get_methods () { # get_methods () : \% {{{
	my $self = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	return $self->{methods};
} # }}}



################################################################################
#				Configuration				       #
################################################################################

sub _init_config () { # _init_config () : {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_init(): Has to be called on a bless'ed object.\n";
	}

	my $config = $self->{config};
	my $configfile = $self->{configfile};

	# Scan for  / read network_to_device_map {{{
	my $network_to_device_map = undef;
	if ($config->{network_to_device_map} eq 'scan') {
		$network_to_device_map = $self->_get_network_to_device_map ();
		if (! $network_to_device_map) {
			log_and_die ("Error: Should scan for networks and devices but didn't find anything.\n");
		}
		$config->{network_to_device_map} = $network_to_device_map;
	}

	elsif (ref ($config->{network_to_device_map}) eq 'HASH') {
		$config->{network_to_device_map} = $config->{network_to_device_map};
	}

	# }}}

	# Check and sanitize allowed_clients list {{{
	if ($config->{allowed_clients}) {
		if (ref ($config->{allowed_clients}) ne 'ARRAY') {
			log_and_die ("Error: \"allowed_clients\" option has to be specified as a listref in \"$configfile\".\n");
		}

		my @cidr_list;
		foreach my $entry (@{$config->{allowed_clients}}) {
			# Net::CIDR::cidrvalidate will only validate IP adddresse...
			if ($entry =~ m/^([[:digit:].]+)\/([[:digit:]]{1,2})$/) {
				my ($ip, $mask) = ($1, $2);
				if (! Net::CIDR::cidrvalidate ($ip) || $mask > 32) {
					log_and_die ("Invalid value to allowed_clients \"$entry\" in \"$configfile\"... Exiting.\n");
				}
			}

			elsif (! Net::CIDR::cidrvalidate ($entry)) {
				log_and_die ("Invalid value to allowed_clients \"$entry\" in \"$configfile\"... Exiting.\n");
			}

			@cidr_list = Net::CIDR::cidradd ($entry, @cidr_list);
		}
		$config->{allowed_clients} = \@cidr_list;
	} # }}}

} # }}}

#
# Build up a list of all IP networks connected to ethernet interfaces and
# return a ref to a hash with an ip network in CIDR notation as key and the
# device it is connected to as value.
#
sub _get_network_to_device_map () { # _get_network_to_device_map () : \% {{{
	my $self = shift;

	# Store network devices pointing to a list pointer
	my $devices_to_cidrnetworks = {};

	# Store networks in CIDR notation pointing to the interface(s) they are bound to
	my $network_to_device_map;

	# Detect badness
	if (! $self || ref($self) ne __PACKAGE__) {
		confess "DAMN\n";
	}

	log_msg ("info", "Saerching for network devices and connected networks...\n") if ($self->{verbose});

	#
	# Gather a list of all networks connected to all interfaces
	#

	# Prefer 'ip addr' over ifconfig as it's way more flexible
	if (! system ("which ip >/dev/null")) { # {{{
		open (IP_ADDR, "ip addr |")
			or log_and_die ("Failed to run 'ip addr'... Exiting.\n");

		my $device = undef;
		while (my $line = <IP_ADDR>) {
			chomp $line;

			if ($line =~ m/^[0-9]+: ([[:alnum:]._-]+): /) {
				$device = $1;
				next;
			}

			if ($device) {
				# We're only interested in ethernet devices
				if ($line =~ m/^[[:space:]]+link\/(\w+) /) {
					log_msg ("info", "Found device $device") if ($self->{verbose});

					if ($1 ne 'ether') {
					log_msg ("info", "Skipped $device, as it's not ethernet device\n") if ($self->{verbose});
						$device = undef;
						next;
					}
				}

				elsif ($line =~ m/^[[:space:]]+inet ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}) /) {
					if (! $devices_to_cidrnetworks->{$device}) {
						$devices_to_cidrnetworks->{$device} = [];
					}

					my @cidrlist = Net::CIDR::cidradd ($1, @{$devices_to_cidrnetworks->{$device}});
					$devices_to_cidrnetworks->{$device} = \@cidrlist;
				}
			}
		}

		close (IP_ADDR);
	} # }}}

	# OK, second try.
	elsif (! system ("which ifconfig >/dev/null")) { #{{{
		log_msg ("warn", "Warning: 'ip' not found. Using 'ifconfig' to get list of connected networks.\n");
		log_msg ("warn",  "If you added IPs via 'ip', they will be missed.\n");

		open (IFCONFIG, "ifconfig |")
			or log_and_die ("Failed to run 'ifconfig'... Exiting.\n");

		my $device = undef;
		while (my $line = <IFCONFIG>) {
			chomp $line;

			if ($line =~ m/^([[:alnum:]._-]+)(:[0-9]+)?[[:space:]]+Link encap:(\w+) /) {
				$device = $1;

				log_msg ("info", "Found device $device.") if ($self->{verbose});
				# We're only interested in ethernet devices
				if ($3 ne 'Ethernet') {
					log_msg ("info", "Skipped $device, as it's not ethernet device\n") if ($self->{verbose});
					$device = undef;
					next;
				}
				log_msg ("info", "\n") if ($self->{verbose});


				if (! $devices_to_cidrnetworks->{$device}) {
					$devices_to_cidrnetworks->{$device} = [];
				}

				next;
			}

			if ($device) {
				if ($line =~ m/^[[:space:]]+inet addr:([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}).+Mask:([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/) {
					my ($ip, $netmask) = ($1, $2);

					my $cidr = Net::CIDR::addrandmask2cidr ($1, $2);
					my @cidrlist = Net::CIDR::cidradd ($cidr, @{$devices_to_cidrnetworks->{$device}});
					$devices_to_cidrnetworks->{$device} = \@cidrlist;

				}
			}
		}

		close (IFCONFIG);
	} #}}}

	# bad $PATH?
	else {
		log_and_die ("Neither 'ip' nor 'ifconfig' were found on your system... Exiting.\n");
	}

	#
	# Mundge "device to networks" list to "network to device" list
	#
	foreach my $device (keys %{$devices_to_cidrnetworks}) {
		my @networks = @{$devices_to_cidrnetworks->{$device}};

		foreach my $network (@networks) {
			if (! $network_to_device_map->{$network}) {
				$network_to_device_map->{$network} = [];
			}

			push @{$network_to_device_map->{$network}}, $device;
		}

		log_msg ("info", "Networks found at $device: " . join (', ', @networks) . "\n") if ($self->{verbose});
	}

	return $network_to_device_map;
} #}}}

sub get_devices_for_ip ($) { # get_devices_for_ip (ip) : @devices {{{
	my $self = shift;

	my $ip = shift;

	# Check parameter
	if (! $ip) {
		log_msg ("err", __PACKAGE__ . "->get_devices_for_ip() called without IP...\n");
		return undef;
	}

	# Build up a list of devices this IP lives in
	my $network_to_device_map = $self->{config}->{network_to_device_map};
	my $devices_list = undef;
	foreach my $cidr_network (keys %{$network_to_device_map}) {
		if (Net::CIDR::cidrlookup ($ip, ("$cidr_network") )) {
			if (! defined $devices_list) {
				$devices_list = [];
			}
			push @{$devices_list}, @{$network_to_device_map->{$cidr_network}};
		}
	}

	return $devices_list;
} # }}}


sub get_allowed_clients () { # get_allowed_clients() : \@ {{{
	my $self = shift;

	return $self->{config}->{allowed_clients};
} # }}}


################################################################################
#			      Real work functions			       #
################################################################################

#
# Boot PC with mac address 'mac_addr' and IP 'ip_addr'
# ('ip_addr' need not to be the exact IP of the host to be bootet, but has to
#  be in the same subnet)
sub boot_pc ($$) { # boot_pc (mac_addr, ip_addr) : \WakeUpManager::RPC::Result {{{
	my $self = shift;

	my $mac_addr = shift;
	my $ip = shift;

	if  (! defined $mac_addr || ! ($mac_addr =~ m/^[[:xdigit:]]{2}:[[:xdigit:]]{2}:[[:xdigit:]]{2}:[[:xdigit:]]{2}:[[:xdigit:]]{2}:[[:xdigit:]]{2}$/)) {
		log_msg ("err", "boot_pc(): Missing or invalid mac address \"$mac_addr\".\n");
		return rpc_return_err (-23, "boot_pc(): Missing or invalid mac address \"$mac_addr\".\n");
	}

	if (! defined $ip || ! Net::CIDR::cidrvalidate ($ip)) {
		log_msg ("err", "boot_pc(): Missing or invalid ip address \"$ip\".\n");
		return rpc_return_err (-23, "boot_pc(): Missing or invalid ip addres \"$ip\".\n");
	}

	# Try to figure out which device should be used to send the magic packet
	my $send_device_list = $self->get_devices_for_ip ($ip);
	if (! $send_device_list) {
		log_msg ("err", "boot_pc(): Could not get local device for ip \"$ip\"\n");
		return rpc_return_err (-23, "boot_up(): Could not get local device for ip \"$ip\"");
	}

	# Maybe there are multiple devices, so why not use all of them..?
	my $ret = 0;
	foreach my $device (@{$send_device_list}) {
		my $retcode = system ("etherwake -i $device $mac_addr 2>/dev/null");

		$ret += $retcode;
	}

	my $msg = "Sending wakeup packet to \"$mac_addr\"";

	if ($ret != 0) {
		log_msg ("err", "boot_pc(): $msg failed.\n");
		return rpc_return_err (1, "$msg failed.\n");
	} else {
		log_msg ("info", "boot_pc(): $msg succeded.\n") if ($self->{verbose});
		return rpc_return_ok ("");
	}
} # }}}

1;

# vim:foldmethod=marker
