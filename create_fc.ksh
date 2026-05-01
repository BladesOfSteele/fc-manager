#!/usr/bin/ksh
#
# create_fc.ksh
#
#       script top prepare the FC LPAR with a fresh FC of production for backup
#       Order of script.
#               1. Validate the target LPAR is down, if not, abort.
#               2. Initiate a Snapshot of the source LPAR.
#               3. Create a thin clone and VG from Snapshot.
#               4. Wait
#               5. Delete snapshot.
#               6. Mount thin clone volumes to target host.
#               7. Boot target host.
#       Variable:
#               1.  LPAR source ID
#               2. LPAR target ID
#               3. Snapshot name
#
#       Written by: Mark Steele/dss
#
# Variables
LPAR=IBMi_PROD
FC_LPAR=PROD-FC
HMC=hmc
FLASH=flash
HMC_USER=fc_manager
FLASH_USER=msteele
PROD_VG=$LPAR
PROD_FC_VG=${LPAR}_FC
SNAPSHOT_NAME=${LPAR}_snapshot_$(date +%Y%m%d%H%M%S)
DRY_RUN=0  # Set to 1 for dry run, 0 for actual execution

# Function to run SSH commands with error handling
run_ssh() {
  step="$1"
  target="$2"
  command="$3"

  echo "STEP: $step"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY_RUN: ssh $target \"$command\""
    return 0
  fi

  ssh "$target" "$command"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "ERROR: $step failed (exit code $rc)" >&2
    exit "$rc"
  fi
}

# ******* Main script execution ******* 

# find the managed system containing the LPAR
echo "Finding the managed system containing the LPAR $FC_LPAR..."
for SYS in $(ssh "$HMC_USER@$HMC" lssyscfg -r sys -F name) ; do 
  for SYSLPAR in $(ssh "$HMC_USER@$HMC" lssyscfg -r lpar -m $SYS -F name) ; do 
    if [ $SYSLPAR == $FC_LPAR ] ; then 
      SYSTEM=$SYS
      break 2
    fi
  done
done

# Validate the FC LPAR is powered down. This is assuming the backup procedure will shutdown the LPAR at completion.
echo "Validate the FC LPAR is not powered up."
FC_STATE=$(ssh "$HMC_USER@$HMC" "lssyscfg -r lpar -m $SYSTEM -F state --filter lpar_names=$FC_LPAR")
RC=$?
if [ "$RC" -ne 0 ]; then
  echo "ERROR: Unable to validate FC LPAR state (exit code $RC)" >&2
  exit "$RC"
fi

if [ "$FC_STATE" != "Not Activated" ]; then
  echo "ERROR: The FC LPAR $FC_LPAR is in an activated state. Needs to be Not Activated! Exiting" >&2
  exit -1
fi

# This creates a new snapshot, with date stamp of the production LPAR with a retention of 3 days. 
# This is to ensure the snapshot is available for the thin clone creation, but also will be automatically removed 
# after 3 days if something goes wrong with the thin clone creation and manual cleanup is needed.
echo "\nCreate the snapshot of the production LPAR."
run_ssh "Create production snapshot" "$FLASH_USER@$FLASH" "svctask addsnapshot -gui -volumegroup $PROD_VG -name $SNAPSHOT_NAME -retentiondays 3"

# This refreshes the thin clone of the production LPAR from the snapshot. The thin clone already exists, in the
# PROD_FC_VG volume group. The volumes are already mapped to the target LPAR.
# Note: you need to wait for the volume protection timer to expire, after shutting down the LPAR, before running this
# otherwise you will run into a CMMVC1035E error. By default this timer is 15 minutes. If this happens, orphan snapshots
# will purge after the 3 day retention period.
echo "\nRefresh thin clone from latest snapshot."
run_ssh "Refresh thin clone from snapshot" "$FLASH_USER@$FLASH" "svctask refreshfromsnapshot -fromsourcegroup $PROD_VG -snapshot $SNAPSHOT_NAME -volumegroup $PROD_FC_VG"

# Wait for 60 seconds to allow the thin clone to be created. This is unlikely to be necessary, just for safety.
echo "\nWaiting 60 seconds for thin clone to be created..."
sleep 60

# This flags the snapshot for deletion. The snapshot won't actually be deleted as long as the thin clone is still
# using it, but this ensures it will be automatically cleaned up after the thin clone is created and no longer needs 
# the snapshot. This is to prevent orphaned snapshots if something goes wrong with the thin clone creation and manual
# cleanup is needed.
echo "\nDelete the snapshot."
run_ssh "Delete snapshot" "$FLASH_USER@$FLASH" "svctask rmsnapshot -gui -volumegroup $PROD_VG -snapshot $SNAPSHOT_NAME"

# This tells the HMC to boot the target LPAR. The thin clone volumes are already mapped to the target LPAR, 
# so it will boot with the new FC volumes from the thin clone.
echo "\nBoot the target host."
# ssh fc_manager@hmc "chsysstate -r lpar -m \`lssyscfg -r sys -F name\` -o on --id 101"
run_ssh "Boot target host" "$HMC_USER@$HMC" "chsysstate -r lpar -m $SYSTEM -o on -n $FC_LPAR"

# Successfully completed all steps
echo "\nSuccessfully completed all steps. The FC LPAR should now be booting with the new FC volumes from the thin clone."
exit 0
