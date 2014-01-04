# To be included in make-ad-vm.sh

source conf.d/domain.info

netbios=`echo $VM_AD_DOMAIN | sed -e 's/\.//g' | tr '[a-z]' '[A-Z]'`
VM_NETBIOS_NAME=${VM_NETBIOS_NAME:-"$netbios"}

VM_NET="--network=bridge=br0,model=virtio"

VM_IMG_DIR=/vmguest/infra_win
VM_DATAIMG_DIR=/vmguest/infra_win
ANS_FILE_DIR=${ANS_FILE_DIR:-$BASEDIR/answerfiles}

FLOPPY_DIR=/vmguest/floppy
FLOPPY_MNT=${FLOPPY_MNT:-/mnt/floppy}

WIN_ISO=${WIN_ISO:-/vmguest/isoimage/GRMSXEVAL_EN_DVD.iso}
WIN_VER_REL_ARCH=${WIN_VER_REL_ARCH:-win2k8x8664}

WIN_VM_DISKFILE=${WIN_VM_DISKFILE:-$VM_IMG_DIR/$VM_NAME.raw}
WIN_VM_DATA_DISKFILE=${WIN_VM_DCDATA_DISKFILE:-$VM_DATAIMG_DIR/DATA-$VM_NAME.raw}

ADMINNAME=${ADMINNAME:-Administrator}
SETUP_PATH=${SETUP_PATH:-"A:"}
FIRSTBOOT_SCRIPT="postinstall.cmd"

if [ ! -d VM_IMG_DIR ] ; then
  mkdir -p VM_IMG_DIR
fi

if [ ! -d VM_DATAIMG_DIR ]; then
  mkdir -p VM_DATAIMG_DIR
fi

if [ ! -d FLOPPY_DIR ]; then
  mkdir -p FLOPPY_DIR
fi