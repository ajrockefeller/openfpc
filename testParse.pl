#!/usr/bin/perl -I .

# leon@rm-rf.co.uk
# Quick script to test event parsing. Nothing to see here. Move on.


use strict;
use warnings;
use ofpcParse;
use Switch;

my $input="May  3 15:16:30 rancid snort: [1:13923:3] SMTP MailEnable SMTP HELO command denial of service attempt [Classification: Attempted Denial of     Service] [Priority: 2]: {TCP} 213.138.226.169:2690 -> 80.68.89.43:25"; # Snort syslog

#my $input="2010-04-05 10:23:12 1NyiWV-0002IK-QJ <= lodgersau3\@nattydreadtours.com H=(ABTS-AP-dynamic-117.149.169.122.airtelbroadband.in) [122.169.149.117] P=esmtp S=2056 id=000d01cad4a1\$ab5a3780\$6400a8c0\@lodgersau3"; # EXIM4
#my $input="	 2010-03-31 13:24:36	 high	 	 	 IPS Demo DE / sfukse3d00.lab.emea.sourcefire.com	 tcp	Go to Host View 192.168.4.248	Go to Host View 207.46.108.86	 Viktor Westcott (viktor.westcott, ldap)	 	 3044/tcp	 1863/tcp	 Standard Text Rule	 CHAT MSN message (1:540)	 Potential Corporate Policy Violation	 0";   # SF49IPS 

my %eventdata = ();

while (1) {
	%eventdata=ofpcParse::SF49IPS($input); if ($eventdata{'parsed'} ) { last; }
	%eventdata=ofpcParse::Exim4($input); if ($eventdata{'parsed'} ) { last; }
	%eventdata=ofpcParse::SnortSyslog($input); if ($eventdata{'parsed'} ) { last; }
	
	die("Unable to parse log. Doesn't match anything")
}

#%eventdata=ofpcParse::EXIM4($input);

if ($eventdata{'type'}) {
	print "\nGot event type $eventdata{'type'}\n";
	print "SIP = $eventdata{'sip'}  DIP = $eventdata{'dip'}\n" .
	"SPT = $eventdata{'spt'} DPT = $eventdata{'dpt'} \n" .
	"proto = $eventdata{'proto'} \n" .
	"msg = $eventdata{'msg'} timestamp = $eventdata{'timestamp'} \n" .
	"bpf = $eventdata{'bpf'} \nparsed = $eventdata{'parsed'} ";
}

print "\n\n";

