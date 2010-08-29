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
openfpcver="0.2"
TARGET_DIR="/opt/openfpc"
CONF_DIR="/etc/openfpc"
INSTALL_FILES="ofpc-client.pl openfpc openfpc.conf ofpc-queued.pl setup-ofpc.pl"
PERL_MODULES="Parse.pm Request.pm"
INIT_SCRIPTS="openfpc"
INIT_DIR="/etc/init.d/" 
REQUIRED_BINS="tcpdump date mergecap perl tshark"
LOCAL_CONFIG="/etc/openfpc/openfpc.conf"
PERL_LIB_DIR="/usr/local/lib/site_perl"

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

	# Check perl site includes dir is in the perl path
	if  perl -V | grep "$PERL_LIB_DIR" > /dev/null
	then
		echo " -  Installing modules to $PERL_LIB_DIR/ofpc"
	else
		die "[!] Perl include path problem. Cant find $PERL_LIB_DIR in Perl's @INC (perl -V to check)"
	fi	
	
        if [ -d $PERL_LIB_DIR/ofpc ] 
	then
		echo -e " -  $PERL_LIB_DIR/ofpc exists"
	else
		mkdir --parent $PERL_LIB_DIR || die "[!] Unable to mkdir $PERL_LIB_DIR/ofpc"
	fi

	[ -d $INIT_DIR ] || die "[!] Cannot find init.d directory $INIT_DIR. Something bad must have happened."

        if [ -d $TARGET_DIR ] 
	then
                die "[!] Can't Install in $TARGET_DIR - Directory Exists."
        else
                mkdir $TARGET_DIR
        fi
    
        for file in $INSTALL_FILES
        do
		echo -e " -  Installing $file"
                cp $file $TARGET_DIR || echo -e " -  Unable to copy $file to $TARGET_DIR"
        done

	######## Modules ###########

	if [ -d $PERL_LIB_DIR/ofpc ] 
	then
		echo -e " *  Found $PERL_LIB_DIR/ofpc"
	else
		mkdir $PERL_LIB_DIR/ofpc || die "[!] Unable to mkdir $PERL_LIB_DIR/ofpc"
	fi

	for file in $PERL_MODULES
	do
		echo -e " -  Installing PERL module $file"
		[ -d $PERL_LIB_DIR/ofpc ] || mkdir --parent $PERL_LIB_DIR/ofpc
		cp ofpc/$file $PERL_LIB_DIR/ofpc/$file
	done

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
		ln -s /etc/init.d/trafficbuffer /etc/rc3.d/S99trafficbuffer || echo "File exists"
		ln -s /etc/init.d/trafficbuffer /etc/rc5.d/S99trafficbuffer || echo "File exists"
		ln -s /etc/init.d/trafficbuffer /etc/rc6.d/K99trafficbuffer || echo "File exists"
		ln -s /etc/init.d/trafficbuffer /etc/rc0.d/K99trafficbuffer || echo "File exists"
	fi

	echo -e "
**************************************************************************
[*] Installation Complete 

    OpenFPC should now be installed and ready for configuration.
    To configure OpenFPC execute...

    $ sudo $TARGET_DIR/setup-ofpc.pl -c $CONF_DIR/openfpc.conf 

    For more informaiton, and advanced setup options take a look at $TARGET_DIR/setup-openfpc.pl --help
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
		if [ -f $PERL_LIB_DIR/ofpc/$file ]
		then	
			rm $PERL_LIB_DIR/ofpc/$file  || echo -e "[!] Unable to delete $file"
		else
			echo -e "    $PERL_LIB_DIR/ofpc/$file Not found"
		fi
	done

	echo -e "[*] Removing Symlinks..."
	for file in $INIT_SCRIPTS
	do
		if [ -L $INIT_DIR/$file ] 
		then
			if rm $INIT_DIR/$file 
			then
				echo -e " -  Removed   $INIT_DIR/$file "
			else
				echo -e " -  Failed to remove $INIT_DIR/$file"
			fi
		else
			echo -e " -  Can't find $INIT_DIR/$file - Won't remove"
		fi
	done
	
	if [ -d $TARGET_DIR ] 
	then
		rm -r $TARGET_DIR  || echo -e "[!] Unable to delete $TARGET_DIR"
		echo -e " -  Removed $TARGET_DIR"
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
		rm /etc/rc3.d/S99trafficbuffer || echo "init script not found"
		rm /etc/rc0.d/K99trafficbuffer || echo "init script not found"
		rm /etc/rc5.d/S99trafficbuffer || echo "init script not found"
		rm /etc/rc6.d/K99trafficbuffer || echo "init script not found"
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
		if [ -f $PERL_LIB_DIR/ofpc/$file ]
		then
			echo -e "  Yes $PERL_LIB_DIR/ofpc/$file Exists"
		else
			echo -e "  No  $PERL_LIB_DIR/ofpc/$file does not exist"
			SUCCESS=0
		fi	
	done


	echo -e "--------------------------------"
	if [ $SUCCESS == 1 ] 
	then
		echo -e "  Installation Okay"
	else
		echo -e "  Install has problems"
	fi
	echo -e "--------------------------------"
}

echo -e "
**************************************************************************
 *  OpenFPC installer - leon@rm-rf.co.uk v$openfpcver
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
                doinstall
        ;;
        remove)
                remove
        ;;
        status)
                installstatus
        ;;
	reinstall)
		echo Running REINSTALL
		remove
		echo And installing...
		doinstall
	;;
     *)
                echo -e " install   - Install the system"
                echo -e " remove     - Remove the system"
                echo -e " status     - Check install status"
                echo -e " reinstall  - Re-install system"
		echo -e "\n Example:"
		echo -e " $ sudo ./install-openfpc install"
        ;;
esac
