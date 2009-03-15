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
#  --  Wed 18 Jun 2008 04:10:55 PM CEST
#

package WakeUpManager::WWW::Page::UpdateTimetable;

use strict;
use Carp qw(cluck confess);

use WakeUpManager::Common::Utils qw(:time :timetable);
use WakeUpManager::WWW::Utils;

my $days = {
	de => [ 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So' ],
	en => [ 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun' ],
};

my $error_messages = { # {{{
	invalid_boot_time => {
		en => 'Invalid boot up time! Has to be HH:MM',
		de => 'Ung&uuml;tige Bootzeit! Format: HH:MM',
	},

	invalid_shutdown_time => {
		en => 'Invalid shutdown time! Has to be HH:MM',
		de => 'Ung&uuml;tige Herunterfahrzeit! Format: HH:MM',
	},

	invalid_day => {
		en => 'Invalid day value. Please choose from the list!',
		de => 'Ung&uuml;tiger Tag. Bitte aus der Liste ausw&auml;hlen!',
	},

	boot_after_shutdown => {
		en => 'Boot time is after shutdown time or time window is smaller than 30 minutes!',
		de => 'Startzeit liegt nach Herunterfahrzeit oder das Zeitfenster ist kleiner als 30 Minuten!',
	},

	overlapping_entries => {
		en => 'The time window of this entry overlaps with a former one!',
		de => 'Das Zeitfenster dieses Eintrags &uuml;berschneidet sich mit einem vorherigen!',
	}
}; # }}}

my $result_message = { # {{{
	saved => {
		en => 'Timetable has been saved.',
		de => 'Der Zeitplan wurde aktualisiert',
	},

	error => {
		en => 'An error occured. Data has <i>not</i> been saved.',
		de => 'Es ist ein Fehler aufgetreten, die Daten wurden <i>nicht</i> gespeichert',
	},

	unchanged => {
		en => 'Timetable did not change, not updating database.',
		de => 'Der Zeitplan wurde nicht ver&auml;ndert, Datenbank wird nicht aktualisiert.',
	},
}; # }}}

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

	# Pull DB handle but don't check it *here*
	my $host_db_h = $args->{host_db_h};

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		host_db_h => $host_db_h,

		params => $params,
	}, $class;

	return $obj;
} #}}}

sub get_header_elements () {
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_header_elements(): Has to be called on bless'ed object\n";
	}

	my $h2 = 'Update host timetable';
	my $lang = $self->{params}->get_lang ();
	if ($lang eq 'de') {
		$h2 = "Zeitplan &auml;ndern";
	}

	return {
		h2 => $h2,

		header_opt => "<script src=\"/ui/inc/UpdateTimetable.js\" type=\"text/javascript\"></script>",
	};
}

