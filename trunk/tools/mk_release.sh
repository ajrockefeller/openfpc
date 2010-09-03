#!/bin/bash 

# Create a release file for OpenFPC
# It's simple, dirty, and works for me.

# Leon Ward - leon@rm-rf.co.uk

TARPATH=~
SRCPATH=..
FILES="ofpc-client.pl install-ofpc.sh openfpc openfpc.conf docs/README ofpc/Parse.pm ofpc/Request.pm ofpc-queued.pl setup-ofpc.pl"
VERFILES="install-ofpc.sh ofpc-client.pl openfpc ofpc-queued.pl"

echo Checking version numbers in code...
for i in $VERFILES
do
	VER=$(grep openfpcver $SRCPATH/$i |awk -F = '{print $2}')
	echo -e " $VER - $i"
done	

VER=$(grep openfpcver $SRCPATH/openfpc |awk -F = '{print $2}')
TARGET="$TARPATH/openfpc-$VER"
FILENAME="openfpc-$VER.tgz"
echo -e "* Build Version $VER in $TARPATH ? (ENTER = yes)"

read 

if [ -d $TARGET ]
then
	echo Error $TARGET exists. 
	echo Hit ENTER to rm -rf $TARGET, to stop it CRTL+C
	read 
	rm -rf $TARGET
	exit 1
else
	echo Creating $TARGET
	mkdir $TARGET

	for i in $FILES
	do
		echo -e "- Adding $i to $TARGET"
		cp $SRCPATH/$i $TARGET
	done
		cd $TARPATH
		tar -czf $FILENAME openfpc-$VER
	 	cd -	
fi

echo "Created $TARPATH/$FILENAME"