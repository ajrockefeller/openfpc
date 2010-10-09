#!/bin/bash 

#########################################################################################
# Copyright (C) 2009 Leon Ward 
# install-openfpc.sh - Part of the OpenFPC - (Full Packet Capture) project
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


# This installer is for users that cannot or will not use the .debs for installation. This may be because: 
# It's goal is to take a system from being OpenFPC-less to one that has OpenFPC operating in a semi-standard setup.

openfpcver="0.2"
TARGET_DIR="/usr/local/bin"
CONF_DIR="/etc/openfpc"
INSTALL_FILES="openfpc-cx2db openfpc-client openfpc-ctl openfpc.conf openfpc-queued openfpc-setup.pl openfpc-dbmaint.sh"
PROG_FILES="openfpc-client openfpc-queued openfpc-setup.pl openfpc-cx2db"
WWW_FILES="index.php bluegrade.png"
WWW_DIR="$TARGET_DIR/www"
PERL_MODULES="Parse.pm Request.pm"
INIT_SCRIPTS="openfpc-daemonlogger openfpc-cx2db openfpc-cxtracker openfpc openfpc-queued"
INIT_DIR="/etc/init.d/" 
REQUIRED_BINS="tcpdump date mergecap perl tshark"
LOCAL_CONFIG="/etc/openfpc/openfpc.conf"
PERL_LIB_DIR="/usr/local/lib/site_perl"
OFPC_LIB_DIR="$PERL_LIB_DIR/OpenFPC"
BIN_DIR="/usr/local/bin"

DEPSOK=0			# Track if obvious deps are met
DISTRO="AUTO"		# Try to work out what distro we are installing on
# DISTRO="RH"		# force to RedHat
# DISTRO="Debian" 	# Force to Debian / Ubuntu

IAM=$(whoami)
DATE=$(date)
PATH=$PATH:/usr/sbin

function die()
{
        echo "$1"
        exit 1
}

function chkroot()
{
	if [ "$IAM" != "root" ]
	then
	       	die "[!] ERROR: Must be root to run this script"
	fi
}

function checkdeps()
{
	if [ "$DISTRO" == "DEBIAN" ] 
	then
		DEPS="apache2 daemonlogger tcpdump tshark libarchive-zip-perl libfilesys-df-perl libapache2-mod-php5 mysql-server php5-mysql libdatetime-perl" 
	elif [ "$DISTRO" == "REDHAT" ] 
	then
		DEPS=""
	else
		echo -e "Package checking only supported on Debian/Redhat OSs"
		echo "Use --force to skip checks, and fix problems by hand"
	fi

	# Check if some obvious dependencies are met	
	for dep in $DEPS
	do
		echo -e "[-] Checking for $dep ..."
		if  dpkg --status $dep > /dev/null 2>&1
		then
			echo -e "    $dep Okay"
		else
			DEPSOK=1
			echo -e "[!] ERROR: Package $dep is not installed."
		fi
	done	


	if [ "$DEPSOK" != 0 ]
	then
		echo -e "--------------------------------"
		echo -e "Problem with above dependencies, please install them before continuing"
		if [ "$DISTRO" == "DEBIAN" ] 
		then
			echo -e "As you're running a distro based on Debian..."
			echo -e "Hint: sudo apt-get install $DEPS\n"
		else 
			echo -e "As you're running a distro based on RedHat..."
			echo -e "Hint: yum install $DEPS\n"
		fi

		exit 1
	fi

	# Extra warning for cxtracker as it's not included in either of the distros we work with
	# 
	if which cxtracker
	then
		echo "* Found cxtracker in your \$PATH (good)"
	else
		echo -e "
###########################################################
# WARNING: No cxtracker found in path!
###########################################################
# Don't Panic! 
# This may be Okay if you expect it not to be found.
# cxtracker likely isn't included as part of your distro's
# package manager. Go grab it from www.openfpc.org/downloads
# Without cxtracker OpenFPC will function, but you loose 
# the ability to search flow/connection data in the web UI.
# All PCAP capture and extraction capabilities will still function.
# -Leon
###########################################################
"
	fi 
}

