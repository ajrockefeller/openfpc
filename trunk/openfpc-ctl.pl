#!/usr/bin/perl
# The master control program for starting and stopping OpenFPC instances.
#########################################################################################
# Copyright (C) 2010 Leon Ward 
# openfpc - Part of the OpenFPC - (Full Packet Capture) project
#
# Contact: leon@rm-rf.co.uk
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#########################################################################################

use strict;
use warnings;
use Getopt::Long;
use Switch;
use Data::Dumper;

my $version=0.2;
my $conf_dir="/etc/openfpc";

my ($quiet,$usertype,$verbose,$help);
my $init=0;						# init script friendly output (i.e not much!)
my $type=0;
my $thing=0;
#my $instance=0;
my %configs=();						# Hash of all configs in $CONF_DIR;
my $action=0;
my @daemonsNode=("openfpc-daemonlogger", 		# Daemons we want to start in OpenFPC Node mode
		"openfpc-queued",
		"openfpc-cxtracker",
		"openfpc-cx2db" );

my @daemonsProxy=("openfpc-queued"); 			# Daemons we want to start in OpenFPC proxy mode

my %defaults=( PIDPATH => "/var/run",
		DAEMONLOGGER_CMD => "/usr/bin/daemonlogger",
		CXTRACKER_CMD => "/usr/bin/cxtracker" ,
		OPENFPC_QUEUED_CMD => "/usr/bin/openfpc-queued",
		SESSION_DIR => "/var/lib/openfpc/session",
		CX2DB_CMD => "/usr/bin/openfpc-cx2db",
		);
		


=head2 getType
	Unless a user has specified if we are taking action on a daemon, or a configuration, this function will try to autodetect.
	The only real risk of failing to detect is if someone stupidly names a configuration the same name as a daemon
	e.g. NODENAME="openfpc-daemonlogger"

	Expects string
	Returns a hash ...

	(	type => "config",
	  	instance => "instance" ,
		filename => "/etc/openfpc/config.filename",
	)
 
=cut
sub getType{
	
	#my $thing=shift; 			# What type of thing is $thing
	my %result=( 	type => 0 ,
			instance => 0,
			filename => 0, 
		);
	my @daemons=(	"openfpc-queued",
			"openfpc-daemonlogger",
			"openfpc-cxtracker",
			"openfpc-cx2db");
	
	# Check if thing is one of our known daemons
	foreach(@daemonsNode) {
		if ( $_ eq $thing ) {
			$result{'type'} = "daemon";
			$result{'filename'} = "/etc/init.d/" . $thing;	
			return(\%result);
		}
	}

	# Check if thing is one of our config files
	if ( exists $configs{$thing} ) {
		$result{'type'} = "instance";
		$result{'instance'} = "$thing";
		$result{'filename'} = $thing;
	}

	# Check if thing is a node-name in any of the config files.
	foreach (keys(%configs)) {
		my $filename=$_;
		if ( $thing eq $configs{$_}{'NODENAME'} ) {
			$result{'type'} = "instance";
			$result{'filename'} = "$filename";
			return(\%result);
		}
	}


	# We don't know what it is.
	return(\%result);	
}

=head2 getInstanceByDaemon
	Get a list of instances that this daemon needs to be started for.
	returns an array of instances (config filenames)
=cut

sub getInstanceByDaemon{
	my $daemon=shift;
	my @instances=();

	foreach my $conf (keys(%configs)) {
		if ( $configs{$conf}{'OFPC_ENABLED'} eq "y") {
			if ($configs{$conf}{'PROXY'} == 1) {
				# Enabled Proxy
				if ( grep $_ eq $daemon, @daemonsProxy ) {
					push(@instances, $conf);
				}
			} elsif ($configs{$conf}{'PROXY'} == 0 ) {
				if ( grep $_ eq $daemon, @daemonsNode ) {
					push(@instances, $conf);
				}
			}
		}
	}
	return(@instances);
}


=head2 getDaemonsByInstance
	Return a list of daemons we need to start for a config files
=cut

sub getDaemonsByInstance{
	my $instance=shift;
	my @daemons=();
	
	if ($configs{$instance}{'PROXY'} == 1 ) {
		return(@daemonsProxy);
	} elsif ($configs{$instance}{'PROXY'} == 0  ) {
		return(@daemonsNode);
	} else {
		die("Unknown Proxy config for instance: $instance\n");
	}
}

