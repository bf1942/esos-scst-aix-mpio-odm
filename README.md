# ESOS / SCST AIX MPIO ODM

Vendor-style AIX/VIOS Device ODM support for Fibre Channel LUNs exported by ESOS/SCST with the SCSI INQUIRY vendor ID `SCST_BIO`.

> **Status:** v2.0.0.0 RC1 / lab validation. This is custom integration code and is not IBM-certified storage support.

## Goal

Instead of adding `SCST_BIO` to IBM's generic `disk/fcp/mpioosdisk` model table, this package creates independent AIX device identities:

```text
disk/fcp/scstmpio
        |
        v
PCM/friend/scstmpio
        |
        v
aixdiskpcmke
```

The disk type continues to use the native AIX disk configuration stack:

```text
DvDr      = scsidisk
Configure = /usr/lib/methods/cfgscsidisk
Change    = /usr/lib/methods/chgdisk
```

The PCM type reuses AIX Native MPIO runtime components:

```text
DvDr      = aixdiskpcmke
Configure = aixdiskpcmrtl
```

Expected result after validation:

```text
# lsdev -Cc disk
hdisk0 Available 03-00-01 SCST MPIO FC Disk

# lsdev -l hdisk0 -F 'name:uniquetype:description'
hdisk0:disk/fcp/scstmpio:SCST MPIO FC Disk

# lsmpio -l hdisk0
# multiple fscsi paths should belong to the same hdisk
```

## Recognition

The RC1 ODM contains a vendor-only `model_map` for:

```text
0808SCST_BIO
```

and exact Vendor+Product fallback entries for the Product IDs observed during development:

```text
SCST_BIO / vios
SCST_BIO / aix72
```

SCSI VPD page `0x83` is used for MPIO identity (`unique_id=081083`).

## Default policy

Disk defaults include `queue_depth=32`, `reserve_policy=no_reserve`, and `rw_timeout=30`.

PCM defaults include `algorithm=shortest_queue`, `hcheck_interval=60`, `hcheck_cmd=test_unit_rdy`, `hcheck_mode=nonactive`, and `timeout_policy=fail_path`.

Unlike the old v1.x package, v2 does **not** use a `Config_Rules` post-cfgmgr tuning hook. Policy is represented directly in predefined ODM attributes.

## Build

Build on AIX or from a VIOS `oem_setup_env` shell. `mkinstallp` and `gencat` are required; `mkinstallp` is provided by `bos.adt.insttools`.

```sh
chmod +x build.sh post_install.sh pre_deinstall.sh payload/usr/lpp/scst_mpio/bin/scst_mpio_check
./build.sh
```

The BFF is produced under `payload/tmp/`.

Preview before installation:

```sh
cd payload/tmp
inutoc .
installp -L -d .
installp -apd . devices.fcp.disk.SCST.mpio.rte
```

Install:

```sh
installp -aXgd . devices.fcp.disk.SCST.mpio.rte
```

Verify predefined ODM:

```sh
/usr/lpp/scst_mpio/bin/scst_mpio_check
```

## RC1 validation sequence

Do not test against an in-use production LUN.

1. Back up ODM and confirm the test disk is not in use.
2. Install the fileset and verify the new `PdDv`/`PdAt` objects.
3. Existing configured disks retain their old `PdDvLn`; the installer deliberately does not remove them.
4. Safely undefine the test SCST disk object.
5. Run `cfgmgr` (or `cfgdev` on VIOS).
6. Confirm that the LUN is rediscovered as `disk/fcp/scstmpio`.
7. Confirm both FC paths are attached to the same hdisk with `lsmpio`.
8. Validate path failure/recovery before considering broader use.

The primary RC1 question is whether `cfgscsidisk` selects the independent `disk/fcp/scstmpio` type from the vendor-only `model_map`. The exact Vendor+Product entries are retained as fallbacks while this behavior is validated.

## Repository layout

```text
build.sh
post_install.sh
pre_deinstall.sh
catalog/scstmpio.msg
payload/usr/lpp/scst_mpio/odm/scst_device.odm
payload/usr/lpp/scst_mpio/bin/scst_mpio_check
payload/usr/lpp/scst_mpio/README
```

## Safety properties

- Installation does not remove or reconfigure existing hdisks.
- Deinstallation refuses to remove predefined support while `disk/fcp/scstmpio` configured devices still exist.
- v2 removes only the legacy v1 `SCST_BIO` generic `mpio_model_map` entry and the old v1 tuning hook, if present.
- The package does not replace IBM `scsidisk`, `cfgscsidisk`, or `aixdiskpcmke` binaries.
