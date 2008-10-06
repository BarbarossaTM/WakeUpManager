#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Sun 08 Jun 2008 11:02:33 PM CEST
#

package WakeUpManager::Cmd::GetHostInfo;

use strict;
use Carp;

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

	my $preset_hostname = $args->{preset_hostname};
	if (! $preset_hostname || length ($preset_hostname) == 0 || ref ($preset_hostname)) {
		return undef;
	}

	# Get DBI parameters
	my $dbi_param = $args->{dbi_param};
	if ($dbi_param && ref ($dbi_param) ne 'ARRAY') {
		confess __PACKAGE__ . "->new(): Invalid dbi_param parameter.\n";
	} else {
		my $wum_config = WakeUpManager::Config->new ();
		if (! $wum_config) {
			confess __PACKAGE__ . "->new(): Failed to load Config\n";
		}

		$dbi_param = $wum_config->get_dbi_param ("HostDB");
		if (! $dbi_param) {
			confess __PACKAGE__ . "->new(): Failed to get dbi_param from wum.conf\n";
		}
	}

	# Setup DB connection
	my $host_db = WakeUpManager::DB::HostDB->new (dbi_param => $dbi_param);
	# Don't check db handle here, do it in get_host_info() instead.

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		host_db_h => $host_db,

		preset_hostname => $preset_hostname,
	}, $class;

	# Prepare for RPC::Wrapper wrappability
	$obj->{methods} = {
		'wakeUpManager.cmd.getHostInfo' => sub { $obj->get_host_info (@_) },
	};

	return $obj;
} #}}}

sub get_host_info () { # boot_host () : \%{ host_state, timetable } {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->boot_host(): Has to be called on bless'ed object.\n";
	}

	my $host_db = $self->{host_db_h};

	$self->{error_no} = 0;
	$self->{error_msg} = "";

	if (! $host_db_h) {
		$self->{error_no} = -4;
		$self->{error_msg} = "Could not connect to database.\n";
		return undef;
	}

	my $host_name = $self->{preset_hostname};
	my $host_id = $host_db->get_host_id ($host_name);
	if (! $host_id) {
		$self->{error_no} = -1;
		$self->{error_msg} = "Invalid hostname: \"$host_name\"\n";
		return undef;
	}

	my $host_state = $host_db->get_host_state ($host_id);
	if (! defined $host_state || ref ($host_state) ne 'HASH') {
		$self->{error_no} = -2;
		$self->{error_msg} = "Could not get host state.\n";
		return undef;
	}

	my $timetable = $host_db->get_times_of_host ($host_id);
	if (! $timetable || ref ($timetable) ne 'HASH') {
		$self->{error_no} = -3;
		$self->{error_msg} = "Could not get timetable or timetable is invalid.\n";
		return undef;
	}

	return {
		host_state => $host_state,
		timetable => $timetable,
	}
} # }}}


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


1;

# vim:foldmethod=marker