=head2 getPidFromFile
	Open a pidfile, and retuen the pid
=cut

sub getPidFromFile($){
	my $filename=shift;
	my $pid=0;

	if ( -f $filename) {
		open PIDFILE, '<', "$filename" or return(0);
		while(<PIDFILE>) {
			$pid=$_;	
			chomp $pid;
		}
	}
	return($pid); 
}

sub isPidRunning($){
	my $pid=shift;
	if ( system("ps $pid > /dev/null")) {
		return(0);
	} else {
		return(1);
	}
}

=head2 openfpcqueued
	Start/Stop the OpenFPC Queue Daemon
	- Leon 2010	
=cut

sub openfpcqueued{
	my $action=shift;
	my $instance=shift;
	my $pidpath=$defaults{'PIDPATH'};
	my $daemoncmd="openfpc-queued";	
	my $daemonargs="-c $conf_dir/$instance --daemon";
	#my $pidfile=$configs{$instance}{'OFPC_Q_PID'} . $configs{$instance}{'OFPC_PORT'};	# Adding the port number to prevent
												# multiple daemons trying to use the same pidfile

	$pidpath=$configs{$instance}{'PIDPATH'} if defined $configs{$instance}{'PIDPATH'};
	my $pidfile="/tmp/openfpc-queued-" . $configs{$instance}{'NODENAME'} . ".pid";

	$daemoncmd=$configs{$instance}{'OPENFPC_QUEUED_CMD'} if ($configs{$instance}{'OPENFPC_QUEUED_CMD'});
	# Get a PID, and check if it's runnings
	my $pid=getPidFromFile($pidfile);
	my $running=isPidRunning($pid) if ($pid);

	switch($action){
		case "start" {
			printf '%-60s', "Starting OpenFPC Queue Daemon ($configs{$instance}{'NODENAME'})... ";
			if ($running) {
				printf '%20s', "Running (pid $pid)\n";
			} else {
				if ( -x $daemoncmd ) {
					my $result=system("$daemoncmd $daemonargs");
					if ($result) {
						printf '%20s', "Failed\n";
						print "->Check syslog for details\n" unless ($quiet);
					} else {
						printf '%20s', "Done.\n";
						return(1);
					}
				}	
			}

		} 
		case "stop" {
			printf '%-60s', "Stopping OpenFPC Queue Daemon ($configs{$instance}{'NODENAME'})... ";
			if ($running) {
				my $result=system("kill $pid");
				if ($result) {
					printf '%20s', "Failed\n";
				} else {
					printf '%20s',"Done\n";
					return(1);
				}
			} else {
				print "Not running\n";
			}
		} 
		case "status" {
			if ($running) {
				print " -  OpenFPC Queued running (pid $pid)\n";
			} else {
				print " -  OpenFPC Queued stopped\n";
			}
		} 
	}
	return(0);
}


=head2 dameonlogger
	Start/Stop the OpenFPC Queue Daemon
	- Leon 2010	
=cut

