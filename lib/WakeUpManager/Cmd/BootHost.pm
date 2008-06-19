#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Fri 06 Jun 2008 10:38:02 PM CEST
#

package WakeUpManager::Cmd::BootHost;

use strict;

use Carp;

use WakeUpManager::Agent::Connector;
use WakeUpManager::Config;
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

	# Get DBI parameters
	my $dbi_param = $args->{dbi_param};
	if ($dbi_param && ref ($dbi_param) ne 'ARRAY') {
		confess __PACKAGE__ . "->new(): Invalid dbi_param parameter.\n";
	} else {
		my $wum_config = WakeUpManager::Config->new ();
		if (! $wum_config) {
			return undef;
		}

		$dbi_param = $wum_config->get_dbi_param ("HostDB");
		if (! $dbi_param) {
			return undef;
		}
	}

	# Setup DB connection
	my $host_db = WakeUpManager::DB::HostDB->new (dbi_param => $dbi_param);
	if (! $host_db) {
		return undef;
	}

	#
	# Agent connection
	my $agent_conn = WakeUpManager::Agent::Connector->new (host_db_h => $host_db);
	if (! $agent_conn) {
		return undef;
	}

	my $preset_uid = $args->{preset_uid} || undef;

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		error_no => 0,
		error_msg => "",

		host_db_h => $host_db,
		agent_conn => $agent_conn,

		preset_uid => $preset_uid,
	}, $class;

	# Prepare for RPC::Wrapper wrappability
	$obj->{methods} = {
		'wakeUpManager.cmd.bootHost' => sub { $obj->boot_host_by_name (@_) },
	};


	return $obj;
} #}}}

sub boot_host_by_name ($;$) {
	my $self = shift;

	my $host_name = shift;
	my $uid = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->boot_host_by_name(): Has to be called on bless'ed object.\n";
	}

	if (! defined $host_name || length ($host_name) == 0) {
		$self->{error_no} = -1;
		$self->{error_msg} = "No hostname given.\n";
		return undef;
	}

	if (! defined $uid) {
		$uid = $self->{preset_uid};
		if (! defined $uid) {
			$self->{error_no} = -2;
			$self->{error_msg} = "No uid provided and none preset.\n";
			return undef;
		}
	}

	my $host_db = $self->{host_db_h};

	$self->{error_no} = 0;
	$self->{error_msg} = "";

	my $host_id = $host_db->get_host_id ($host_name);
	if (! defined $host_id) {
		$self->{error_no} = -3;
		$self->{error_msg} = "Invalid hostname \"$host_name\" given.\n";
		return undef;
	}

	return $self->boot_host ($host_id, $uid);
}

sub boot_host ($$) { # boot_host (host_id, uid) 
	my $self = shift;

	my $host_id = shift;
	my $uid = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->boot_host(): Has to be called on bless'ed object.\n";
	}

	my $host_db = $self->{host_db_h};

	$self->{error_no} = 0;
	$self->{error_msg} = "";

	if (! $host_db->is_valid_host ($host_id)) {
		$self->{error_no} = -4;
		$self->{error_msg} = "Invalid host_id given.\n";
		return undef;
	}

	# This _should_ work as we checked the host_id
	my $host_name = $host_db->get_host_name ($host_id) || "#$host_id";

	#
	# So try to boot the host
	if (! $host_db->user_can_boot_host ($uid, $host_id)) {
		$self->{error_no} = -5;
		$self->{error_msg} = "User \"$uid\" does not have the right to boot host \"$host_name\" (#$host_id)\n";
		return undef;
	}


	if ($self->{agent_conn}->boot_host ($host_id)) {
			return 1;
	} else {
		$self->{error_no} = -6;

		my $error_msg = $self->{agent_conn}->get_errormsg ();
		if ($error_msg) {
			$self->{error_msg} = $error_msg;
		} else {
			$self->{error_msg} = "An unknown error occured while booting host \"$host_name\" (#$host_id)\n";
		}

		return undef;
	}
}


sub get_error_no () { # get_error_msg () : $self->{error_no} {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->boot_host(): Has to be called on bless'ed object.\n";
	}

	return $self->{error_no};
} # }}}

sub get_error_msg () { # get_error_msg () : $self->{error_msg} {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->boot_host(): Has to be called on bless'ed object.\n";
	}

	return $self->{error_msg};
} # }}}

sub get_methods () { # get_methods () : \%methods {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->boot_host(): Has to be called on bless'ed object.\n";
	}

	return $self->{methods};
} # }}}

1;

# vim:foldmethod=marker
