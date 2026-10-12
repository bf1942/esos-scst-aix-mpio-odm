# Changelog

## 2.0.0.0 RC1

- Introduced independent AIX disk unique type `disk/fcp/scstmpio`.
- Introduced independent friend PCM unique type `PCM/friend/scstmpio`.
- Reused native AIX `scsidisk`, `cfgscsidisk`, `aixdiskpcmke`, and `aixdiskpcmrtl` components.
- Added `SCST MPIO FC Disk` message catalog description.
- Moved queue, health-check, algorithm, and timeout defaults into predefined ODM attributes.
- Removed dependence on the v1.x `Config_Rules` post-cfgmgr tuning hook.
- Added migration cleanup for the legacy `SCST_BIO` `mpio_model_map` entry.
- Added safe install/deinstall checks and `scst_mpio_check` verification helper.
- Added RC1 `model_map` recognition for `SCST_BIO`, with observed `vios` and `aix72` Product ID fallbacks.

## 1.x historical design

The earlier package added `SCST_BIO` to IBM's generic `disk/fcp/mpioosdisk` `mpio_model_map`, which successfully enabled AIX Native MPIO but did not provide a distinct vendor device identity. v2 replaces that approach.
