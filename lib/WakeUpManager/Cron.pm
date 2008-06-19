#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Wed, 04 Jun 2008 15:24:01 +0200
#

package WakeUpManager::Cron;

our $VERSION = '0.1';

use strict;
use Carp;

use WakeUpManager::Agent::Connector;
use WakeUpManager::Common::Logging;
use WakeUpManager::Config;
use WakeUpManager::DB::HostDB;

my $default_config_file = "/etc/wum/wum.conf";

log_init ("wakeup-cron", "daemon");

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

	my $config_file = $args->{configfile} || $default_config_file;

	# WakeUpManager::Config will 'confess' on error...
	my $config = WakeUpManager::Config->new (config_file => $config_file);

	# Get DB handle for 'HostDB'
	my $dbi_param = $config->get_dbi_param ('HostDB');
	my $db_h = WakeUpManager::DB::HostDB->new (dbi_param => $dbi_param);
	if (! $db_h) {
		print STDERR "WakeUpManager::Cron: Failed to get connection to HostDB\n";
		exit 1;
	}

	my $agent_connector = WakeUpManager::Agent::Connector->new (host_db_h => $db_h);
	if (! $agent_connector) {
		print STDERR "Failed to get Agent::Connector\n";
		exit 2;
	}

	# Put new object together
	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		config => $config,
		db_h => $db_h,
		agent_connector => $agent_connector,
	}, $class;

	return $obj;
} #}}}


sub wake_them_up ($) {
	my $self = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	my $host_list = $self->{db_h}->get_hosts_to_start_within_next_window ('00:15');
	if (! $host_list) {
		log_msg ("err", "Error: Didn't get hostlist.\n");
		return undef;
	}

	my $host_count = scalar (@{$host_list});
	my $success_count = 0;

	if ($host_count > 0 ) {
		foreach my $host_data (@{$host_list}) {
			my $log_msg = "Booting host $host_data->[1] (#$host_data->[0]): ";
			if ($self->{agent_connector}->boot_host ($host_data->[0])) {
				$log_msg .= "succeeded.";
				$success_count++;
			} else {
				$log_msg .= "FAILED!";
			}

			log_msg ("info", "$log_msg\n");
		}

		log_msg ("info", "$success_count / $host_count hosts successfully bootet.\n");
	} else {
		log_msg ("info", "No hosts to boot.\n");
	}
}

1;

# vim:foldmethod=marker
