#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Thu May 29 21:07:06 2008
#

package WakeUpManager::WWW::Page;

use strict;
use Carp qw(cluck confess);

use WakeUpManager::Config;
use WakeUpManager::DB::HostDB;

use HTML::Template;

#
# Default values
my $default_title = "Wake Up Manager";
my $default_h1 = "Wake Up Manager";

my $TEMPLATE_BASEDIR = "/srv/wum/htdata/templates/";

#
# Optional elements of the main page template which may be filled by a page module
my @header_element_names = qw(h2 header_opt);

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
		confess __PACKAGE__ . "->new(): No or invalid 'params' argument.\n";
	}

        # Read wum.conf
	my $wum_config = WakeUpManager::Config-> new (config_file => "/etc/wum/wum.conf");
	if (! $wum_config) {
		cluck __PACKAGE__ . "->new(): Could not get 'wum_config'...";
		return undef;
	}

	# Setup DB handle but don't check it here!
	my $host_db_h = WakeUpManager::DB::HostDB-> new (dbi_param => $wum_config->get_dbi_param ('HostDB'));

	#
	# Create page instance
	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		params => $args->{params},
		wum_config => $wum_config,
		host_db_h => $host_db_h,

		templates => {},
	}, $class;

	return $obj;
} #}}}


sub get_page () {
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_page(): Has to be called on bless'ed object.\n";
	}

	my $lang = $self->{params}->get_lang ();

	# Fireup main page template (which is language independant!)
	$self->{template}->{default} = HTML::Template->new (filename => "$TEMPLATE_BASEDIR/main.tmpl");

	# title / headline
	$self->{template}->{default}->param (title => $default_title);
	$self->{template}->{default}->param (h1 => $default_h1);

	# menu
	$self->{template}->{default}->param (menu => $self->_gen_menu ());

	#
	# Get content part and optinal headers from page logic module
	my $page_name = $self->{params}->get_page_name ();
	if ($self->_is_valid_page ($page_name) > 0) {
		my $page_logic = "WakeUpManager::WWW::Page::$page_name"->new (params => $self->{params});
		if ($page_logic) {
			# Maybe there are optional header elements
			my $page_header_elements =  $page_logic->get_header_elements ();
			foreach my $header_elem (@header_element_names) {
				if ($page_header_elements->{$header_elem}) {
					$self->{template}->{default}->param ($header_elem => $page_header_elements->{$header_elem});
				}
			}

			# File page template if there
			if (-f "$TEMPLATE_BASEDIR/$lang/$page_name.tmpl") {
				# Fire up template
				$self->{template}->{content} = HTML::Template->new (filename => "$TEMPLATE_BASEDIR/$lang/$page_name.tmpl");

				#
				# Ask page for content elements to be pushed into the page's template
				my $page_content_elements = $page_logic->get_content_elements ();
				if (! $page_content_elements || ref ($page_content_elements) ne 'HASH') {
					confess __PACKAGE__ . "->get_page(): Got invalid 'page_content_elements' from page \"$page_name\"\n";
				}

				# Check for errors in $page_logic
				if (! $page_content_elements->{PageERROR}) {
					foreach my $content_elem (keys %{$page_content_elements}) {
						$self->{template}->{content}->param ($content_elem => $page_content_elements->{$content_elem});
					}

					# Output finished page template as content part for the main page
					$self->{template}->{default}->param (content => $self->{template}->{content}->output ());

				} else {
					$self->{template}->{default}->param (content => $self->_gen_error_content ($page_content_elements->{PageERROR}));
					print STDERR "Error from page \"$page_name\": \"$page_content_elements->{PageERROR}\"";
				}
			# (! -f page_template)
			} else {

				# Whoops. This should not have happend.
				$self->{template}->{content} = $self->_gen_error_content ("No template found for page \"$page_name\" (lang \"$lang\"). Contact your system administrator.");
				print STDERR "No template found for page \"$page_name\" (lang $lang...";
			}
		# (! $page_logic)
		} else {
			# Whoops. This should not have happend.
			$self->{template}->{content} = $self->_gen_error_content ("Could not load module for page \"$page_name\". Contact your system administrator.");
			print STDERR "Could not load module for page \"$page_name\"\n";
		}
	}

	else {
		$self->{template}->{default}->param (content => $self->_gen_error_content ("Page \"$page_name\" could not be loaded or does not exist..."));
	}

	#
	# Push out HTML data
	return $self->{template}->{default}->output ();
}

################################################################################
#			Internal hepler functions			       #
################################################################################

