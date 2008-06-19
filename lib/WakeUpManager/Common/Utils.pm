#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Sat 12 Jan 2008 08:07:21 PM CET
#

package WakeUpManager::Common::Utils;

use strict;
use base 'Exporter';

our @EXPORT    = qw();
our @EXPORT_OK = qw(string2time dow_to_day get_times_list get_times_by_hour get_host_state);
our %EXPORT_TAGS = (
	time => [qw(string2time dow_to_day)],
	timetable => [qw(get_times_list get_times_by_hour)],
	state => [qw(get_host_state)],
	all => \@EXPORT_OK
);

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

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

	}, $class;

	return $obj;
} #}}}

sub string2time ($) { # string2time (<int>[ms]) : 00:<min>:<sec> # {{{
	my $string = shift;

	if ($string && ! ref ($string)) {
		# minutes
		if ($string =~ m/^([0-9]{1,2})m$/) {
			return ($1 < 10) ? "00:0$1:00" : "00:$1:00";
		}

		elsif ($string =~ m/^([0-9]{1-3})s$/) {
			my $sec = $1;
			my $min = 0;

			{
				use integer;

				$min = $sec / 60;
				$sec = $sec - ($min * 60);
			}

			return ($min < 10 ) ? "00:0$min:$sec" : "00:$min:$sec";
		}
	}

	return undef;
} # }}}

sub dow_to_day ($) { # dow_to_day (dow) : day_name {{{
	my $day_of_week = shift;

	if (! defined $day_of_week || $day_of_week =~ m/[^0-9]/) {
		return undef;
	}

	my $days = {
		0 => 'sun',
		1 => 'mon',
		2 => 'tue',
		3 => 'wed',
		4 => 'thu',
		5 => 'fri',
		6 => 'sat',
		7 => 'sun',
	};

	return $days->{$day_of_week};
} # }}}


################################################################################
#			       Time table helpers			       #
################################################################################

sub _by_timestamp () { # [SORT HELPER] _by_timestamp() : -1/0/1 {{{
	my @val_a = split (':', $a);
	my @val_b = split (':', $b);

	return ($val_a[0] * 60 + $val_a[1]) <=> ($val_b[0] * 60 + $val_b[1]);
} # }}}

sub get_times_list ($) { # {{{
	my $times_from_db = shift;

	if (! $times_from_db || ref ($times_from_db) ne 'HASH') {
		return undef;
	}

	#
	# Convert times into useful format
	my $times = {
		mon => [],
		tue => [],
		wed => [],
		thu => [],
		fri => [],
		sat => [],
		sun => [],
	};
	my $times_current_handle = {};

	# Initialize host state as down
	my $host_state = {
		mon => 0,
		tue => 0,
		wed => 0,
		thu => 0,
		fri => 0,
		sat => 0,
		sun => 0,
	};

	foreach my $day ('mon','tue','wed','thu','fri','sat','sun') {
		my $day_hash = $times_from_db->{$day};

		foreach my $timestamp (sort _by_timestamp keys %{$day_hash}) {
			if ($day_hash->{$timestamp}->{action} eq 'boot') {
				if (! $host_state->{$day}) {
					$host_state->{$day} = 1;

					my $hash = {
						'boot' => $timestamp,
						'shutdown' => undef,
					};

					push @{$times->{$day}}, $hash;
					$times_current_handle->{$day} = $hash;
				} else {
					# XXX
					print "Two boot entries for day \"$day\"...\n";
				}
			}

			elsif ($day_hash->{$timestamp}->{action} eq 'shutdown') {
				if ($host_state->{$day}) {
					$host_state->{$day} = 0;
					$times_current_handle->{$day}->{shutdown} = $timestamp;
				} else {
					# XXX
					print "Shutdown entry for down host on day \"$day\"...\n";
				}
			}

			else {
				print "Unknown event type \"$day_hash->{$timestamp}->{action}\"...\n";
			}
		}
	}

	return $times;
} # }}}

