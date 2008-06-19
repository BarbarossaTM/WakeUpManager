#!/usr/bin/perl -WT
#
#  This class is part of the WakeUpManager suite.
#
#  This class is the interface which should be used by programmers to boot
#  a specific maschine.
#
#  This call will lookup the host in the HostDB, figure out which agent to
#  trigger for booting the host and actually make the ageht to send the
#  wakeup packet.
#
# Maximilian Wilhelm <max@rfc2324.org>
#  -- Thu, 29 May 2008 02:13:55 +0200
#


package WakeUpManager::Agent::Connector;

use strict;
use Carp;

use WakeUpManager::Agent::Client;
use WakeUpManager::DB::HostDB;


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

	my $host_db_h = $args->{host_db_h};
	my $host_db_dbi_param = $args->{host_db_dbi_param};

	if (! defined $host_db_h && ! defined $host_db_dbi_param) {
		confess __PACKAGE__ . "->new(): One of 'host_db_h' and 'host_db_dbi_param' has to be set\n";
	}

	# Prefer existing DB connection over new one
	if (defined $host_db_h && ref ($host_db_h) ne 'WakeUpManager::DB::HostDB') {
		confess __PACKAGE__ . "->new(): Invalid HostDB handle given.\n";
	}

	if (! defined $host_db_h && defined $host_db_dbi_param) {
		if (ref ($host_db_dbi_param) ne 'ARRAY') {
			confess __PACKAGE__ . "->new(): Invalid HostDB DBI parameters given.\n";
		} else {
			# HostDB will die on error...
			$host_db_h = WakeUpManager::DB::HostDB->new (dbi_param => $host_db_dbi_param);
			if (! $host_db_h) {
				confess __PACKAGE__ . "->new(): Failed to fire up HostDB object.\n";
			}
		}
	}

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		agent_conn => {},

		host_db => $host_db_h,

		errormsg => undef,
	}, $class;

	return $obj;
} #}}}

sub boot_host ($) { # boot_host (host_id) : 0/1 # {{{
	my $self = shift;

	my $host_id = shift;

	my $host_db = $self->{host_db};
	my $agent_h_cache = $self->{agent_handle_cache};

	# Called on blessed object?
	return undef if (ref ($self) ne __PACKAGE__);

	$self->{error_msg} = undef;

	# If we don't know the hostname, no chance
	if (! $host_db->is_valid_host ($host_id)) {
		$self->$self->{error_msg} = "Invalid host with ID \"$host_id\".\n";
		return undef;
	}

	# Get the ID of the net the host resides in
	my $host_boot_info = $host_db->get_host_boot_info ($host_id);
	if (! defined $host_boot_info) {
		$self->{error_msg} = "Could not get host boot information for host with ID \"$host_id\".\n";
		return undef;
	}

	my @agents = $host_db->get_agents_for_network ($host_boot_info->{net_id});
	if (! @agents) { # defined @... is depreciated
		# Handle case that there is no agent for network
		$self->{error_msg} = "No agent found for network #$host_boot_info->{net_id} (host ID $host_id)\n";
		return undef;
	}

	# Ok, try sending a wakeup
	my $could_send_packet = 0;
	foreach my $agent_id (@agents) {
		if ($self->_boot_pc_using_agent ($agent_id,
		                                  $host_boot_info->{mac_addr},
		                                  $host_boot_info->{net_cidr})) {
# XXX TODO
# Add option 'send_via_all_agents' or 'use_all_agents' ...
			$could_send_packet++;
		}
	}

	return $could_send_packet;
} # }}}

sub get_errormsg () { # get_errormsg () : $self->{error_msg} {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_errormsg(): Has to be called on bless'ed object.\n";
	}

	return $self->{error_msg};
} # }}}

sub _boot_pc_using_agent ($$$) { # boot_pc_using_agent (agent_id, mac_addr, net_cidr) : 0/1 {{{
	my $self = shift;

	my $agent_id = shift;

	my $mac_addr = shift;
	my $net_cidr = shift;

	my $agent_ip = undef;

	# Called on blessed object?
	return undef if (ref ($self) ne __PACKAGE__);

	# Got valid agent id?
	return undef if (! $self->{host_db}->is_valid_agent_id ($agent_id));

	# Got mac_addr and net_cidr?
# XXX
	return undef if (! $mac_addr or ! $net_cidr);


	# Use already created agent client, if there
	if (! defined $self->{agent_conn}->{$agent_id}) {
		$agent_ip = $self->{host_db}->get_agent_ip ($agent_id);
		confess "Could not get IP for agent #$agent_id\n" if (! defined $agent_ip);

		# Strip any trailing netmask
		$agent_ip =~ s/\/[0-9]+$//;

		$self->{agent_conn}->{$agent_id} = WakeUpManager::Agent::Client->new (
			agent_ip => $agent_ip);
	}

	# Now there *should* be an agent client handle
	if (! $self->{agent_conn}->{$agent_id}) {
# XXX Logging?
		return undef;
	}

	return $self->{agent_conn}->{$agent_id}->boot_pc ($mac_addr, $net_cidr);
} # }}}

1;

# vim:foldmethod=marker