sub get_content_elements () {
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->run(): You may want to call me on an instantiated object.\n";
	}

	if (! $self->{host_db_h}) {
		return { PageERROR => "No connection to database." };
	}
	my $host_db = $self->{host_db_h};

	# Result hash
	my $content_elements = {};

	my $params = $self->{params};

	my $lang = $params->get_lang ();
	if (! defined $days->{$lang}) {
		# XXX This more or less is a programming error.
		#     How to handle this useful?!
		$lang = 'en';
	}

	my $user = $params->get_auth_info()->{user};
	my $submitted = $params->get_http_param ('submitted');

	# Get host_id parameter (if set)
	my $host_id = $params->get_http_param ('host_id');

	if (! defined $host_id) {
		my $allowed_hostgroups = $self->{host_db_h}->hostgroups_user_can_write_config ($user);
		my $allowed_hosts = $self->{host_db_h}->hosts_user_can_write_config ($user);

		# The really cool version of output formatting[tm]
		my $ALL_hostgroup_id = $self->{host_db_h}->get_hostgroup_id ('ALL');
		if ($ALL_hostgroup_id) {
			my $hostgroup_tree = $self->{host_db_h}->get_hostgroup_tree_below_group ($ALL_hostgroup_id);
			$content_elements->{hostgroup_loop} = WakeUpManager::WWW::Utils->gen_pretty_hostgroup_tree_select ($hostgroup_tree, $allowed_hostgroups);
		}

		if ($allowed_hosts) {
			$content_elements->{host_loop} = WakeUpManager::WWW::Utils->gen_pretty_host_select ($allowed_hosts);
		}

	} else {
		# Get hostname for error messages
		my $host_name = $host_db->get_host_name ($host_id) || "#$host_id";
		$content_elements->{hostname} = $host_name;

		# Check rights
		if (! $host_db->user_can_write_host_config ($user, $host_id)) {
			return { error => 1,
			         user_not_allowed_for_host => 1,
			         hostname => $host_name,
			};
		}


		#
		# Get times from database
		my $timetable_from_db = $host_db->get_times_of_host ($host_id);
		if (! $timetable_from_db) {
			return { error => 1,
			         cant_read_timetable => 1,
			         hostname => $host_name,
			};
		}
		my $times_list_from_db = sanitize_times_list (get_times_list ($timetable_from_db));
		if (! $times_list_from_db) {
			 return { error => 1,
			          cant_read_timetable => 1,
			         hostname => $host_name,
			};
		}

		# Called from somewhere else without FORM data?
		my $times_list;
		if (! $submitted) {
			$times_list = $times_list_from_db;

		}

		# User submitted data.
		else {
			$times_list = {};

			for (my $n = 1; 1; $n++) {
				my $day = $params->get_http_param ("day$n");
				if (! $day) {
					last;
				}

				if ($day eq '--') {
					next;
				}

				my $boot_time = $params->get_http_param ("boot$n");
				my $shutdown_time = $params->get_http_param ("shutdown$n");

				if (! $times_list->{$day}) {
					$times_list->{$day} = [];
				}

				push @{$times_list->{$day}}, { boot => $boot_time, 'shutdown' => $shutdown_time };
			}

			$times_list = sanitize_times_list (order_times_list ($times_list));
		}


		$content_elements->{hidden_form_data} = "\t  <input type=\"hidden\" name=\"host_id\" value=\"$host_id\">
	\t  <input type=\"hidden\" name=\"submitted\" value=\"1\">\n";

		my $table_data = $self->gen_table_from_timestable ($times_list);

		$content_elements->{timetable} = $table_data->{timetable};

		if ($submitted && $table_data->{error_count} == 0) {
			$content_elements->{result} = 1;

			my $equal_times_lists = equal_times_lists ($times_list_from_db, $times_list);
			if (! defined $equal_times_lists) {
				$content_elements->{content} = $result_message->{error}->{$lang};
				return $content_elements;
			}

			if ($equal_times_lists) {
				$content_elements->{content} = $result_message->{unchanged}->{$lang};
			} else {
				my $ret = $host_db->update_timetable_of_host ($host_id, $times_list);

				if ($ret == 1) {
					$content_elements->{content} = $result_message->{saved}->{$lang};
				} else {
					$content_elements->{content} = $result_message->{error}->{$lang};
				}
			}
		}
	}

	return $content_elements;
}

sub _by_boot_time {
	if (! ($a =~ m/^[0-2]?[0-9]:[0-5]?[0-9]/ && $b =~ m/^[0-2]?[0-9]:[0-5]?[0-9]/)) {
		return 1;
	}

	my @a_time = split (':', $a->{boot});
	my @b_time = split (':', $a->{boot});

	my $a_minutes = $a_time[0] * 60 + $a_time[1];
	my $b_minutes = $b_time[0] * 60 + $b_time[1];

	return { $a_minutes <=> $b_minutes };
}



