#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Thu 12 Jun 2008 11:58:02 PM CEST
#

package WakeUpManager::Common::Logging::Win32;

use strict;
use base 'Exporter';
use Carp;

use Win32::EventLog;

our @EXPORT = qw(log_init log_and_die log_msg);


my $handle = undef;

END {
	if (defined $handle) {
		$handle->Close ();
	}
}


#
# Valid loglevel without WakeUpManager
my $log_level = {
	err => 'EVENTLOG_ERROR_TYPE',
	error => 'EVENTLOG_ERROR_TYPE',

	warn => 'EVENTLOG_WARNING_TYPE',
	warning => 'EVENTLOG_WARNING_TYPE',

	notice => 'EVENTLOG_INFORMATION_TYPE',

	info => 'EVENTLOG_INFORMATION_TYPE',

	audit_success => 'EVENTLOG_AUDIT_SUCCESS',

	audit_failure => 'EVENTLOG_AUDIT_FAILURE',
};


#
# Has to be called first!
sub log_init ($$) {
	my $self = shift;

	my $name = shift || "WakeUpManager";
	my $facility = shift;

	if ($self ne __PACKAGE__) {
		confess __PACKAGE__ . "->log_init() should never be called directly. Use WakeUpManager::Common::Logging instead.\n";
	}

	if (! ($facility =~ m/^(Application|System|Security)$/)) {
		confess __PACKAGE__ . "->log_init(): Facility has to be one of \"Application\", \"System\" or \"Security\"\n";
	}

#	$handle = Win32::EventLog->new ($facility);
}


#
# Log an error and die
sub log_and_die ($) {
	my $self = shift;

	my $msg = shift;

	if ($self ne __PACKAGE__) {
		confess __PACKAGE__ . "->log_and_die() should never be called directly. Use WakeUpManager::Common::Logging instead.\n";
	}

	if (! defined $msg || ! length ($msg)) {
		confess "Empty log message...\n";
	}

	log_msg ('err', $msg);
	die ($msg);
}

#
# Log message
sub log_msg ($$) { # log (log_level, msg)
	my $self = shift;

	my $level = shift || "info";
	my $msg = shift;

	if ($self ne __PACKAGE__) {
		confess __PACKAGE__ . "->log_msg() should never be called directly. Use WakeUpManager::Common::Logging instead.\n";
	}

	if (! defined $msg || ! length ($msg)) {
		confess "Empty log message...\n";
	}

	if (! defined $log_level->{$level}) {
		confess "Invalid log level...\n";
	}

#	$handle->Report ({
#			Category => "WakeUpManager",
#
#			EventType => $log_level->{level},
#
#			Strings => $msg,
#		});
}

1;

# vim:foldmethod=marker
