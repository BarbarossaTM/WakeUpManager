#!/usr/bin/perl -WT

use strict;

use WakeUpManager::WWW;

my $www = WakeUpManager::WWW->new ();

if (! $www) {
	print "Internal error.\n";
	print "Please contact your system administrator.\n";

	die "Could not fire up WakeUpManager::WWW...";
}

print $www->get_page ();
