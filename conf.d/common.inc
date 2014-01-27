# To be included in make-ad-vm.sh

source $BASEDIR/domain.info

netbios=`echo $VM_AD_DOMAIN | sed -e 's/\.//g' | tr '[a-z]' '[A-Z]'`
VM_NETBIOS_NAME=${VM_NETBIOS_NAME:-"$netbios"}
PRIMARY_DNS=127.0.0.1
# SECONDARY_DNS=

VM_NET_INT_BRIDGE="br0"
VM_NET_EXT_BRIDGE="br1"

VM_BASE_DIR=/vmstore
VM_IMG_DIR=$VM_BASE_DIR/fast
VM_DATAIMG_DIR=$VM_BASE_DIR/primary

ANS_FILE_DIR=${ANS_FILE_DIR:-$BASEDIR/answerfiles}

FLOPPY_DIR=$VM_DATAIMG_DIR/floppy
FLOPPY_MNT=${FLOPPY_MNT:-/mnt/floppy}

WIN_ISO=${WIN_ISO:-/vmstore/isoimage/GRMSXEVAL_EN_DVD.iso}
WIN_VER_REL_ARCH=${WIN_VER_REL_ARCH:-win2k8x8664}

WIN_VM_DISKFILE=${WIN_VM_DISKFILE:-$VM_IMG_DIR/$VM_NAME.raw}
WIN_VM_DATA_DISKFILE=${WIN_VM_DCDATA_DISKFILE:-$VM_DATAIMG_DIR/DATA-$VM_NAME.raw}

ADMINNAME=${ADMINNAME:-Administrator}
SETUP_PATH=${SETUP_PATH:-"A:"}
FIRSTBOOT_SCRIPT="postinstall.cmd"

if [ -z $SECONDARY_DNS ] ; then
  SECONDARY_DNS_STRING="\n            <IpAddress wcm:action=\"add\" wcm:keyValue=\"2\">$SECONDARY_DNS<\/IpAddress>\n"
else
  SECONDARY_DNS_STRING=""
fi

if [ -z $VM_AD_DOMAIN ] ; then
  echo "Missing Active Directory DOMAIN NAME."
  exit 1
elif [ -z $ADDS_ADMIN_PASSWORD ] ; then
  echo "Missing Active Directory DOMAIN ADMINISTRATOR PASSWORD."
  exit 1
elif [ -z $ADDS_SAFEADMIN_PASSWORD ] ; then
  echo "Missing Active Directory Safe Mode ADMINISTRATOR PASSWORD."
  exit 1
else
  echo "The created VM will be a member of this Active Directory domain - \"$VM_AD_DOMAIN\""
fi

if [ ! -d $VM_BASE_DIR ] ; then
  echo "Virtual Machine repo \"$VM_BASE_DIR\" was not found"
  exit 1
fi

if [ ! -d $VM_IMG_DIR ] ; then
  mkdir -p $VM_IMG_DIR
fi

if [ ! -d $VM_DATAIMG_DIR ]; then
  mkdir -p $VM_DATAIMG_DIR
fi

if [ ! -d $FLOPPY_DIR ]; then
  mkdir -p $FLOPPY_DIR
fi

if [ ! -d $FLOPPY_MNT ]; then
  mkdir -p $FLOPPY_MNT
fi
