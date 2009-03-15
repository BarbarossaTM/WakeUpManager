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
