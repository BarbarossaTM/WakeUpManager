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
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Wed 28 Nov 2007 02:48:36 AM CET
#

package WakeUpManager::Common::Logging::Linux;

use strict;
use base 'Exporter';
use Carp;

use Sys::Syslog qw(:standard :macros setlogsock);

our @EXPORT = qw(log_init log_and_die log_msg);

#
# Close log on exit
END { closelog(); }


#
# Valid loglevel without WakeUpManager
my $log_level = {
	err => LOG_ERR,
	error => LOG_ERR,

	warn => LOG_WARNING,
	warning => LOG_WARNING,

	notice => LOG_NOTICE,

	info => LOG_INFO,

	debug => LOG_DEBUG,
};


#
# Has to be called first!
sub log_init ($$) {
	my $self = shift;

	if ($self ne __PACKAGE__) {
		confess __PACKAGE__ . "->log_init() should never be called directly. Use WakeUpManager::Common::Logging instead.";
	}

	my $name = shift || "WakeUpManager";
	my $facility = shift || LOG_DAEMON;

	setlogsock('unix');
	openlog ($name, "ndelay,pid", $facility);
}


#
# Log an error and die
sub log_and_die ($) {
	my $self = shift;

	my $msg = shift;

	if ($self ne __PACKAGE__) {
		confess __PACKAGE__ . "->log_and_die() should never be called directly. Use WakeUpManager::Common::Logging instead.";
	}

	if (! defined $msg || ! length ($msg)) {
		confess "Empty log message...\n";
	}

	syslog (LOG_ERR, $msg);
	die ($msg);
}

#
# Log message
sub log_msg ($$) { # log (log_level, msg)
	my $self = shift;

	my $level = shift || LOG_USER;
	my $msg = shift;

	if ($self ne __PACKAGE__) {
		confess __PACKAGE__ . "->log_msg() should never be called directly. Use WakeUpManager::Common::Logging instead.";
	}

	if (! defined $msg || ! length ($msg)) {
		confess "Empty log message...\n";
	}

	if (! defined $log_level->{$level}) {
		confess "Invalid log level...\n";
	}

	syslog ($level, $msg);
}

1;

# vim:foldmethod=marker
