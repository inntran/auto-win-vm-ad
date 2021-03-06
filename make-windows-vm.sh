#!/bin/bash

# Available roles: 
#  DOMAIN CONTROLLER: newdomain, replica
#  Certification Authority: offlinerootca, offlinepolicyca, issuingca
#  SUPPORTING: iis, wsus
#  WORKSTATION: adminwks, default

# SCRIPT BASEDIR
directoryx="$(dirname -- $(readlink -fn -- "$0"; echo x))"
BASEDIR="${directoryx%x}"

usage="Usage make-windows-vm.sh -n VM_NAME -r VM_ROLE -i IP_ADDRESS"
while getopts "n:r:i:h" opt; do
  case $opt in
    n  ) VM_NAME=$OPTARG ;;
    r  ) VM_ROLE=$OPTARG ;;
    i  ) VM_IP=$OPTARG ;;
    h  ) echo $usage 
         exit 1 ;;
    \? ) echo $usage
         exit 1 ;;
  esac
done

VM_NAME=${VM_NAME:-TESTVM}
VM_NAME=`echo $VM_NAME|tr '[a-z]' '[A-Z]'`
VM_ROLE=${VM_ROLE:-default}

# COMMON SETTINGS
source $BASEDIR/conf.d/common.inc

# ROLE SPECIFIC SETTINGS
if [[ $VM_ROLE =~ newdomain|replica|offlinerootca|iis|offlinepolicyca|issuingca|wsus|adminwks|default ]] ; then
  source "$BASEDIR/conf.d/$VM_ROLE.inc"
  case $VM_ROLE in
    "newdomain"|"replica" )
            UNATTENDED_XML="domainctl.xml"
            ;;
    "offlinerootca"|"offlinepolicyca"|"issuingca" )
            UNATTENDED_XML="standalone.xml"
            ;;
    "adminwks"|"default" )
            UNATTENDED_XML="adclient.xml"
            ;;
    "iis" )
            UNATTENDED_XML="iisaspnet.xml"
            ;;
    "wsus" )
            UNATTENDED_XML="wsus.xml"
            ;;
    * )
            UNATTENDED_XML="standalone.xml"
            ;;
  esac
else
  echo "Error: Invalid VM role given, loading default settings"
  source "$BASEDIR/conf.d/default.inc"
fi

# SET DNS SERVERS
if [ ! -z $SECONDARY_DNS ] ; then
  SECONDARY_DNS_STRING="\n            <IpAddress wcm:action=\"add\" wcm:keyValue=\"2\">$SECONDARY_DNS<\/IpAddress>"
else
  SECONDARY_DNS_STRING=""
fi

# VIRTUAL MACHINE NETWORK
case $IFACE_COUNT in
  0) VM_NET="" ;;
  1) VM_NET="--network=bridge=$VM_NET_INT_BRIDGE,model=virtio" ;;
  2) VM_NET="--network=bridge=$VM_NET_INT_BRIDGE,model=virtio --network=bridge=$VM_NET_EXT_BRIDGE,model=virtio" ;;
esac

# DISK
if [ -z $DATA_DISKSIZE ] ; then
  VM_DISKS="--disk path=$WIN_VM_DISKFILE,bus=virtio,size=$VM_DISKSIZE,format=raw"
else
  VM_DISKS="--disk path=$WIN_VM_DISKFILE,bus=virtio,size=$VM_DISKSIZE,format=raw
            --disk path=$WIN_VM_DATA_DISKFILE,bus=virtio,size=$DATA_DISKSIZE,format=raw"
fi

# FLOPPY
ANS_FLOPPY=${ANS_FLOPPY:-$FLOPPY_DIR/answer-$VM_ROLE-$VM_NAME-`date +'%Y%m%d%H%M%S'`.flp}

# SUBSTITUTIONS FUNCTION
do_subst()
{
    sed \
        -e "s/@ADMINPASSWORD@/$ADDS_ADMIN_PASSWORD/g" \
        -e "s/@SAFEADMINPASSWORD@/$ADDS_SAFEADMIN_PASSWORD/g" \
        -e "s/@DOMAINNAME@/$VM_AD_DOMAIN/g" \
        -e "s/@ADMINNAME@/$ADMINNAME/g" \
        -e "s/@VM_AD_DOMAIN@/$VM_AD_DOMAIN/g" \
        -e "s/@VM_NETBIOS_NAME@/$VM_NETBIOS_NAME/g" \
        -e "s/@VM_NAME@/$VM_NAME/g" \
        -e "s/@VM_FQDN@/$VM_FQDN/g" \
        -e "s/@VM_AD_SUFFIX@/$VM_AD_SUFFIX/g" \
        -e "s/@SETUP_PATH@/$SETUP_PATH/g" \
        -e "s/@AD_FOREST_LEVEL@/$AD_FOREST_LEVEL/g" \
        -e "s/@AD_DOMAIN_LEVEL@/$AD_DOMAIN_LEVEL/g" \
        -e "s/@VM_IP@/$VM_IP/g" \
        -e "s/@VM_ROUTER@/$VM_ROUTER/g" \
        -e "s/@FIRSTBOOT_SCRIPT@/$FIRSTBOOT_SCRIPT/g" \
        -e "s/@PRIMARY_DNS@/$PRIMARY_DNS/g" \
        -e "s/@SECONDARY_DNS_STRING@/$SECONDARY_DNS_STRING/g" \
        $1
}