#
# Check if the given page name is valid (if a fitting module exists.)
#
# Return codes:
#    1: Page found.
#
#  -23: Someone is tampering with us.
#   -1: Page not found
#   -2: Error in page. (File found but module doesn't load)
sub _is_valid_page ($) { # _is_valid_page (page_name) : int  {{{
	my $self = shift;

	my $page = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_is_valid_page() has to be called on bless'ed object.\n";
	}

	# If $page is the empty string or contains anything different than
	# [A-Za-z] characters, someone is tampering with us...
	if (! defined $page || length ($page) == 0 || ! ($page =~ m/^([A-Za-z]+)$/)) {
		print STDERR "Cheater detected, request for page \"$page\".";
		return -23;
	}

	# Untaint $page by using regexp with backreference
	#  => Perl Cookbook, Chapter 19.4 "Writing a Safe CGI Program"
	my $module = "WakeUpManager::WWW::Page::$1";

	# Idea stolen by OTRS (beware of ugly code!)
	if (eval "require $module") {
		# If simply require'ing the file works, everything's good.
		return 1;
	} else {
		# Hmm something's bad, let's see what's up
		my $mod_path = $module;
		$mod_path =~ s/::/\//g;

		foreach my $dir (@INC) {
			if (-f "$dir/$mod_path.pm") {
				# Hmm, module file exists, but seems to be errornous.
				print STDERR "Error: Module for page \"$page\" exists in \"$dir\", but could not be loaded. Check \"$module\" for errors!";
				return -1;
			}
		}

		# Module file does not exist withih @INC
		print STDERR "Warning: No Module for page \"$page\".";
		return -2;
	}
} # }}}


#
# Produce a page showing a hopefully useful message to the user
#
sub _gen_error_content ($;$) { # _gen_error_page (msg, helptext) : HTML string {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_gen_error_page(): Has to be called on bless'ed object.";
	}

	my $error_msg = shift;
	if (! defined $error_msg || length ($error_msg) == 0) {
		confess __PACKAGE__ . "->_gen_error_content(): You would better supply a error msg you coward.";
	}
	my $error_helptext = shift;

	my $lang = $self->{params}->get_lang ();

	my $template = undef;
	# Check for an error template for the requested language
	if ( -f "$TEMPLATE_BASEDIR/$lang/error.tmpl") {
		$template = HTML::Template->new (filename => "$TEMPLATE_BASEDIR/$lang/error.tmpl");
	}
	# If no localized error template is there, try to use the 'en' one instead.
	elsif (-f "$TEMPLATE_BASEDIR/en/error.tmpl") {
		$template = HTML::Template->new (filename => "$TEMPLATE_BASEDIR/en/error.tmpl");
	}

	# If there is a template, use it.
	if (defined $template) {
		$template->param (error_message_red => $error_msg);
		$template->param (error_helptext => $error_helptext);
		return $template->output ();
	}

	# OK no template available (why?!) put out the error by hand.
	else {
		my $HTML_string = "<p><b>An error occured: $error_msg</b></p>";

		if ($error_helptext) {
			$HTML_string .= "<p>Additional information: $error_helptext</p>";
		}

		return $HTML_string;
	}
} # }}}

sub _gen_menu () { # _gen_menu () : HTML_string for menu {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_gen_error_page(): Has to be called on bless'ed object.";
	}

	my $lang = $self->{params}->get_lang ();
	my $menu_HTML_string = "\t  <div class=\"three_em\">\n";

	my $user = $self->{params}->get_auth_info()->{user};

	my $user_can_boot_hosts = 1;
	my $user_can_read_host_config = 1;
	my $user_can_write_host_config = 1;
	eval {
		my $temp;

		$temp = $self->{host_db_h}->hosts_user_can_boot ($user);
		$user_can_boot_hosts = (keys %{$temp} != 0);

		$temp =  $self->{host_db_h}->hosts_user_can_read_config ($user);
		$user_can_read_host_config = (keys %{$temp} != 0);

		$temp =  $self->{host_db_h}->hosts_user_can_write_config ($user);
		$user_can_write_host_config = (keys %{$temp} != 0);

		if ($user_can_write_host_config) {
			$user_can_read_host_config = 1;
		}
	};

	if ($lang eq 'de') {
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=BootHost\">Rechner starten</a><br>\n" if ($user_can_boot_hosts);
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=ShowTimetable\">Zeitplan anzeigen</a><br>\n" if ($user_can_read_host_config);
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=UpdateTimetable\">Zeitplan &auml;ndern</a><br>\n" if ($user_can_write_host_config);
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=HostState\">Aktivierungsstatus</a><br>\n" if ($user_can_read_host_config);
		$menu_HTML_string .= "\t  <br>\n";
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=Preferences\">Einstellungen</a><br>\n";
		$menu_HTML_string .= "\t  <br>\n";
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=About\">&Uuml;ber Wake Up Manager</a><br>\n";
	} else {
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=BootHost\">Boot host</a><br>\n" if ($user_can_boot_hosts);;
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=ShowTimetable\">Show timetable</a><br>\n" if ($user_can_read_host_config);
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=UpdateTimetable\">Update timetable</a><br>\n" if ($user_can_write_host_config);
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=HostState\">Host activation state</a><br>\n" if ($user_can_read_host_config);
		$menu_HTML_string .= "\t  <br>\n";
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=Preferences\">Preferences</a><br>\n";
		$menu_HTML_string .= "\t  <br>\n";
		$menu_HTML_string .= "\t  &raquo; <a href=\"/ui/index.pl?page=About\">About Wake Up Manager</a><br>\n";
	}

	return $menu_HTML_string . "\t  </div>\n";
} # }}}

1;

# vim:foldmethod=marker
