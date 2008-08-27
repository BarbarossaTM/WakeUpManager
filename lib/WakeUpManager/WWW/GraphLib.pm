#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Mon 02 Jun 2008 06:46:21 AM CEST
#

package WakeUpManager::WWW::GraphLib;

use strict;
use Carp;

use IO::Pipe;
use Cairo;

my $days = {
	0 => { en => ' ', de => ' ',},
	1 => { en => 'mon', de => 'Mo', },
	2 => { en => 'tue', de => 'Di', },
	3 => { en => 'wed', de => 'Mi', },
	4 => { en => 'thu', de => 'Do', },
	5 => { en => 'fri', de => 'Fr', },
	6 => { en => 'sat', de => 'Sa', },
	7 => { en => 'sun', de => 'So', },
};


my $default_margin = 5;

# Horizontal layout
my $default_timeline_horiz = 10.0;
my $default_row_height = $default_timeline_horiz * 3.5;
my $default_left_width = 30;
my $default_hour_width = 30;

my $stretch_value = 1.5;
my $stretch_to = 6;
my $stretch_from = 20;

# Vertical layout
my $default_timeline_vert = 10.0;
my $default_col_width = 60;
my $default_top_vert_height = 35;
my $default_hour_height = 30;

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

	my $margin = (defined $args->{margin}) ? $args->{margin} : $default_margin;
	my $timeline_horiz = (defined $args->{timeline_horiz}) ? $args->{timeline_horiz} : $default_timeline_horiz;
	my $row_height = (defined $args->{row_height}) ? $args->{row_height} : $default_row_height;
	my $left_width = (defined $args->{left_width}) ? $args->{left_width} : $default_left_width;
	my $hour_width = (defined $args->{hour_width}) ? $args->{hour_width} : $default_hour_width;

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		margin => $margin,
		row_height => $row_height,
		timeline_horiz => $timeline_horiz,

		left_width => $left_width,
		hour_width => $hour_width
	}, $class;

	return $obj;
} #}}}


################################################################################
#			Stuff for horizontal timetable			       #
################################################################################

