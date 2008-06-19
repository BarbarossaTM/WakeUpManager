#!/usr/bin/perl -WT
#
# WakeUpManager RPC Result
#
# An object of this class shall be used as the return value of every method
# callable via RPC within WakeUpManager.
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Wed, 14 Nov 2007 02:17:11 +0100
#

package WakeUpManager::RPC::Result;

use strict;
use Carp;

##
# Little bit of magic to simplify debugging
sub _options() { #{{{
	my %ret = @_;

	if ( $ret{debug} ) {
		foreach my $opt (keys %ret) {
			print STDERR __PACKAGE__ . "->_options: $opt => $ret{$opt}\n";
		}
	}

	return \%ret;
} #}}}

##
# Create new RPC Result object
sub new () { # new (retcode => <int>, retval => \%, errormsg => <string>)
	my $self = shift;
	my $class = ref ($self) || $self;

	# Make life easy
	my $args = &_options (@_);

	#
	# The return code of the called function.
	# == 0 =>  Everything is fine
	# <> 0 =>  Error codes
	my $retcode = 0;
	if (defined $args->{retcode}) {
		$retcode = $args->{retcode};
	}

	#
	# The return value of the called function
	#
	# If not specifed undef is used
	my $retval = undef;
	if (defined $args->{retval}) {
		$retval = $args->{retval};
	}

	#
	# An optional error messagge explainig what was wrong.
	# The value is ignored if retcode is == 0
	#
	# This messagee is intended to be shown to the user
	my $errormsg = undef;
	if ($retcode && defined $args->{errormsg}) {
		$errormsg = $args->{errormsg};
	}

	my $obj = bless {
		retcode => $retcode,
		retval => $retval,
		errormsg => $errormsg,
	}, $class;

	return $obj;
}

1;