sub openfpcdaemonlogger{
	my $action=shift;
	my $instance=shift;
	my $pidpath=$defaults{'PIDPATH'};
	$pidpath=$configs{$instance}{'PIDPATH'} if defined $configs{$instance}{'PIDPATH'};

	my $pidfile="openfpc-daemonlogger-" . $configs{$instance}{'NODENAME'} . ".pid";
	my $daemonargs=" -d ".
			"-i $configs{$instance}{'INTERFACE'} " .
			"-l $configs{$instance}{'BUFFER_PATH'} ".
			"-M $configs{$instance}{'PCAP_SPACE'} ".
			"-s $configs{$instance}{'FILE_SIZE'} ".
			"-p $pidfile " .
			"-P $pidpath " .
			"-n openfpc-$configs{$instance}{'NODENAME'}.pcap" .
			" >> /tmp/openfpc-dl-out 2>&1 ";

	# Daemonlogger is verbose at startup, and we need to store the op to find 
	# any problems if found. Throwing it to a file in /tmp works for now.

	# Check we have a sane config to start dl


	my $daemoncmd="/usr/bin/daemonlogger";
	$daemoncmd=$configs{$instance}{'DAEMONLOGGER_CMD'} if ($configs{$instance}{'DAEMONLOGGER_CMD'});

	# Get a PID, and check if it's runnings
	my $pid=getPidFromFile("$pidpath/$pidfile");
	my $running=isPidRunning($pid) if ($pid);

	switch($action){
		case "start" {
			#print "$daemoncmd $daemonargs\n";
			printf '%-60s',  "Starting Daemonlogger ($configs{$instance}{'NODENAME'})... ";
			if ($running) {
				print "Running (pid $pid)\n";
			} else {
				# Check if interface is available
				if (system("ifconfig $configs{$instance}{'INTERFACE'} up > /dev/null 2>&1")){
					printf '%20s', "Failed\n";
					print "->Cant bring $configs{$instance}{'INTERFACE'} up\n" unless ($quiet);
					return(0);
				}
				# Check if BUFFER_PATH exists and is writable
				if ( ! -d  $configs{$instance}{'BUFFER_PATH'}){
					printf '%20s',"Failed \n";	
					print "Log path $configs{$instance}{'BUFFER_PATH'} doesn't exist\n" unless ($quiet);
					return(0);
				}

				if ( -x $daemoncmd ) {
					my $result=system("$daemoncmd $daemonargs");
					if ($result) {
						printf '%20s', "Failed\n";
					} else {
						printf '%20s', "Done\n";
						return(1);
					}
				} else {
					printf '%20s', "Can't exec $daemoncmd\n";
					return(0);
				}	
			}

		} 
		case "stop" {
			printf '%-60s',  "Stopping Daemonlogger... ";
			if ($running) {
				my $result=system("kill $pid");
				if ($result) {
					printf '%20s', "Failed\n";
				} else {
					print "Done\n";
					return(1);
				}
			} else {
				print "Not running\n";
			}
		} 
		case "status" {
			if ($running) {
				print " -  Daemonlogger running (pid $pid)\n";
			} else {
				print " -  Daemonlogger stopped\n";
			}
		} 
	}
	return(0);
}


sub openfpccxtracker{
	my $action=shift;
	my $instance=shift;
	my $pidpath=$defaults{'PIDPATH'};
	my $daemoncmd=$defaults{'CXTRACKER_CMD'};
	my $sessiondir=$defaults{'SESSION_DIR'};
	my $pidfile="openfpc-cxtracker-$configs{$instance}{'NODENAME'}.pid";	

	$pidpath=$configs{$instance}{'PIDPATH'} if defined $configs{$instance}{'PIDPATH'};
	$daemoncmd=$configs{$instance}{'CXTRACKER_CMD'} if defined $configs{$instance}{'CXTRACKER_CMD'};
	$sessiondir=$configs{$instance}{'SESSION_DIR'} if defined $configs{$instance}{'SESSION_DIR'};

	my $daemonargs="-i $configs{$instance}{'INTERFACE'} " .
			"-d $sessiondir " .
			"-p $pidfile " . 
			"-P $pidpath " .
			"-D > /tmp/openfpc-cxtracker-$configs{$instance}{'NODENAME'}";

	# Get a PID, and check if it's runnings
	my $pid=getPidFromFile("$pidpath/$pidfile");
	my $running=isPidRunning($pid) if ($pid);

	switch($action){
		case "start" {
			printf '%-60s', "Starting OpenFPC cxtracker ($configs{$instance}{'NODENAME'})... ";
			if ($running) {
				print "Running (pid $pid)\n";
			} else {
				# Check if interface is available
				if (system("ifconfig $configs{$instance}{'INTERFACE'} up > /dev/null 2>&1")){
					printf '%20s', "Failed\n";
					print "->Cant bring $configs{$instance}{'INTERFACE'} up\n" unless ($quiet);
					return(0);
				}
				# Check if BUFFER_PATH exists and is writable
				if ( ! -d  $configs{$instance}{'SESSION_DIR'}){
					printf '%20s', "Failed\n";	
					print "->Log path $configs{$instance}{'SESSION_DIR'} doesn't exist\n" unless ($quiet);
					return(0);
				}
				if ( -x $daemoncmd ) {
					my $result=system("$daemoncmd $daemonargs");
					if ($result) {
						printf '%20s', "Failed\n";
					} else {
						printf '%20s', "Done\n";
						return(1);
					}
				} else {
					printf '%20s', "Failed\n";
					print " -> Unable to exec $daemoncmd \n";
				}	
			}

		} 
		case "stop" {
			printf '%-60s',  "Stopping OpenFPC cxtracker ($configs{$instance}{'NODENAME'})... ";
			if ($running) {
				my $result=system("kill $pid");
				if ($result) {
					printf '%20s', "Failed\n";
				} else {
					print "Done\n";
					return(1);
				}
			} else {
				print "Not running\n";
			}
		} 
		case "status" {
			if ($running) {
				print " -  OpenFPC cxtracker ($configs{$instance}{'NODENAME'}) running (pid $pid)\n";
			} else {
				print " -  OpenFPC cxtracker ($configs{$instance}{'NODENAME'}) stopped\n";
			}
		} 
	}
	return(0);
}