function doinstall()
{

	chkroot
	# Check for, and create if required a /etc/openfpc dir
        if [ -d $CONF_DIR ] 
	then
		echo -e " -  Found existing config dir $CONF_DIR "
	else
		mkdir $CONF_DIR || die "[!] Unable to mkdir $CONF_DIR"
	fi

	# Check the perl_lib_dir is in the perl path
	if  perl -V | grep "$PERL_LIB_DIR" > /dev/null
	then
		echo " -  Installing modules to $PERL_LIB_DIR"
	else
		die "[!] Perl include path problem. Cant find $PERL_LIB_DIR in Perl's @INC (perl -V to check)"
	fi	

	# Check four our inclide dir	
        if [ -d $OFPC_LIB_DIR ] 
	then
		echo -e " -  $OFPC_LIB_DIR exists"
	else
		mkdir --parent $OFPC_LIB_DIR || die "[!] Unable to mkdir $OFPC_LIB_DIR"
	fi

	[ -d $INIT_DIR ] || die "[!] Cannot find init.d directory $INIT_DIR. Something bad must have happened."

        for file in $INSTALL_FILES
        do
		echo -e " -  Installing $file"
                cp $file $TARGET_DIR || echo -e " -  Unable to copy $file to $TARGET_DIR"
        done

	######## Modules ###########

	if [ -d $OFPC_LIB_DIR ] 
	then
		echo -e " *  Found $OFPC_LIB_DIR"
	else
		mkdir --parent $OFPC_LIB_DIR || die "[!] Unable to mkdir $OFPC_LIB_DIR"
	fi

	for file in $PERL_MODULES
	do
		echo -e " -  Installing PERL module $file"
		cp OpenFPC/$file $OFPC_LIB_DIR/$file
	done

	###### Programs ######

	for file in $PROG_FILES
	do
		echo -e " -  Installing application $file"
		cp $file $BIN_DIR
	
	done

	###### WWW files #####

	if [ -d $WWW_DIR ] 
	then
		echo -e " *  Found $WWW_DIR"
	else
		mkdir --parent $WWW_DIR || die "[!] Unable to mkdir $WWW_DIR"
	fi

	for file in $WWW_FILES
	do
		echo -e " -  Installing $file"
		cp www/$file $WWW_DIR/$file
	done

	echo -e "[*] -------- Enabling and restarting Apache2 --------"	
	# Add openfpc config in apache
	cp etc/openfpc.apache2.conf /etc/apache2/sites-available/openfpc
	a2ensite openfpc
	service apache2 reload
	echo -e "-----------------------------------------------------"

	###### init #######

        for file in $INIT_SCRIPTS
        do
		echo -e " -  Installing $INIT_DIR/$file"
                ln -s $TARGET_DIR/$file /$INIT_DIR/$file  || echo -e " !  Unable to symlink $file into $INIT_DIR/$file"
        done

	if [ "$DISTRO" == "DEBIAN" ]
	then
		echo "[*] Performing a Debain Install"

		for file in $INIT_SCRIPTS
		do
			echo -e "[*] Updating rc.d with $file"
		 	update-rc.d $file defaults
		done
	elif [ "$DISTRO" == "REDHAT" ]
	then
		echo "[*] Performing a RedHat Install"
		echo NOT DONE!!!!!
		exit 1
	fi

	echo -e "
**************************************************************************
[*] Installation Complete 

    OpenFPC should now be installed and ready for configuration.
    To configure OpenFPC execute...

    $ sudo $TARGET_DIR/openfpc-setup.pl -c $CONF_DIR/openfpc.conf 

    For more information, and advanced setup options take a look at $TARGET_DIR/setup-openfpc.pl --help
    You may also want to check the status of OpenFPC's dependancies 
     
"
}