ETC_HOSTS_IP=`getent hosts | grep -v localhost | grep -v ipv6 | grep $VM_NAME|awk '{print $1}'`
if [ "$VM_IP" != "$ETC_HOSTS_IP" ] ; then
  echo Error: your machine $VM_NAME has no IP address in /etc/hosts. It will be appended to /etc/hosts
  getent hosts
  echo "$VM_IP    $VM_NAME.$VM_AD_DOMAIN $VM_NAME" >> /etc/hosts
fi
VM_FQDN="$VM_NAME.$VM_AD_DOMAIN"
echo using hostname $VM_FQDN for $VM_NAME with IP address $VM_IP

# lmhn: left most host name
# lmdn: left most domain name
lmhn=`echo $VM_FQDN | sed -e 's/^\([^.]*\).*$/\1/'`
domain=`echo $VM_FQDN | sed -e 's/^[^.]*\.//'`
VM_AD_DOMAIN=${VM_AD_DOMAIN:-"$domain"}
lmdn=`echo $VM_AD_DOMAIN | sed -e 's/^\([^.]*\).*$/\1/'`
#suffix=`echo $VM_AD_DOMAIN | sed -e 's/^/dc=/' -e 's/\./,dc=/g'`
netbios=`echo $VM_AD_DOMAIN | sed -e 's/\.//g' | tr '[a-z]' '[A-Z]'`
#VM_CA_NAME=${VM_CA_NAME:-"$lmdn-$lmhn-ca"}
#VM_AD_SUFFIX=${VM_AD_SUFFIX:-"$suffix"}
VM_NETBIOS_NAME=${VM_NETBIOS_NAME:-"$netbios"}
#ADMIN_DN=${ADMIN_DN:-"cn=$ADMINNAME,cn=Users,$VM_AD_SUFFIX"}

##### AD Functional Level, for Windows 2008 R2, it is 4. Reference: http://technet.microsoft.com/en-us/library/cc739548(v=ws.10).aspx
if [ -z "$AD_FOREST_LEVEL" -o -z "$AD_DOMAIN_LEVEL" ] ; then
    case $WIN_VER_REL_ARCH in
    win2k8*) AD_FOREST_LEVEL=${AD_FOREST_LEVEL:-4}
             AD_DOMAIN_LEVEL=${AD_DOMAIN_LEVEL:-4} ;;
    win2012*) AD_FOREST_LEVEL=${AD_FOREST_LEVEL:-Win2012}
              AD_DOMAIN_LEVEL=${AD_DOMAIN_LEVEL:-Win2012} ;;
    *) echo Error: unknown windows version $WIN_VER_REL_ARCH
       echo Please set AD_FOREST_LEVEL and AD_DOMAIN_LEVEL ;;
    esac
fi

if [ ! -f $ANS_FLOPPY ] ; then
    mkfs.vfat -C $ANS_FLOPPY 1440 || { echo error $? from mkfs.vfat -C $ANS_FLOPPY 1440 ; exit 1 ; }
fi

if [ ! -d $FLOPPY_MNT ] ; then
    mkdir -p $FLOPPY_MNT || { echo error $? from mkdir -p $FLOPPY_MNT ; exit 1 ; }
fi

mount -o loop -t vfat $ANS_FLOPPY $FLOPPY_MNT || { echo error $? from mount -o loop -t vfat $ANS_FLOPPY $FLOPPY_MNT ; exit 1 ; }

# replace .in files with the real data
# convert to DOS format to make them easier to read in Windows
# files in answerfiles/winverrel/ will override files in answerfiles/ if
# they have the same name - this allow to provide version specific files
# to override the more general ones in answerfiles/
for file in $ANS_FILE_DIR/* $ANS_FILE_DIR/$WIN_VER_REL_ARCH/* "$@" ; do
    if [ ! -f "$file" ] ; then continue ; fi
    err=
    case $file in
        *$UNATTENDED_XML*) outfile=$FLOPPY_MNT/autounattend.xml ;;
        *) outfile=$FLOPPY_MNT/`basename $file .in` ;;
    esac
    case $file in
        *.in) do_subst $file | unix2dos > $outfile || err=$? ;;
        *) unix2dos -q -n $file $outfile || err=$? ;;
    esac
    if [ -n "$err" ] ; then
        echo error $err copying $file to $outfile  ; umount $FLOPPY_MNT ; exit 1
    fi
done

umount $FLOPPY_MNT || { echo error $? from umount $FLOPPY_MNT ; exit 1 ; }
VI_FLOPPY="--disk path=$ANS_FLOPPY,device=floppy"

virt-install --cpu=host \
    --name "$VM_NAME" --ram=$VM_RAM --vcpu=$VM_CPUS \
    --cdrom $WIN_ISO --memballoon none --graphics=vnc --os-variant=win2k8 \
    $VM_DISKS \
    $VI_FLOPPY $VI_EXTRAS_CD \
    $VM_NET \
    $VI_DEBUG --noautoconsole || { echo error $? from virt-install ; exit 1 ; }

exit 0