=head2 openfpccx2db
	Start/Stop cx2db (uploads sessions from disk to DB)
=cut

sub openfpccx2db{
	my $action=shift;
	my $instance=shift;
	my $pidpath=$defaults{'PIDPATH'};
	my $daemoncmd=$defaults{'CX2DB_CMD'};
	my $pidfile="openfpc-cx2db-$configs{$instance}{'NODENAME'}.pid";	

	$pidpath=$configs{$instance}{'PIDPATH'} if defined $configs{$instance}{'PIDPATH'};
	$daemoncmd=$configs{$instance}{'CX2DB_CMD'} if defined $configs{$instance}{'CX2DB_CMD'};

	my $daemonargs="--daemon --config $conf_dir/$instance " .
			"> /tmp/openfpc-cx2db-$configs{$instance}{'NODENAME'}.log";

	# Get a PID, and check if it's runnings
	my $pid=getPidFromFile("$pidpath/$pidfile");
	my $running=isPidRunning($pid) if ($pid);

	switch($action){
		case "start" {
			printf '%-60s', "Starting OpenFPC Connection Uploader ($configs{$instance}{'NODENAME'}) ... ";
			if ($running) {
				print "Running (pid $pid)\n";
			} else {
				# Check if BUFFER_PATH exists and is writable
				if ( ! -d  $configs{$instance}{'SESSION_DIR'}){
					printf '%20s', "Failed. \n";	
					print "->Log path $configs{$instance}{'SESSION_DIR'} doesn't exist\n" unless ($quiet);
					return(0);
				}
				if ( -x $daemoncmd ) {
					my $result=system("$daemoncmd $daemonargs");
					if ($result) {
						printf '%20s', "Failed\n";
					} else {
						print "Done\n";
						return(1);
					}
				} else {
					printf '%20s', "Failed\n";
					print " -> Unable to exec $daemoncmd \n";
				}	
			}

		} 
		case "stop" {
			printf '%-60s',  "Stopping OpenFPC Connection Uploader ($configs{$instance}{'NODENAME'})... ";
			if ($running) {
				my $result=system("kill $pid");
				if ($result) {
					printf '%20s', "Failed\n";
				} else {
					print "Done\n";
					return(1);
				}
			} else {
				print "Not running\n";
			}
		} 
		case "status" {
			if ($running) {
				print " -  OpenFPC Connection Uploader ($configs{$instance}{'NODENAME'}) running (pid $pid)\n";
			} else {
				print " -  OpenFPC Connection Uploader stopped\n";
			}
		} 
	}
	return(0);
}



sub showhelp{

	print "
	openfpc : An OpenFPC control tool.

This tool start/stops all OpenFPC components on a host.  It does all the 
hard work so you don't have to.  Multiple instances of OpenFPC can exist 
on a host, this tool caters for that need allowing a user to start/stop 
either an instance, or all copies of a specific daemon.

e.g
To start all daemons required to operate an OpenFPC node with the name 
\"DefaultNode\"

     openfpc --action start -t DefaultNode  

To start all daemons required to operate a node by specifying a config files
     openfpc --action start -t openfpc-default.conf

To start all the instances of the openfpc-queued daemon
     openfpc --action start -t openfpc-queued

To get the status of all daemons that are configured to run on this host
    openfpc --action status

See --usage for command line options.
###############################################################################
Usage:

openfpc --action --thing <thing to take action on> --quiet
	--action  or -a         start/stop/status
        --quiet   or -q         Quiet output for init scripts
        --thing   or -t         Take action on this \"thing\"

Note: --thing can be one of...
 - A Daemon name
   openfpc-daemonlogger
   openfpc-queued
   openfpc-cx2db
   openfpc-cxtracker
 - Config file e.g.
   openfpc-dafault.conf
 - Node name (defined in any config file in conf_dir)
   MyOpenFPCNode
   CORP.UK.DMZ.WWW

Part of the OpenFPC project http://www.openfpc.org
";
	exit 0;
}

