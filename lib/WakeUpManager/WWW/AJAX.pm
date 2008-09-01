#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Fri 29 Aug 2008 02:14:50 AM CEST
#

package WakeUpManager::WWW::AJAX;

use strict;
use Carp qw(cluck confess);

use WakeUpManager::Config;
use WakeUpManager::DB::HostDB;

use HTML::Template;

my $TEMPLATE_BASEDIR = "/srv/wum/htdata/templates/";

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

	if (! defined $args->{ajax_page_name} || ! defined $args->{ajax_func_name}) {
		confess __PACKAGE__ . "->new(): ajax_page_name or ajax_func_name undefined!\n";
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

		ajax_page_name => $args->{ajax_page_name},
		ajax_func_name => $args->{ajax_func_name},
	}, $class;

	return $obj;
} #}}}


sub get_page () {
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_page(): Has to be called on bless'ed object.\n";
	}
	my $output = undef;

	#
	# Get content part and optinal headers from page logic module
	my $page_name = $self->{ajax_page_name};
	if ($self->_is_valid_page ($page_name) > 0) {
		my $page_logic = "WakeUpManager::WWW::Page::$page_name"->new (
			params => $self->{params},
			host_db_h => $self->{host_db_h},
		);

		if ($page_logic) {
			my $result = $page_logic->ajax_call ($self->{ajax_func_name});

			if (ref ($result) eq 'HASH') {
				$output = $result;
			} else {
				$output = "An error occured while running AJAX call...\n";
			}

		# (! $page_logic)
		} else {
			# Whoops. This should not have happend.
			$output = $self->_gen_error_content ("Could not load module for page \"$page_name\". Contact your system administrator.");
			print STDERR "Could not load module for page \"$page_name\"\n";
		}
	}

	else {
		$output = $self->_gen_error_content ("Page \"$page_name\" could not be loaded or does not exist...");
	}

	#
	# Push out HTML data
	return $self->_return_result_box ($output);
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

sub _return_result_box ($) { # _return_result_box (content) : HTML strings {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_gen_error_page(): Has to be called on bless'ed object.";
	}

	my $content = shift;
	if (! defined $content) {
		$content = $self->_gen_error_content ("Internal error!");
	}

	my $lang = $self->{params}->get_lang ();

	my $template = undef;
	if (-f "$TEMPLATE_BASEDIR/$lang/result_box.tmpl") {
		$template = HTML::Template->new (filename => "$TEMPLATE_BASEDIR/$lang/result_box.tmpl");
	} elsif (-f "$TEMPLATE_BASEDIR/en/result_box.tmpl") {
		$template = HTML::Template->new (filename => "$TEMPLATE_BASEDIR/en/result_box.tmpl");
	}

	# If there is a template, use it.
	if (defined $template) {
		if (ref ($content) eq 'HASH') {
			$template->param (result => 1);

			foreach my $key (keys  %{$content}) {
				$template->param ($key => $content->{$key});
			}
		} else {
			$template->param (
				result => 1,
				content => $content,
			);
		}
		return $template->output ();
	}

	# NO template available (why?!), push out the result as is.
	else {
		return $content;
	}

} # }}}

1;

# vim:foldmethod=marker