sub print_timetable_horizontal_png ($) { # {{{
	my $self = shift;

	my $timetable = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_timetable_png(): Has to be called on bless'ed object.\n";
	}

	if (! $timetable || ref ($timetable) ne 'HASH') {
		confess __PACKAGE__ . "->get_timetable_png(): No or invalid 'timetable' parameter.\n";
	}

	# Get variables for simpler access
	my $margin = $self->{margin};

	my $left_width = $self->{left_width};
	my $hour_width = $self->{hour_width};

	my $row_height = $self->{row_height};
	my $timeline_horiz = $self->{timeline_horiz};

	# Setup Cairo surface
	my $surface = Cairo::ImageSurface->create (
		'argb32',
		2 * $margin + $left_width + 24 * $hour_width - ($stretch_to + 1 + (24 - $stretch_from) * $hour_width / $stretch_value),
		2 * $margin + $row_height  * 8
	);
	if (! $surface) {
		return undef;
	}

	# Setup Cairo drawing context
	my $cr = Cairo::Context->create ($surface);
	if (! $cr) {
		return undef;
	}


	#
	# Show time
	# Create timelines # {{{
	$cr->set_source_rgb (0.39, 0.82, 0.04);
	$cr->set_line_width ($timeline_horiz);

	for (my $n = 1; $n <= 7; $n++) {
		my $day = $days->{$n}->{en};
		my $y = $margin + $row_height * $n + ($row_height - $timeline_horiz)/2 + $timeline_horiz/2;

		foreach my $list_item (@{$timetable->{$day}}) {
			my $x = $self->_get_x1_x2_from_boot_list_item ($list_item);

			$cr->move_to ($margin + $left_width + $x->[0], $y);
			$cr->line_to ($margin + $left_width + $x->[1], $y);
		}
	}

	# Reset everything
	$cr->stroke ();
	# }}}

	# Time table border # {{{
	# Hour headings
	my $x_cur = $margin + $left_width;
	for (my $hour = 0; $hour < 24; $hour++) {
		my $cur_width = ($hour <= $stretch_to || $hour >= $stretch_from) ? $hour_width/$stretch_value : $hour_width;
		my $x = $x_cur;

		$cr->set_line_width (1);
		$cr->set_source_rgb (0, 0, 0.5);
		$cr->move_to ($x, $margin);
		$cr->line_to ($x, $margin + $row_height);

		$cr->move_to ($x + $cur_width/2, $margin + $row_height);
		$cr->line_to ($x + $cur_width/2, $margin + $row_height - 5);
		$cr->stroke ();

		my $text_extents = $cr->text_extents ($hour);
		my $text_x = $x + $cur_width/2 - ($text_extents->{width} / 2  + $text_extents->{x_bearing});
		my $text_y = $margin + ($row_height) / 2 - ($text_extents->{height} / 2 + $text_extents->{y_bearing});

		$cr->move_to ($text_x, $text_y);
		$cr->set_source_rgb (0, 0, 0);
		$cr->set_font_size (14);
		$cr->show_text ($hour);
		$cr->stroke ();

		if ($hour != 23) {
			$x_cur += $cur_width;
		}
	}

	# Reset everything
	$cr->stroke ();

	$cr->set_line_width (2);
	$cr->set_source_rgb (0, 0, 0.5);
	$cr->rectangle ($margin + $left_width,
	                $margin,
	                $x_cur - $hour_width/$stretch_value + 4,
	                $row_height * 8);
	$cr->stroke ();

	# }}}

	# Day name column # {{{
	$cr->set_line_width (2);
	$cr->set_source_rgb (0, 0, 0.5);
	$cr->rectangle ($margin, $margin, $left_width, $row_height * 8);

	$cr->move_to ($margin, $margin + $row_height);
	$cr->line_to ($x_cur + $hour_width/$stretch_value, $margin + $row_height);
	$cr->stroke ();

	for (my $n = 0; $n <= 7; $n++) {
		my $y = $margin + ($row_height * ($n + 1));

		#
		# Lines
		if ($n != 0) {
			$cr->set_source_rgb (0, 0, 0.5);
			$cr->set_line_width (1);
			$cr->move_to ($margin, $y);
			$cr->line_to ($x_cur + $hour_width/$stretch_value, $y);
			$cr->stroke ();
		}

		#
		# Texts
		$cr->set_source_rgb (0, 0, 0);
		$cr->set_font_size (16);

		# Calculate value for printing text centered
		my $text_extents = $cr->text_extents ($days->{$n}->{de});
		my $text_x = ($margin + $left_width/2) - ($text_extents->{width} / 2  + $text_extents->{x_bearing});
		my $text_y = $y + ($text_extents->{height} / 2 + $text_extents->{y_bearing}) - 2;

		$cr->move_to ($text_x , $text_y);
		$cr->show_text ($days->{$n}->{de});
		$cr->stroke ();
	}

	# Reset everything
	$cr->stroke ();
	# }}}


	my $img_data;
	$surface->write_to_png_stream (sub {
		my ($closure, $data) = @_;
		print "$data";
	});
} # }}}