GetOptions (    'a|action=s' => \$action,		# Action to take
		'v|verbose' => \$verbose,		# Verbose
		't|thing=s' => \$thing,			# The thing we want to take action on
		'q|quiet' => \$quiet,
		'help' => \$help,
);

&showhelp if ($help);

# Check if we are root
unless ($> == 0 || $< == 0) { die "You need root privs to run openfpc-ctl" }


# Read in a hash of all configs on the system

opendir(my $dh, $conf_dir) || die("Unable to open config dir $conf_dir\n");
while(my $file=readdir $dh) {
	open FILE, '<', "$conf_dir/$file" or die "Unable to open config file $conf_dir/$file $!";
	while(my $line=<FILE>) {
        	chomp $line;
	        if ( $line =~ m/^[a-zA-Z]/) {
	                (my $key, my @value) = split /=/, $line;
	                unless ($key eq "USER") {
	                        $configs{$file}{$key} = join '=', @value;
                	}    
        	}
	}
	close(FILE);

}
closedir($dh);
# Make sure we have the minimum input to do something of use.

die("[!] No action specified. See --usage for more options") unless ($action);

# Check if we need to act in the context of a daemon type, or an instance.
# Get the type of the thing the user wants to start/stop

if ($thing) {
	my $ofpc=getType($thing);
	print "Filename is $ofpc->{'filename'} \nType is $ofpc->{'type'} \n" if $verbose;

	if ( $ofpc->{'type'} eq "daemon" ) {
		my @instances=getInstanceByDaemon($thing);
		switch($thing) {
			case "openfpc-queued" {
				foreach (@instances){
					openfpcqueued($action,$_);
				}
			}
			case "openfpc-daemonlogger" {
				foreach (@instances){
					openfpcdaemonlogger($action,$_);
				}
			}
			case "openfpc-cxtracker" {
				foreach (@instances){
					openfpccxtracker($action,$_);
				}
			}
			case "openfpc-cx2db" {
				foreach (@instances){
					openfpccx2db($action,$_);
				}
			}
			else {
				print " !  Unknown daemon $_\n";
			}
		}
	} elsif ( $ofpc->{'type'} eq "instance" ) {
		my $instance = $ofpc->{'filename'}; 		
		my @daemons=getDaemonsByInstance($ofpc->{'filename'});
		foreach (@daemons) {
			switch($_) {
				case "openfpc-queued" {
					openfpcqueued($action,$instance);
				}
				case "openfpc-daemonlogger" {
					openfpcdaemonlogger($action,$instance);
				}
				case "openfpc-cxtracker" {
					openfpccxtracker($action,$instance);
				}
				case "openfpc-cx2db" {
					openfpccx2db($action,$instance);
				}
				else {
					print " !  Unknown daemon $_\n";
				}
			}
		}
	} else {
		die("Dont know what this is");
	}
} else {
	# Thing not speficied, taking action on 
	# all daemons for all instances.
	foreach my $instance (keys(%configs)) {
		print "[*] OpenFPC instance $instance\n";
		my @daemons=getDaemonsByInstance($instance);
		foreach (@daemons) {
			switch($_) {
				case "openfpc-queued" {
					openfpcqueued($action,$instance);
				}
				case "openfpc-daemonlogger" {
					openfpcdaemonlogger($action,$instance);
				}
				case "openfpc-cxtracker" {
					openfpccxtracker($action,$instance);
				}
				case "openfpc-cx2db" {
					openfpccx2db($action,$instance);
				}
				else {
					print " !  Unknown daemon $_\n";
				}
			}
		}
	}
}