sub get_times_by_hour ($) { # {{{
	my $times_from_db = shift;

	my $times_list = get_times_list ($times_from_db);
	if (! $times_list || ref ($times_list) ne 'HASH') {
		die;
	}

	my $times_by_hour = {};
	for (my $n = 0; $n < 24; $n++) {
		$times_by_hour->{$n} = {};
	}

	foreach my $day ('mon','tue','wed','thu','fri','sat','sun') {
		my $day_hash = $times_list->{$day};

		for my $entry (@{$day_hash}) {
			my @boot_time_triple = split (':', $entry->{boot});
			my @shutdown_time_triple = split (':', $entry->{shutdown});

			my $time_info = "$boot_time_triple[0]:$boot_time_triple[1] - $shutdown_time_triple[0]:$shutdown_time_triple[1]";

			$boot_time_triple[0] *= 1;
			$shutdown_time_triple[0] *= 1;

			if (! $times_by_hour->{$boot_time_triple[0]}->{$day}) {
				$times_by_hour->{$boot_time_triple[0]}->{$day} = [];
			}

			push @{$times_by_hour->{$boot_time_triple[0]}->{$day}}, [ 'down', $boot_time_triple[1], "" ];

			if ($boot_time_triple[0] == $shutdown_time_triple[0]) {
				push @{$times_by_hour->{$boot_time_triple[0]}->{$day}}, [ 'up', ($shutdown_time_triple[1] - $boot_time_triple[1]), $time_info ];
			} else {
				push @{$times_by_hour->{$boot_time_triple[0]}->{$day}}, [ 'up', (60 - $boot_time_triple[1]), $time_info ];

				# Loop over every hour between boot and shutdown time and place the correct img
				for (my $hour = $boot_time_triple[0] + 1; $hour <= $shutdown_time_triple[0]; $hour++) {
					if ($hour == $shutdown_time_triple[0] &&
					    $shutdown_time_triple[1] == 0) {
						next;
					}

					if (! $times_by_hour->{$hour}->{$day}) {
						$times_by_hour->{$hour}->{$day} = [];
					}

					# If we reached the hour the host will be shut down
					if ($hour == $shutdown_time_triple[0]) {
						push @{$times_by_hour->{$hour}->{$day}}, [ 'up', ($shutdown_time_triple[1] - $boot_time_triple[1]), $time_info ];


					} else {
						push @{$times_by_hour->{$hour}->{$day}}, [ 'up', 60, $time_info ];
					}
				}
			}
		}
	}

#	#
#	# Strip every eventless hour before or after an every period
#	my $hours_to_delete = {};
#	my $found_event = 0;
#	my $after_event = 0;
#	for (my $hour = 0; $hour < 24; $hour++) {
#		if (keys %{$times_by_hour->{$hour}} == 0) {
#			if (! $after_event) {
#				delete $times_by_hour->{$hour};
#			} else {
#				$hours_to_delete->{$hour} = 1;
#			}
#		} else {
#			$found_event = 1;
#			$after_event = 1;
#			$hours_to_delete = {};
#		}
#	}
#	foreach my $hour (keys %{%hours_to_delete}) {
#		delete $times_by_hour->{$hour};
#	}
#
#	#
#	# Put an 60 minutes 'down' event into every empty hour
#	for (my $hour = 0; $hour < 24; $hour++) {
#		if (exists $times_by_hour->{$hour} && keys %{$times_by_hour->{$hour}} == 0) {
#			for my $day ('mon','tue','wed','thu','fri','sat','sun') {
#				$times_by_hour->{$hour}->{$day} = [ [ 'down', 60, "" ] ];
#			}
#		}
#	}


	return $times_by_hour;
} # }}}


sub get_host_state ($;$) { # get_current_host_state (\%timetable ; $window_width) : 'boot'/'shutdown'
	my $times_from_db = shift;

	my $window_width = shift;

	if (! $times_from_db || ref ($times_from_db) ne 'HASH') {
		return undef;
	}

	my $times_list = get_times_list ($times_from_db);
	if (! $times_list || ref ($times_list) ne 'HASH') {
		return undef;
	}

	if (! $window_width || $window_width =~ m/[^0-9]/) {
		$window_width = 15;
	}

	# Localtime will return (sec, min, hour, ?, ?, ?, dow, ...)
	my @localtime = localtime (time);
	my $day = dow_to_day ($localtime[6]);
	if (! $day) {
		return undef;
	}

	my $now_minutes = $localtime[2] * 60 + $localtime[1];

	if ($now_minutes + $window_width < 24 * 60) {
		foreach my $entry_hash (@{$times_list->{$day}}) {
			my @boot_time = split (':', $entry_hash->{boot});
			my @shutdown_time = split (':', $entry_hash->{shutdown});

			my $boot_time_minutes = $boot_time[0] * 60 + $boot_time[1];
			my $shutdown_time_minutes = $shutdown_time[0] * 60 + $shutdown_time[1];

			# If the next (maybe first) found occurence of a 'boot' event
			# is (wrt $window_width) far enough in the future, the host
			# should be offline
			if ($now_minutes + $window_width < $boot_time_minutes) {
				return "shutdown";
			}

			# If the boot event is in the (wrt $windows_width) to close
			# future or in the past (as we reached this code) and the
			# shutdown event is in the future, ths host should be online.
			if ($now_minutes < $shutdown_time_minutes) {
				return "online";
			}
		}
	} else {
		# XXX FIXME XXX

		# Prevent trouble by just saying the host has to be online at
		# midnight, if there is no better solution implemented
		return "online";
	}

	# If there was none or none of the existing events triggered a
	# decision, the only choice is to shut down the PC as there is
	# no entry which would tell us to stay up.
	return "shutdown";
}


1;

# vim:foldmethod=marker
