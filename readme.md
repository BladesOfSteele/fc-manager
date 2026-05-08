# FC Manager Scripts

This repository contains operational Korn shell scripts used to manage IBM i FC refresh workflows and tape adapter movement.

## create_fc.ksh

Prepares an IBM i Flash Copy (FC) LPAR with a fresh copy of production volumes for backup processing.

### What it does

1. Finds the managed system that contains the FC LPAR.
2. Validates the FC LPAR is in `Not Activated` state.
3. Creates a timestamped snapshot of the production volume group.
4. Refreshes the FC thin-clone volume group from that snapshot.
5. Waits 60 seconds.
6. Marks the snapshot for deletion.
7. Boots the FC LPAR.

All key SSH operations are checked for non-zero return codes and the script exits on failure.

### Configuration

Edit variables at the top of the script as needed:

| Variable | Default | Description |
|---|---|---|
| `LPAR` | `IBMi_PROD` | Production LPAR base name |
| `FC_LPAR` | `${LPAR}_FC` | FC target LPAR name |
| `HMC` | `hmc` | HMC host |
| `FLASH` | `flash` | FlashSystem host |
| `HMC_USER` | `fc_manager` | HMC SSH user |
| `FLASH_USER` | `msteele` | FlashSystem SSH user |
| `PROD_VG` | `$LPAR` | Production volume group |
| `PROD_FC_VG` | `${LPAR}_FC` | FC thin-clone volume group |
| `DRY_RUN` | `0` | Set to `1` to print commands only |

### Usage

```sh
./create_fc.ksh
```

Dry run:

```sh
DRY_RUN=1 ./create_fc.ksh
```

### Prerequisites

- SSH access configured for `fc_manager@hmc` and `msteele@flash`.
- FC thin-clone volume group and mappings already exist.
- FC LPAR must be powered off before execution.
- FlashSystem volume protection timer must be expired to avoid `CMMVC1035E` during refresh.

## move_tape.ksh

Moves a tape adapter slot from its currently assigned LPAR to a target LPAR.

### What it does

1. Reads the current LPAR assignment for a configured physical slot.
2. Validates the target LPAR exists on the configured managed system.
3. Executes `chhwres` to move the slot from the current LPAR to the target LPAR.

### Configuration

Edit script variables if your environment differs:

| Variable | Default | Description |
|---|---|---|
| `SYSTEM` | `Server-9009-41A-SN7817760` | Managed system name |
| `SLOT` | `2102001B` | Physical slot ID for the tape adapter |
| `HMC` | `hmc` | HMC host |
| `HMC_USER` | `fc_manager` | HMC SSH user |

### Usage

```sh
./move_tape.ksh <LPAR_NAME>
```

Example:

```sh
./move_tape.ksh IBMi_PROD_FC
```

The script exits with an error if the target LPAR does not exist or if the move operation fails.

## Notes

- Both scripts are intended for operators with appropriate HMC/Flash permissions.
- Test in a non-production or DRY_RUN scenario before operational use.
