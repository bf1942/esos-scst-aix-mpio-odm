#!/bin/ksh
PATH=/usr/bin:/usr/sbin:/bin:/sbin
export PATH
ODMDIR=/etc/objrepos
export ODMDIR

DISKUT='disk/fcp/scstmpio'
PCMUT='PCM/friend/scstmpio'

# Never remove predefined support while configured devices still reference it.
if odmget -q "PdDvLn=$DISKUT" CuDv 2>/dev/null | grep -q '^CuDv:'; then
    print -u2 "ERROR: configured $DISKUT devices still exist."
    print -u2 "Remove/undefine those hdisks safely before deinstalling this fileset."
    exit 1
fi

odmdelete -q "uniquetype=$DISKUT" -o PdAt >/dev/null 2>&1 || true
odmdelete -q "uniquetype=$DISKUT" -o PdDv >/dev/null 2>&1 || true
odmdelete -q "uniquetype=$PCMUT" -o PdAt >/dev/null 2>&1 || true
odmdelete -q "uniquetype=$PCMUT" -o PdDv >/dev/null 2>&1 || true

print "Removed SCST_BIO predefined disk and PCM ODM definitions."
exit 0
