# create_fc.ksh

Prepares an IBM i Flash Copy (FC) LPAR with a fresh copy of the production environment for backup purposes.

## What It Does

The script automates the following sequence:

1. **Validates the FC LPAR is powered off** — queries the HMC via SSH and aborts if the target LPAR is not in the `Not Activated` state.
2. **Creates a production snapshot** — takes a dated snapshot of the production volume group (`IBMi_PROD`) on the IBM FlashSystem with a 3-day auto-retention.
3. **Refreshes the thin clone** — updates the FC volume group (`IBMi_PROD_FC`) from the new snapshot. The thin clone volumes are already mapped to the FC LPAR.
4. **Waits 60 seconds** — allows the thin clone refresh to complete.
5. **Deletes the snapshot** — flags the snapshot for deletion. It will not be removed while the thin clone still depends on it, but will be cleaned up automatically once no longer needed.
6. **Boots the FC LPAR** — instructs the HMC to power on the FC LPAR, which will start with the refreshed thin clone volumes.

All SSH steps are error-checked. If any step fails, the script prints an error message with the exit code and stops immediately.

## Prerequisites

- SSH key-based authentication configured for:
  - `fc_manager@hmc` (HMC)
  - `msteele@flash` (IBM FlashSystem)
- The FC LPAR thin clone volume group (`IBMi_PROD_FC`) and volume-to-LPAR mappings must already exist.
- The FC LPAR must be fully powered off before running the script (the prior backup procedure is expected to shut it down).
- The FlashSystem volume protection timer must have expired after the LPAR was shut down (default: 15 minutes). Running too early will result in a `CMMVC1035E` error.

## Configuration

Edit the variables at the top of the script before running:

| Variable        | Default                          | Description                              |
|-----------------|----------------------------------|------------------------------------------|
| `FC_LPAR_ID`    | `101`                            | LPAR ID of the FC target on the HMC      |
| `HMC`           | `hmc`                            | Hostname of the HMC                      |
| `FLASH`         | `flash`                          | Hostname of the IBM FlashSystem          |
| `HMC_USER`      | `fc_manager`                     | SSH user for the HMC                     |
| `FLASH_USER`    | `msteele`                        | SSH user for the FlashSystem             |
| `PROD_VG`       | `IBMi_PROD`                      | Source production volume group           |
| `PROD_FC_VG`    | `IBMi_PROD_FC`                   | Target FC thin clone volume group        |
| `DRY_RUN`       | `0`                              | Set to `1` to print commands without executing |

## Running the Script

```sh
./create_fc.ksh
```

To do a dry run (prints all SSH commands without executing them):

```sh
DRY_RUN=1 ./create_fc.ksh
```

The script requires execute permission. To set it:

```sh
chmod u+x create_fc.ksh
```

## Error Handling

If any SSH command fails, the script outputs:

```
ERROR: <step name> failed (exit code <rc>)
```

and exits immediately with that exit code. Check SSH connectivity, remote command availability, and FlashSystem volume protection timer status when troubleshooting.

## Author

Mark Steele / dss
