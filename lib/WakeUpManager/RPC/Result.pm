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
