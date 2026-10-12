#!/bin/ksh
set -u
PATH=/usr/bin:/usr/sbin:/bin:/sbin
export PATH

HERE=$(cd "$(dirname "$0")" && pwd)
BUILD="$HERE/payload"
TEMPLATE="$HERE/devices.fcp.disk.SCST.mpio.template"
POST="$HERE/post_install.sh"
PREDE="$HERE/pre_deinstall.sh"
VRMF=2.0.0.0
CAT_SRC="$HERE/catalog/scstmpio.msg"
CAT_NAME=scstmpio.cat

if [ "$(uname -s)" != "AIX" ]; then
    print -u2 "ERROR: build.sh must run on AIX/VIOS (inside oem_setup_env on VIOS)."
    exit 1
fi

for c in mkinstallp gencat; do
    command -v "$c" >/dev/null 2>&1 || {
        print -u2 "ERROR: $c not found."
        [ "$c" = "mkinstallp" ] && print -u2 "Install bos.adt.insttools."
        exit 1
    }
done

# Build our own lsdev description catalog. Install the same English catalog in
# common AIX locale paths plus prime fallback.
for loc in en_US EN_US C prime; do
    mkdir -p "$BUILD/usr/lib/nls/msg/$loc"
    rm -f "$BUILD/usr/lib/nls/msg/$loc/$CAT_NAME"
    gencat "$BUILD/usr/lib/nls/msg/$loc/$CAT_NAME" "$CAT_SRC" || exit 1
done

cat > "$TEMPLATE" <<EOT
Package Name: devices.fcp.disk.SCST.mpio
Package VRMF: $VRMF
Update: N
Fileset
  Fileset Name: devices.fcp.disk.SCST.mpio.rte
  Fileset VRMF: $VRMF
  Fileset Description: SCST_BIO AIX Native MPIO Device ODM Support
  USRLIBLPPFiles
    Post-installation Script: $POST
    Pre-deinstall Script: $PREDE
  EOUSRLIBLPPFiles
  Bosboot required: Y
  License agreement acceptance required: N
  Include license files in this package: N
  Requisites:
  USRFiles
    /usr/lpp/scst_mpio/odm/scst_device.odm
    /usr/lpp/scst_mpio/bin/scst_mpio_check
    /usr/lpp/scst_mpio/README
    /usr/lib/nls/msg/en_US/scstmpio.cat
    /usr/lib/nls/msg/EN_US/scstmpio.cat
    /usr/lib/nls/msg/C/scstmpio.cat
    /usr/lib/nls/msg/prime/scstmpio.cat
  EOUSRFiles
  ROOT Part: N
  ROOTFiles
  EOROOTFiles
  Relocatable: N
EOFileset
EOT

chown -R root:system "$HERE" 2>/dev/null || true
rm -rf "$BUILD/.info" "$BUILD/tmp"

print "Building devices.fcp.disk.SCST.mpio.rte $VRMF ..."
mkinstallp -d "$BUILD" -T "$TEMPLATE" || exit 1

print ""
print "Build complete:"
find "$BUILD/tmp" -type f -name '*.bff' -print 2>/dev/null
print ""
print "Verify image type:"
print "  cd $BUILD/tmp"
print "  inutoc ."
print "  installp -L -d ."
print ""
print "Preview:"
print "  installp -apd . devices.fcp.disk.SCST.mpio.rte"
print ""
print "Install:"
print "  installp -aXgd . devices.fcp.disk.SCST.mpio.rte"