sub gen_table_from_timestable ($) { # gen_table_from_timestable (times_list) : HTML_string {{{
	my $self = shift;

	my $times_list = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->gen_table_from_timestable(): Has to be called on bless'ed object.\n";
	}

	if (! $times_list || ref ($times_list) ne 'HASH') {
		return undef;
	}

	my $error_count = 0;

	my $lang = $self->{params}->get_lang ();

	# Generate HTML table
	my $table .= "\t  <table cellpadding=\"3\" cellspacing=\"2\" border=\"0\">\n";

	my $entry_num = 0;
	for (my $n = 1; $n <= 7; $n++) {
		my $day_name = dow_to_day ($n);
		my $day_hash = $times_list->{$day_name};

		if (! defined $day_hash || scalar @{$day_hash} == 0) {
			next;
		}

		my $last_shutdown_minutes = undef;

		foreach my $item_hash (sort _by_boot_time @{$day_hash}) {
			my @errors = ();

			# Increase entry number
			$entry_num++;

			#
			# Check boot time {{{
			my $valid_boot_time = 0;
			my $boot_time = $item_hash->{boot};
			if ($boot_time =~ m/^[0-2]?[0-9]:[0-5][0-9]:[0-2]?[0-9]$/) {
				# Strip seonds
				$boot_time =~ s/:[0-9]{2}$//;
			}
			if ($boot_time =~ m/^([0-2]?[0-9]):([0-5]?[0-9])$/) {
				if ($1 >= 0 && $1 < 24 && $2 >= 0 && $2 <= 59) {
					$valid_boot_time = 1;
				}
			}
			if (! $valid_boot_time) {
				push @errors, $self->get_error_msg ('invalid_boot_time');
			}
			# }}}

			#
			# Check shutdown time {{{
			my $valid_shutdown_time = 0;
			my $shutdown_time = $item_hash->{shutdown};
			if ($shutdown_time =~ m/^[0-2]?[0-9]:[0-5][0-9]:[0-5]?[0-9]$/) {
				# Strip seconds
				$shutdown_time =~ s/:[0-9]{2}$//;
			}
			if ($shutdown_time =~ m/^([0-2]?[0-9]):([0-5]?[0-9])$/) {
				if ($1 >= 0 && $1 <= 24 && $2 >= 0 && $2 <= 59) {
					$valid_shutdown_time = 1;
				}
			}
			if (! $valid_shutdown_time) {
				push @errors, $self->get_error_msg ('invalid_shutdown_time');
			}
			# }}}

			# If both times are valid, check for content level errors
			if ($valid_boot_time && $valid_shutdown_time) {
				# Check if boot time is smaller than shutdown time # {{{
				my @boot_times = split (':', $boot_time);
				my @shutdown_times = split (':', $shutdown_time);

				my $boot_minutes = $boot_times[0] * 60 + $boot_times[1];
				my $shutdown_minutes = $shutdown_times[0] * 60 + $shutdown_times[1];

				if ($shutdown_minutes - $boot_minutes < 30) {
					push @errors, $self->get_error_msg ('boot_after_shutdown');
				}
				# }}}

				# Check for overlapping entries {{{
				if (defined $last_shutdown_minutes && $last_shutdown_minutes >= $boot_minutes) {
					push @errors, $self->get_error_msg ('overlapping_entries');
				} else {
					$last_shutdown_minutes = $shutdown_minutes
				}
				# }}}
			}

			$table .= "\t   <tr>\n";
			$table .= "\t    <td>\n";

			# Build day select for this day.
			$table .= "\t     <select name=\"day$entry_num\">\n";
			   $table .= "\t      <option value=\"--\">--</option>\n";
			for (my $n_loop = 1; $n_loop <= 7; $n_loop++) {
				my $selected = ($n == $n_loop) ? 'selected' : '';
				$table .= "\t      <option value=\"" . dow_to_day ($n_loop). "\" $selected>$days->{$lang}[$n_loop-1]</option>\n";
			}
			$table .= "\t    </select>\n";

			$table .= "\t    </td>\n";
			$table .= "\t    <td>\n";
			$table .= "\t     <input type=\"text\" maxlength=\"5\" size=\"10\" name=\"boot$entry_num\" value=\"$boot_time\">\n";
			$table .= "\t    </td>\n";
			$table .= "\t    <td>\n";
			$table .= "\t     <input type=\"text\" maxlength=\"5\" size=\"10\" name=\"shutdown$entry_num\" value=\"$shutdown_time\">\n";
			$table .= "\t    </td>\n";

			if (scalar (@errors) > 0) {
				$error_count += scalar (@errors);

				$table .= "\t    <td class=\"error\">\n";
				foreach my $item (@errors) {
					$table .= "\t     $item <br>";
				}
				$table .= "\t    </td>\n";
			}

			$table .= "\t   </tr>\n";
		}
	}

	#
	# Print 3 extra rows with empty fields
	for (my $n = 1; $n <= 3; $n++) { # {{{
		$entry_num++;

		# Build day select for this day.
		my $day_select = "\t     <select name=\"day$entry_num\">\n";
		   $day_select .= "\t      <option value=\"--\">--</option>\n";
		for (my $n_loop = 1; $n_loop <= 7; $n_loop++) {
			$day_select .= "\t      <option value=\"" . dow_to_day ($n_loop). "\">$days->{$lang}[$n_loop-1]</option>\n";
		}
		$day_select .= "\t    </select>\n";

		$table .= "\t   <tr>\n";
		$table .= "\t    <td>\n";
		$table .= $day_select;
		$table .= "\t    </td>\n";
		$table .= "\t    <td>\n";
		$table .= "\t     <input type=\"text\" maxlength=\"5\" size=\"10\" name=\"boot$entry_num\" value=\"\">\n";
		$table .= "\t    </td>\n";
		$table .= "\t    <td>\n";
		$table .= "\t     <input type=\"text\" maxlength=\"5\" size=\"10\" name=\"shutdown$entry_num\" value=\"\">\n";
		$table .= "\t    </td>\n";
		$table .= "\t   </tr>\n";
	} # }}}

	$table .= "\t  </table>\n";

	return {
		error_count => $error_count,
		timetable => $table,
	};
} # }}}

sub get_error_msg ($) { # get_error_msg (error_name) {{{
	my $self = shift;

	my $error = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! $error);

	my $lang = $self->{params}->get_lang ();

	if (! defined $error_messages->{$error}) {
		return "Unknown error.";
	}

	if (defined $error_messages->{$error}->{$lang}) {
		return $error_messages->{$error}->{$lang};
	} elsif (defined $error_messages->{$error}->{en}) {
		return $error_messages->{$error}->{en};
	} else {
		return "Unknown error.";
	}
} # }}}

1;

# vim:foldmethod=marker
