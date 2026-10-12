# Design notes

## Background

The original v1.x integration taught AIX to treat `SCST_BIO` LUNs as IBM's generic `disk/fcp/mpioosdisk` by adding an `mpio_model_map` entry. That proved the target's SCSI identity and page `0x83` data were sufficient for AIX Native MPIO, but the resulting device remained a generic `MPIO Other FC SCSI Disk Drive`.

v2 moves to a vendor-style Device ODM package with its own disk and PCM unique types.

## Device type

```text
disk/fcp/scstmpio
```

The disk type intentionally reuses native AIX components:

```text
DvDr        scsidisk
Define      /usr/lib/methods/define
Configure   /usr/lib/methods/cfgscsidisk
Change      /usr/lib/methods/chgdisk
Unconfigure /usr/lib/methods/ucfgdevice
Undefine    /usr/lib/methods/undefine
```

This package is therefore not a replacement kernel disk driver.

## PCM type

```text
PCM/friend/scstmpio
```

The PCM type uses:

```text
DvDr      aixdiskpcmke
Configure aixdiskpcmrtl
```

and declares:

```text
dvc_support = disk/fcp/scstmpio
```

The disk's `PCM` predefined attribute points back to `PCM/friend/scstmpio`.

This mirrors the structure observed in vendor-specific MPIO device definitions on VIOS, where independent disk unique types are associated with a friend PCM through `dvc_support`.

## Device recognition

RC1 provides:

```text
model_map = 0808SCST_BIO
```

plus exact Vendor+Product fallbacks for observed SCST targets:

```text
0818SCST_BIOvios            
0818SCST_BIOaix72           
```

The first field encodes the SCSI INQUIRY offset/length pattern used by AIX predefined disk model matching. RC1 validation must prove that the vendor-only 8-byte match is sufficient for `cfgscsidisk` to select the independent disk type.

## MPIO identity

The device uses SCSI VPD page `0x83`:

```text
unique_id values = 081083
```

The target must return a stable identifier that is identical across every FC path to the same LUN. Otherwise AIX may create separate hdisks instead of merging the paths.

## Defaults

Disk defaults are derived from the previously working generic `mpioosdisk` integration, with `queue_depth=32`, `reserve_policy=no_reserve`, and `rw_timeout=30`.

PCM policy is defined in the PCM PdAt objects rather than applied by a cfgmgr tuning hook. RC1 uses:

```text
algorithm       shortest_queue
hcheck_interval 60
hcheck_cmd      test_unit_rdy
hcheck_mode     nonactive
timeout_policy  fail_path
```

These values are part of RC1 test scope, especially behavior with one path versus multiple paths.

## Migration from v1.x

The v2 post-install script removes only the legacy entry:

```text
uniquetype=disk/fcp/mpioosdisk
attribute=mpio_model_map
deflt=0808SCST_BIO
```

and the old `Config_Rules` invocation of `scst_mpio_tune -q`.

It deliberately does not remove or redefine existing configured hdisks. A configured disk keeps its current `PdDvLn` until it is safely undefined and rediscovered.

## Validation gates

RC1 is considered successful only after all of the following are proven on a disposable/test LUN:

1. `cfgmgr`/`cfgdev` selects `disk/fcp/scstmpio`.
2. `lsdev` reports `SCST MPIO FC Disk`.
3. two FC paths map into one hdisk.
4. `lsmpio` reports both paths enabled.
5. target/path interruption produces expected failover and recovery behavior.
6. no unexpected `cfgmgr` method errors are introduced.
7. deinstall safety checks work as intended.