sub _get_x1_x2_from_boot_list_item ($) { # _get_x1_x2_from_boot_list_item (\%boot_list_item) : [ x1, x2 ] # {{{
	my $self = shift;

	my $boot_list_item = shift;

	if (! $self || ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_get_x1_x2_from_boot_list_item(): Has to be called on bless'ed object.\n";
	}

	if (! $boot_list_item || ref ($boot_list_item) ne 'HASH') {
		confess __PACKAGE__ . "->_get_x1_x2_from_boot_list_item(): No or invalid 'boot_list_item' parameter.\n";
	}

	my $hour_width = $self->{hour_width};

	my @boot_time = split (':', $boot_list_item->{boot});
	my @shutdown_time = split (':', $boot_list_item->{shutdown});

	my $x1;
	my $x2;

	# Stretch boot time
	if (($boot_time[0] * 60 + $boot_time[1]) <= (($stretch_to + 1) * 60)) {
		$x1 = ($boot_time[0] * 60 + $boot_time[1]) * $hour_width / 60 / $stretch_value;
	} elsif (($boot_time[0] * 60 + $boot_time[1]) < $stretch_from * 60) {
		$x1 = ($stretch_to + 1) * 60 * $hour_width / 60 / $stretch_value +
		      (($boot_time[0] * 60 + $boot_time[1]) - (($stretch_to + 1) * 60)) * $hour_width / 60;
	} else {
		$x1 = ($stretch_to + 1) * 60 * $hour_width / 60 / $stretch_value +
		      ($stretch_from - $stretch_to - 1) * 60 * $hour_width / 60 +
		      (($boot_time[0] * 60 + $boot_time[1]) - (($stretch_from) * 60)) * $hour_width / 60 / $stretch_value;
	}

	# Shutdown time
	if (($shutdown_time[0] * 60 + $shutdown_time[1]) <= (($stretch_to + 1) * 60)) {
		$x2 = ($shutdown_time[0] * 60 + $shutdown_time[1]) * $hour_width / 60 / $stretch_value;
	} elsif (($shutdown_time[0] * 60 + $shutdown_time[1]) < $stretch_from * 60) {
		$x2 = ($stretch_to + 1) * 60 * $hour_width / 60 / $stretch_value +
		      (($shutdown_time[0] * 60 + $shutdown_time[1]) - (($stretch_to + 1) * 60)) * $hour_width / 60;
	} else {
		$x2 = ($stretch_to + 1) * 60 * $hour_width / 60 / $stretch_value +
		      ($stretch_from - $stretch_to - 1) * 60 * $hour_width / 60 +
		      (($shutdown_time[0] * 60 + $shutdown_time[1]) - (($stretch_from) * 60)) * $hour_width / 60 / $stretch_value;
	}

	return [ $x1, $x2 ];
} # }}}

sub get_timetable_horizontal_map ($$$) { # get_timetable_horizontal_map (\%times_list, host_id, place_link) : "<map> ... </map>" # {{{
	my $self = shift;

	my $times_list = shift;
	my $host_id = shift;
	my $place_link = shift;

	if (! $self || ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_timetable_horizontal_map(): Has to be called on bless'ed object.\n";
	}

	if (! $times_list || ref ($times_list) ne 'HASH') {
		confess __PACKAGE__ . "->get_timetable_horizontal_map(): No or invalid times_list parameter given.\n";
	}

	if (! defined $host_id || ref ($host_id)) {
		confess __PACKAGE__ . "->get_timetable_vertical_map(): No or invalid host_id parameter given.\n";
	}

	my $margin = $self->{margin};
	my $row_height = $self->{row_height};
	my $timeline_horiz = $self->{timeline_horiz};
	my $left_width = $self->{left_width};

	my $href = ($place_link) ? "href=\"/ui/index.pl?page=UpdateTimetable&host_id=$host_id\"" : "";
	my $image_map = "<map name=\"timetable\">\n";

	for (my $n = 1; $n <= 7; $n++) {
		my $day = $days->{$n}->{en};
		my $y = $margin + $row_height * $n + ($row_height - $timeline_horiz)/2 + $timeline_horiz/2;

		foreach my $list_item (@{$times_list->{$day}}) {
			my @boot_time = split (':', $list_item->{boot});
			my @shutdown_time = split (':', $list_item->{shutdown});

			my $x = $self->_get_x1_x2_from_boot_list_item ($list_item);

			my $x1 = $margin + $left_width + $x->[0];
			my $y1 = $y - 5;

			my $x2 = $margin + $left_width + $x->[1];
			my $y2 = $y + 5;

			my $title = "$boot_time[0]:$boot_time[1] - $shutdown_time[0]:$shutdown_time[1]";

			$image_map .= " <area $href shape=\"rect\" coords=\"$x1,$y1,$x2,$y2\" title=\"$title\" alt=\"$title\">\n";
		}
	}

	return $image_map . "</map>\n";
} # }}}


