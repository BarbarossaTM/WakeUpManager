#!/usr/bin/perl -W -I C:\Programme\WakeUpManager\lib
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Mon 13 Jun 2008 00:34:23 PM CEST
#

use strict;
use Carp;

use WakeUpManager::Common::Utils qw(:timetable :state);
use WakeUpManager::RPC::Utils;
use WakeUpManager::Config;

use Frontier::Client 1.01;
use POSIX qw(strftime);

use Win32::OLE('in');

use constant wbemFlagReturnImmediately => 0x10;
use constant wbemFlagForwardOnly => 0x20;

#
# Satisfy -T switch
$ENV{'PATH'} = "c:\\Windows\\system32";

my $log_file = $ENV{PROGRAMFILES} . "\\WakeUpManager\\log\\wum.log";
open (LOG_FILE, ">> $log_file")
	or die "Could not open logfile \"$log_file\" for writing: $!\n";

sub log_msg ($$) {
	my $level = shift;
	my $msg = shift;
	chomp $msg;

	my $now_string = strftime ("%b %d %H:%M:%S", localtime);
	print LOG_FILE "$now_string $level: $msg\n";
}

sub log_and_die ($) {
	my $msg = shift;
	chomp $msg;

	log_msg ('err', $msg);
	die "Error: $msg\n";
}

################################################################################
#				Configuration				       #
################################################################################

# Default time in minutes to wait after machine has been booted before
# shutting down the PC.
my $boot_grace_time = 15;

# Default time window to consider in timetable to check for eventual
# boot event following a potential current shutdown event.
my $time_window = 15;


# Read additional configuration from file # {{{
my $config_file = $ENV{PROGRAMFILES} . "\\WakeUpManager\\etc\\wum.conf";

#
# Read config file
my $config = WakeUpManager::Config->new (config_file => $config_file);
if (! $config) {
	log_and_die ("Failed to read configuraton from \"$config_file\".");
}

my $client_opts =  $config->get_client_opts ();
if (! $client_opts) {
	log_and_die ("Could not get 'CLIENT' configuration from \"$config_file\".");
}

# Get URL of RPC connection for UI
if (! $client_opts->{RPC_URL}) {
	log_and_die ("RPC_URL no set in config file \"$config_file\".");
}


if ($client_opts->{boot_grace_time}) {
	$boot_grace_time = $client_opts->{boot_grace_time};
}

if ($client_opts->{time_window}) {
	$boot_grace_time = $client_opts->{time_window};
}
#}}}


################################################################################
#			Check for shutdown criteria			       #
################################################################################

#
# 0. Should this host be shut down by WUM?
if (! $client_opts->{do_shutdown}) {
	exit 0;
}

#
# 1. If host has been booted within the last 15 minutes, don't shutdown
my $objWMIService = Win32::OLE->GetObject("winmgmts:\\\\localhost\\root\\CIMV2")
	or die "WMI connection failed.\n";

my $osItems = $objWMIService->ExecQuery ("SELECT * FROM Win32_OperatingSystem",
                                         "WQL",
                                         wbemFlagReturnImmediately | wbemFlagForwardOnly);

my $LastBootUpTime = undef;
foreach my $objItem (in $osItems) {
	$LastBootUpTime = $objItem->{LastBootUpTime};
}
if (! defined $LastBootUpTime) {
	confess "Error while getting LastBootUpTime.\n";
}

my @now = localtime (time);
my @boot_time;
if ($LastBootUpTime =~ m/^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2}).*$/) {
	@boot_time = (0, $5, $4, $3, $2, $1-1900, undef, undef, undef);
}
if (! @boot_time) {
	confess "Error while gettint boot time.\n";
}


# Booted today
if ($boot_time[3] == $now[3] &&
    ($boot_time[4] * 60 + $boot_time[3]) - ($now[4] * 60 + $now[3]) <= $boot_grace_time) {
	log_msg ("info", "Machine is up for less than $boot_grace_time minutes. Staying cool.\n");
	exit 0;
}

# Booted yesterday
elsif ($boot_time[3] - $now[3] == 1 &&
       (24 * 60 - ($boot_time[4] * 60 + $boot_time[3]) + ($now[4] * 60 + $now[3])) <= $boot_grace_time) {
	log_msg ("info", "Machine is up for less than $boot_grace_time minutes. Staying cool.\n");
	exit 0;
}


#
# 2. If someone is logged in interactivly, don't shutdown
my $pcItems = $objWMIService->ExecQuery("SELECT * FROM Win32_ComputerSystem", "WQL",
	wbemFlagReturnImmediately | wbemFlagForwardOnly);

my $UserName = undef;
foreach my $item (in $pcItems) {
	$UserName = $item->{UserName};
}
if ($UserName) {
	log_msg ("info", "User $UserName is logged in. Staying cool.\n");
	exit 0;
}


#
# 3. Ask the WUM server for host state and timetable
#    If the host is inactive, don't shutdown
#    If the host is in an 'up' timeframe, don't shutdown


# Setup RPC connection
my $rpc_h = Frontier::Client->new (
	url => "$client_opts->{RPC_URL}/rpc/client",
	handle_perl_objects => 1);
if (! $rpc_h) {
	log_and_die ("Could not connect to server.\n");
}

# eval'uate the agent call as it will 'die' on error...
my $result = undef;
#eval {
	$result = $rpc_h->call ('wakeUpManager.cmd.getHostInfo');
#};

# Check the result of the RPC call
if (! defined $result || ! rpc_result_ok ($result)) {
	log_msg ("err", "Did not get (valid) result from server.\n");
	if (defined $result) {
		log_msg ("err", "Server reported: " . rpc_get_errmsg ($result) . "\n");
	}
	exit 1;
} else {
	my $rpc_value = rpc_get_value ($result);
	# In case of invalid data no change to take a decision
	if (ref ($rpc_value) ne 'HASH' ||
	    ref ($rpc_value->{timetable} ne 'HASH') ||
	    ref ($rpc_value->{host_state}) ne 'HASH') {
		log_and_die ("Got invalid result from server.\n");
	}

	# If host is not active, no reboot via WUM at all
	if (! $rpc_value->{host_state}->{shutdown_host}) {
		log_msg ("info", "Host is not active. Staying cool.\n");
		exit 1;
	}

	# If there is no entry in the timetable, there's nothing to do for us
	if (keys %{$rpc_value->{timetable}} == 0) {
		log_msg ("info", "No entry in timetable. Staying cool.\n");
		exit 1;
	}

	my $supposed_state = get_host_state ($rpc_value->{timetable});
	if ($supposed_state eq 'shutdown') {
		log_msg ("info", "Machine should be shut down. Good night.\n");
		system ('shutdown -s');
	} else {
		log_msg ("info", "Machine should not be shut down. Staying cool.\n");
		exit 0;
	}
}

# vim:foldmethod=marker
