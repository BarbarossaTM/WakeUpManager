#!/usr/bin/perl -WT
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