################################################################################
#			Stuff for vertical timetable			       #
################################################################################

sub print_timetable_vertical_png ($) { # print_timetable_vertical_png (\%times_list) : {{{
	my $self = shift;

	my $timetable = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_timetable_png(): Has to be called on bless'ed object.\n";
	}

	if (! $timetable || ref ($timetable) ne 'HASH') {
		confess __PACKAGE__ . "->get_timetable_png(): No or invalid 'timetable' parameter.\n";
	}

	# Get variables for simpler access
	my $margin = $default_margin;

	my $timeline_vert = $default_timeline_vert;
	my $col_width = $default_col_width;
	my $top_vert_height = $default_top_vert_height;
	my $hour_height = $default_hour_height;


	# Setup Cairo surface
	my $surface = Cairo::ImageSurface->create (
		'argb32',
		2 * $margin + $col_width  * 8,
		2 * $margin + $top_vert_height + 24 * $hour_height
	);
	if (! $surface) {
		return undef;
	}

	# Setup Cairo drawing context
	my $cr = Cairo::Context->create ($surface);
	if (! $cr) {
		return undef;
	}


	#
	# Show time

	# Day name column # {{{
	$cr->set_line_width (2);
	$cr->set_source_rgb (0, 0, 0.5);
	$cr->rectangle ($margin, $margin, $col_width * 8, $top_vert_height);

	$cr->move_to ($margin + $col_width, $margin);
	$cr->line_to ($margin + $col_width, $margin + $top_vert_height + 24 * $hour_height);
	$cr->stroke ();

	for (my $n = 0; $n <= 7; $n++) {
		my $x = $margin + ($col_width * ($n + 1));

		#
		# Lines
		if ($n != 0) {
			$cr->set_source_rgb (0, 0, 0.5);
			$cr->set_line_width (1);
			$cr->move_to ($x, $margin);
			$cr->line_to ($x, $margin + $top_vert_height + 24 * $hour_height);
			$cr->stroke ();
		}

		#
		# Texts
		$cr->set_source_rgb (0, 0, 0);
		$cr->set_font_size (20);

		# Calculate value for printing text centered
		my $text_extents = $cr->text_extents ($days->{$n}->{de});
		my $text_x = $x - $col_width + ($text_extents->{width} / 2  + $text_extents->{x_bearing});
		my $text_y = $margin + $top_vert_height + ($text_extents->{height} / 2 + $text_extents->{y_bearing});

		$cr->move_to ($text_x , $text_y);
		$cr->show_text ($days->{$n}->{de});
		$cr->stroke ();
	}

	# Reset everything
	$cr->stroke ();
	# }}}

	# Time table border # {{{
	$cr->set_line_width (2);
	$cr->set_source_rgb (0, 0, 0.5);
	$cr->rectangle ($margin,
	                $margin + $top_vert_height,
	                $col_width * 8,
	                $hour_height * 24);
	$cr->stroke ();

	# Hour headings
	for (my $hour = 0; $hour < 24; $hour++) {
		my $y = $margin + $top_vert_height + $hour_height * $hour;

		$cr->set_line_width (1);
		$cr->set_source_rgb (0, 0, 0.2);
		$cr->move_to ($margin, $y);
		$cr->line_to ($margin + $col_width * 8, $y);

		$cr->move_to ($margin + $col_width,    $y + $hour_height/2);
		$cr->line_to ($margin + $col_width -5, $y + $hour_height/2);
		$cr->stroke ();

		my $text_extents = $cr->text_extents ($hour);
		my $text_x = $margin + ($col_width) / 2 + ($text_extents->{height} / 2 + $text_extents->{y_bearing});
		my $text_y = $y + $hour_height/2 + ($text_extents->{width} / 2  + $text_extents->{x_bearing});

		$cr->move_to ($text_x, $text_y);
		$cr->set_source_rgb (0, 0, 0);
		$cr->set_font_size (14);
		$cr->show_text ($hour);
		$cr->stroke ();
	}

	# Reset everything
	$cr->stroke ();
	# }}}

	# Create timelines # {{{
	$cr->set_source_rgb (0.39, 0.82, 0.04);
	$cr->set_line_width ($timeline_vert);

	for (my $n = 1; $n <= 7; $n++) {
		my $day = $days->{$n}->{en};
		my $x = $margin + $col_width * $n + ($col_width - $timeline_vert)/2 + $timeline_vert/2;

		foreach my $list_item (@{$timetable->{$day}}) {
			my @boot_time = split (':', $list_item->{boot});
			my @shutdown_time = split (':', $list_item->{shutdown});

			$cr->move_to ($x, $margin + $top_vert_height + ($boot_time[0] * 60 + $boot_time[1]) * $hour_height / 60);
			$cr->line_to ($x, $margin + $top_vert_height + ($shutdown_time[0] * 60 + $shutdown_time[1]) * $hour_height / 60);
		}
	}

	# Reset everything
	$cr->stroke ();
	# }}}

	my $img_data;
	$surface->write_to_png_stream (sub {
		my ($closure, $data) = @_;
		print "$data";
	});
} # }}}

