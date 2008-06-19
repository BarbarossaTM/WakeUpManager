#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Thu May 29 20:20:06 2008
#

package WakeUpManager::WWW::Page::BootHost;

use strict;
use Carp qw(cluck confess);

use WakeUpManager::Config;
use WakeUpManager::DB::HostDB;
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

	# Read wum.conf
	my $wum_config = WakeUpManager::Config-> new (config_file => "/etc/wum/wum.conf");
	if (! $wum_config) {
		cluck __PACKAGE__ . "->new(): Could not get 'wum_config'...";
		return undef;
	}

	# Setup DB handle but don't check it here!
	my $host_db_h = WakeUpManager::DB::HostDB-> new (dbi_param => $wum_config->get_dbi_param ('HostDB'));

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		host_db_h => $host_db_h,

		params => $params,

		wum_config => $wum_config,
	}, $class;

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

	my $user = $self->{params}->get_auth_info()->{user};

	our $bootable_hostgroups = $self->{host_db_h}->hostgroups_user_can_boot ($user);
	our $bootable_hosts = $self->{host_db_h}->hosts_user_can_boot ($user);

	# The really cool version of output formatting[tm]
	my $ALL_hostgroup_id = $self->{host_db_h}->get_hostgroup_id ('ALL');
	if ($ALL_hostgroup_id) {
		my $hostgroup_tree = $self->{host_db_h}->get_hostgroup_tree_below_group ($ALL_hostgroup_id);
		$content_elements->{hostgroup_loop} = WakeUpManager::WWW::Utils->gen_pretty_hostgroup_tree_select ($hostgroup_tree, $bootable_hostgroups);
	}

	if ($bootable_hosts) {
		$content_elements->{host_loop} = WakeUpManager::WWW::Utils->gen_pretty_host_select ($bootable_hosts);
	}

	return $content_elements;
}

1;

# vim:foldmethod=marker
