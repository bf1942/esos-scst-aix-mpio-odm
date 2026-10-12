#!/bin/ksh
PATH=/usr/bin:/usr/sbin:/bin:/sbin
export PATH
ODMDIR=/etc/objrepos
export ODMDIR

ODMFILE=/usr/lpp/scst_mpio/odm/scst_device.odm
DISKUT='disk/fcp/scstmpio'
PCMUT='PCM/friend/scstmpio'
LEGACYQ='uniquetype=disk/fcp/mpioosdisk AND attribute=mpio_model_map AND deflt=0808SCST_BIO'
LEGACYRULE='/usr/lpp/scst_mpio/bin/scst_mpio_tune -q'

# Required AIX native disk/MPIO infrastructure must already exist.
odmget -q 'uniquetype=disk/fcp/mpioosdisk' PdDv 2>/dev/null | grep -q '^PdDv:' || {
    print -u2 "ERROR: disk/fcp/mpioosdisk is missing. Install the AIX FC disk/MPIO device support first."
    exit 1
}
odmget -q 'DvDr=aixdiskpcmke' PdDv 2>/dev/null | grep -q '^PdDv:' || {
    print -u2 "ERROR: AIX native disk PCM (aixdiskpcmke) is not installed."
    exit 1
}
[ -x /usr/lib/methods/cfgscsidisk ] || {
    print -u2 "ERROR: /usr/lib/methods/cfgscsidisk is missing."
    exit 1
}
[ -r "$ODMFILE" ] || {
    print -u2 "ERROR: $ODMFILE is missing."
    exit 1
}

# Do not overwrite a foreign definition using our chosen unique types.
if odmget -q "uniquetype=$DISKUT" PdDv 2>/dev/null | grep -q '^PdDv:'; then
    print -u2 "ERROR: $DISKUT already exists. Refusing to overwrite an existing device definition."
    exit 1
fi
if odmget -q "uniquetype=$PCMUT" PdDv 2>/dev/null | grep -q '^PdDv:'; then
    print -u2 "ERROR: $PCMUT already exists. Refusing to overwrite an existing PCM definition."
    exit 1
fi

odmadd "$ODMFILE" || exit 1

# Verify both sides of the disk<->PCM relation.
odmget -q "uniquetype=$DISKUT" PdDv 2>/dev/null | grep -q '^PdDv:' || exit 1
odmget -q "uniquetype=$DISKUT AND attribute=PCM" PdAt 2>/dev/null | grep -q 'PCM/friend/scstmpio' || exit 1
odmget -q "uniquetype=$PCMUT AND attribute=dvc_support" PdAt 2>/dev/null | grep -q 'disk/fcp/scstmpio' || exit 1
odmget -q "uniquetype=$DISKUT AND attribute=model_map AND deflt=0808SCST_BIO" PdAt 2>/dev/null | grep -q '^PdAt:' || exit 1

# Remove only the legacy v1 vendor-wide generic mapping, otherwise cfgmgr can
# continue selecting disk/fcp/mpioosdisk instead of the new vendor type.
odmdelete -q "$LEGACYQ" -o PdAt >/dev/null 2>&1 || true

# Remove the v1 cfgmgr tuning hook if it is still present. It only targeted
# disk/fcp/mpioosdisk and is no longer required in the v2 architecture.
odmdelete -q "rule=\"$LEGACYRULE\"" -o Config_Rules >/dev/null 2>&1 || true

print "Installed SCST_BIO AIX Device ODM support:"
print "  Disk unique type: $DISKUT"
print "  PCM unique type : $PCMUT"
print "Existing configured hdisks are NOT removed or reconfigured automatically."
print "Safely remove stale SCST hdisk objects before cfgmgr if you want them rediscovered as $DISKUT."
exit 0