sub get_timetable_vertical_map ($$$) { # print_timetable_vertical_map (\%times_list, $host_id, place_link) : "<map> ... </map>" {{{
	my $self = shift;

	my $times_list = shift;
	my $host_id = shift;
	my $place_link = shift;

	if (! $self || ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_timetable_vertical_map(): Has to be called on bless'ed object.\n";
	}

	if (! $times_list || ref ($times_list) ne 'HASH') {
		confess __PACKAGE__ . "->get_timetable_vertical_map(): No or invalid times_list parameter given.\n";
	}

	if (! defined $host_id || ref ($host_id)) {
		confess __PACKAGE__ . "->get_timetable_vertical_map(): No or invalid host_id parameter given.\n";
	}

	# Get variables for simpler access
	my $margin = $default_margin;

	my $timeline_vert = $default_timeline_vert;
	my $col_width = $default_col_width;
	my $top_vert_height = $default_top_vert_height;
	my $hour_height = $default_hour_height;

	my $href = ($place_link) ? "href=\"/ui/index.pl?page=UpdateTimetable&host_id=$host_id\"" : "";
	my $image_map = "<map name=\"timetable\">\n";

	for (my $n = 1; $n <= 7; $n++) {
		my $day = $days->{$n}->{en};
		my $x = $margin + $col_width * $n + ($col_width - $timeline_vert)/2 + $timeline_vert/2;

		foreach my $list_item (@{$times_list->{$day}}) {
			my @boot_time = split (':', $list_item->{boot});
			my @shutdown_time = split (':', $list_item->{shutdown});

			my $x1 = $x - 5;
			my $y1 = $margin + $top_vert_height + ($boot_time[0] * 60 + $boot_time[1]) * $hour_height / 60;

			my $x2 = $x + 5;
			my $y2 = $margin + $top_vert_height + ($shutdown_time[0] * 60 + $shutdown_time[1]) * $hour_height / 60;

			my $title = "$boot_time[0]:$boot_time[1] - $shutdown_time[0]:$shutdown_time[1]";

			$image_map .= " <area $href  shape=\"rect\" coords=\"$x1,$y1,$x2,$y2\" title=\"$title\" alt=\"$title\">\n";
		}
	}

	return $image_map . "</map>\n";
} # }}}

1;

# vim:foldmethod=marker
