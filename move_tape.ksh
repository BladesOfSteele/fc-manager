#!/bin/ksh
#
# Script to move tape adapter to provided LPAR
#
# Usage: move_tape.ksh <LPAR_NAME>
#	where <LPAR_NAME> is the LPAR to move the tape adapter to.
#
#
#  lshwres -r io -m Server-9009-41A-SN7817760 --rsubtype slot -F lpar_name,phys_loc,description --filter "slots=2102001B"
#  IBMi_PROD,C6,"SAS RAID Controller, PCIe3 x8, Quad-port 6Gb"
#
# Written by: Mark Steele/dss
#	https://github.com/BladesOfSteele/fc-manager
#
# Variables
PROGNAME=${0##*/}
SYSTEM=Server-9009-41A-SN7817760
LPAR=$1
SLOT=2102001B
HMC=hmc
HMC_USER=fc_manager

function die
{
	print -u2 "$PROGNAME: $*"
	exit -1
}

# Capture current adapter assignment
CURRENT_LPAR=$(ssh "$HMC_USER@$HMC" lshwres -r io -m $SYSTEM --rsubtype slot -F lpar_name --filter "slots=$SLOT")
echo "Tape attached to $CURRENT_LPAR"

# Exit if source and target LPAR are the same
if [[ $CURRENT_LPAR = $LPAR ]] ; then
	echo "Tape adapter is already assigned to $LPAR"
	exit 0
fi

# Validate target LPAR exists
[[ $(ssh $HMC_USER@HMC lssyscfg -r lpar -m $SYSTEM --filter "lpar_names=$LPAR" -F name 2>/dev/null ) = $LPAR ]] || die "$LPAR Does not exist on $SYSTEM"

echo "Moving drive to $LPAR"
ssh $HMC_USER@HMC chhwres -r io -m $SYSTEM -o m -p $CURRENT_LPAR -t $LPAR -l $SLOT
rc=$?
if [[ $rc -ne 0 ]] ; then
	die "Moving tape drive from $CURRENT_LPAR to $LPAR failed (rc=$rc)" 
fi