function remove()
{
	echo -e "* Stopping Services..."
	chkroot
	for file in $INIT_SCRIPTS
	do
		if [ -f $INIT_DIR/$file ] 
		then 
			echo -e "Stopping $file"
			$INIT_DIR/$file stop || echo -e " -  $file didn't stop, removing anyway"
		else
			echo -e " -  $INIT_DIR/$file doesn't exist - Won't try to stop"
		fi
	done

	echo -e "[*] Disabling OpenFPC GUI"
	a2dissite openfpc
	service apache2 reload
	[ -f /etc/apache2/sites-available/openfpc ] && rm /etc/apache2/sites-available/openfpc 


	echo -e "[*] Removing openfpc-progs ..."

	for file in $PROG_FILES
	do
		if [ -f $BIN_DIR/$file ] 
		then
			echo -e "    Removed   $BIN_DIR/$file"
			rm $BIN_DIR/$file || echo -e "unable to delete $BIN_DIR/$file"
		else
			echo -e "    Not Found $BIN_DIR/$file"	
		fi
	done
	
	echo -e "[*] Removing files..."

	for file in $INSTALL_FILES
	do
		if [ -f $TARGET_DIR/$file ] 
		then
			echo -e "    Removed   $TARGET_DIR/$file"
			rm $TARGET_DIR/$file || echo -e "unable to delete $file"
		else
			echo -e "    Not Found $TARGET_DIR/$file"	
		fi
	done

	echo -e "[*] Removing PERL modules"
	for file in $PERL_MODULES
	do
		if [ -f $OFPC_LIB_DIR/$file ]
		then	
			rm $OFPC_LIB_DIR/$file  || echo -e "[!] Unable to delete $file"
		else
			echo -e "    $OFPC_LIB_DIR/$file Not found"
		fi
	done

	echo -e "[*] Removing WWW files"
	for file in $WWW_FILES
	do
		if [ -f $WWW_DIR/$file ]
		then	
			rm $WWW_DIR/$file  || echo -e "[!] Unable to delete $WWW_DIR/$file"
		else
			echo -e "    $WWW_DIR/$file Not found"
		fi
	done

	# Remove the password file if it has been created
	[ -f $TARGET_DIR/apache2.passwd ] && rm $TARGET_DIR/apache2.passwd

	echo -e "[*] Removing openfpc wwwroot"
	if [ -d $WWW_DIR ] 
	then
		rm -r $WWW_DIR  || echo -e "[!] Unable to delete $WWW_DIR"
		echo -e " -  Removed $WWW_DIR"
	fi

	echo -e "-Updating init---------------------------------"
        if [ "$DISTRO" == "DEBIAN" ]
        then
                for file in $INIT_SCRIPTS
                do
			update-rc.d $file remove
                done

        elif [ "$DISTRO" == "REDHAT" ]
	then
		echo NOT DONE	
	fi
	echo -e "------------------------------------------------"
	echo -e "[*] Removal process complete"
}

function installstatus()
{
	SUCCESS=1

	echo -e "* Status"
	if [ -d $TARGET_DIR ] 
	then
		echo -e "  Yes Target install dir $TARGET_DIR Exists"	
	else
		echo -e "  No  Target install dir $TARGET_DIR does not exist"
		SUCCESS=0

	fi
	
	for file in $INSTALL_FILES
	do
		if [ -f $TARGET_DIR/$file ] 
		then
			echo -e "  Yes $TARGET_DIR/$file Exists"
		else
			echo -e "  No  $TARGET_DIR/$file does not exist"
			SUCCESS=0
		fi

	done
	
	for file in $INIT_SCRIPTS
	do
	
		if [ -f $TARGET_DIR/$file ]
		then
			echo -e "  Yes $TARGET_DIR/$file Exists"
		else
			echo -e "  No  $TARGET_DIR/$file does not exist"
			SUCCESS=0
		fi	
	done
	
	for file in $PERL_MODULES
	do
		if [ -f $OFPC_LIB_DIR/$file ]
		then
			echo -e "  Yes $OFPC_LIB_DIR/$file Exists"
		else
			echo -e "  No  $OFPC_LIB_DIR/$file does not exist"
			SUCCESS=0
		fi	
	done


	echo -e "--------------------------------"
	if [ $SUCCESS == 1 ] 
	then
		echo -e "  Installation Okay"
	else
		echo -e "  OpenFPC Not installed correctly"
	fi
	echo -e "--------------------------------"
}

echo -e "
**************************************************************************
 *  OpenFPC installer - Leon Ward (leon@openfpc.org) v$openfpcver
    A set if scripts to help manage and find data in a large network traffic
    archive. 

    - http://www.openfpc.org 
"
	


if  [ "$DISTRO" == "AUTO" ]
then
	[ -f /etc/debian_version ]  && DISTRO="DEBIAN"
	[ -f /etc/redhat-release ] && DISTRO="REDHAT"

	if [ "$DISTRO" == "AUTO" ] 
	then
		die "[*] Unable to detect distro. Set manually"
	fi

	echo -e "[*] Detected distribution as $DISTRO\n"
fi

case $1 in  
        install)
		checkdeps
                doinstall
        ;;
        forceinstall)
                doinstall
        ;;
        remove)
                remove
        ;;
        status)
                installstatus
        ;;
	reinstall)
		echo [*] Running REINSTALL remove
		remove
		echo [*] Running REINSTALL install
		doinstall
	;;
     *)
                echo -e " install   	- Install the system"
                echo -e " forceinstall  - Install the system without checking for deps"
                echo -e " remove     	- Remove the system"
                echo -e " status     	- Check install status"
                echo -e " reinstall  	- Re-install system"
		echo -e "\n Example:"
		echo -e " $ sudo ./openfpc-install install"
        ;;
esac
