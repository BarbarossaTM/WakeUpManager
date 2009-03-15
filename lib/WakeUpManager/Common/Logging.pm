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
#  --  Thu 12 Jun 2008 11:35:14 PM CEST
#

package WakeUpManager::Common::Logging;

use strict;
use base 'Exporter';
use Carp;

our @EXPORT = qw(log_init log_msg log_and_die);

my $OS = $^O;
my $OS_Logging_Module = undef;

#
# Log to syslog
if ($OS eq 'linux') {
	require WakeUpManager::Common::Logging::Linux;
	$OS_Logging_Module = "WakeUpManager::Common::Logging::Linux";
}

#
# Log to Windows Eventlog[tm]
elsif ($OS eq 'MSWin32') {
	require WakeUpManager::Common::Logging::Win32;
	$OS_Logging_Module = "WakeUpManager::Common::Logging::Win32";
}

sub log_init ($$) {
	my $name = shift;
	my $facility = shift;

	$OS_Logging_Module->log_init ($name, $facility);
}

sub log_msg ($$) {
	my $level = shift;
	my $msg = shift;

	$OS_Logging_Module->log_msg ($level, $msg);
}

sub log_and_die ($) {
	my $msg = shift;

	$OS_Logging_Module->log_and_die ($msg);
}
