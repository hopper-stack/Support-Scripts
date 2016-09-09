#!/bin/bash
# ----------------------------------------------------------
#
#   Date:     3rd September 2016
#   Comments: Initial Version
#
# ----------------------------------------------------------

# ----------------------------------------------------------
#                       File to Run
# ----------------------------------------------------------
FILE=/tmp/run-virsh.sh
echo "#!/bin/bash" > $FILE
echo "# ----------------------------------------------------------" >> $FILE
echo "#                                                           " >> $FILE
echo "#   Date:     3rd September 2016                            " >> $FILE
echo "#   Comments: Initial Version                               " >> $FILE
echo "#                                                           " >> $FILE
echo "# ----------------------------------------------------------" >> $FILE
echo >> $FILE

echo "# ----------------------------------------------------------" >> $FILE
echo "#                          Functions                        " >> $FILE
echo "# ----------------------------------------------------------" >> $FILE
echo "create-server(){" >> $FILE
echo "   cp /vm/template.qcow2 /vm/\${1}.qcow2" >> $FILE
echo "   chown qemu.qemu /vm/\${1}.qcow2" >> $FILE
echo "   virt-install --virt-type kvm --name \$1 --memory=\$2 \\" >> $FILE
echo "      --vcpus=\$3 --import \\" >> $FILE
echo "      --disk path=/vm/\${1}.qcow2,size=100,format=qcow2 \\" >> $FILE
echo "      --network network=default \\" >> $FILE
echo "      --graphics vnc,listen=0.0.0.0 --noautoconsole \\" >> $FILE
echo "      --os-type=linux --os-variant=rhel7" >> $FILE
echo "   sleep 2" >> $FILE
echo "}" >> $FILE
echo >> $FILE

echo "shutdown-server(){" >> $FILE
echo "   virsh shutdown \$1" >> $FILE
echo "}" >> $FILE
echo >> $FILE

echo "add-network(){" >> $FILE
echo "   mac=\`echo 52:54:\$(dd if=/dev/urandom count=1 2>/dev/null | md5sum \\" >> $FILE
echo "   | sed 's/^\(..\)\(..\)\(..\)\(..\).*$/\1:\2:\3:\4/')\`" >> $FILE
echo "   virsh attach-interface --domain \$1 --type network \\" >> $FILE
echo "      --source \$2 --model virtio \\" >> $FILE
echo "      --mac \$mac --config --live" >> $FILE
echo "}" >> $FILE
echo >> $FILE

echo "create-disk(){" >> $FILE
echo "   qemu-img create -f qcow2 /vm/\$1-\$2-\$4.qcow2 \$3" >> $FILE
echo "   chown qemu.qemu /vm/\$1-\$2-\$4.qcow2" >> $FILE
echo "}" >> $FILE
echo >> $FILE

echo "attach-disk(){" >> $FILE
DISKF="\$1-\$2-\$3.xml"
echo "  virsh attach-device --persistent \$1 $DISKF" >> $FILE
echo "rm -f $DISKF" >> $FILE
echo "}" >> $FILE
echo >> $FILE

echo "# ----------------------------------------------------------" >> $FILE
echo "#                 Create the virtual networks               " >> $FILE
echo "# ----------------------------------------------------------" >> $FILE
CK=`cat virsh-vm-create-config | grep ^NETWORK | awk '{print $1}' | head -1`
if [ x$CK != x ]; then
   cat virsh-vm-create-config | grep ^NETWORK > /tmp/rrb.tmp
   while read i; do
      NM=`echo $i | tr -s ' ' | cut -f2 '-d '`
      IP=`echo $i | tr -s ' ' | cut -f3 '-d '`
      NT=`echo $i | tr -s ' ' | cut -f2 -d' ' | cut -f2 -dN`
      MK=`echo $i | tr -s ' ' | cut -f4 '-d '`
      echo "<network>" > $NM.xml
      echo "  <name>$NM</name>" >> $NM.xml
      echo "  <bridge name=\"virbr${NT}\" stp=\"on\" delay=\"0\"/>" >> $NM.xml
      echo "  <ip address=\"${IP}\" netmask=\"$MK\" />" >> $NM.xml
      echo "</network>" >> $NM.xml
      echo "# $NM" >> $FILE
      echo "virsh net-define --file $NM.xml" >> $FILE
      echo "virsh net-start $NM" >> $FILE
      echo "rm -f $NM.xml" >> $FILE
      echo >> $FILE
   done < /tmp/rrb.tmp 
   echo >> $FILE
fi

echo "# ----------------------------------------------------------" >> $FILE
echo "#                 Create the virtual machines               " >> $FILE
echo "# ----------------------------------------------------------" >> $FILE
CK=`cat virsh-vm-create-config | grep ^SERVER | awk '{print $1}' | head -1`
if [ x$CK != x ]; then
   cat virsh-vm-create-config | grep ^SERVER > /tmp/rrb.tmp
   while read i; do
      NM=`echo $i | tr -s ' ' | cut -f2 '-d '`
      MEM=`echo $i | tr -s ' ' | cut -f3 '-d '`
      CPU=`echo $i | tr -s ' ' | cut -f4 '-d '`
      echo "# $NM" >> $FILE
      echo "create-server $NM $MEM $CPU" >> $FILE
      echo >> $FILE
   done < /tmp/rrb.tmp
   echo >> $FILE
fi

echo "# ----------------------------------------------------------" >> $FILE
echo "#                   Add additional networks                 " >> $FILE
echo "# ----------------------------------------------------------" >> $FILE
CK=`cat virsh-vm-create-config | grep ^NICS | awk '{print $1}' | head -1`
if [ x$CK != x ]; then
   cat virsh-vm-create-config | grep ^NICS > /tmp/rrb.tmp
   while read i; do
      NAM=`echo $i | tr -s ' ' | cut -f2 '-d '`
      NET=`echo $i | tr -s ' ' | cut -f3 '-d '`
      echo "# $NAM" >> $FILE
      echo "add-network $NAM $NET" >> $FILE
      echo >> $FILE
   done < /tmp/rrb.tmp
   echo >> $FILE
fi

echo "# ----------------------------------------------------------" >> $FILE
echo "#                    Add additional storage                 " >> $FILE
echo "# ----------------------------------------------------------" >> $FILE
CK=`cat virsh-vm-create-config | grep ^MKDISK | awk '{print $1}' | head -1`
if [ x$CK != x ]; then
   echo "mkdir -p /vm" >> $FILE

   cat virsh-vm-create-config | grep ^MKDISK > /tmp/rrb.tmp
   while read i; do
      SV=`echo $i | tr -s ' ' | cut -f2 '-d '`
      NM=`echo $i | tr -s ' ' | cut -f3 '-d '`
      SZ=`echo $i | tr -s ' ' | cut -f4 '-d '`
      DV=`echo $i | tr -s ' ' | cut -f5 '-d '`
      DISKF=$SV-$NM-$DV.xml
      echo "<disk type='file' device='disk'>" > $DISKF
      echo "    <driver name='qemu' type='qcow2' cache='none'/>" >> $DISKF
      echo "    <source file='/vm/$SV-$NM-$DV.qcow2' />" >> $DISKF
      echo "    <target dev='$DV' bus='virtio'/>" >> $DISKF
      echo "    <alias name='virtio-$SV-$NM-disk'/>" >> $DISKF
      echo "</disk>" >> $DISKF
      echo "create-disk $SV $NM $SZ $DV" >> $FILE
      echo "attach-disk $SV $NM $DV" >> $FILE
      echo >> $FILE
   done < /tmp/rrb.tmp
   echo >> $FILE
fi


#echo "# ----------------------------------------------------------" >> $FILE
#echo "#               Shutting down virtual machines              " >> $FILE
#echo "# ----------------------------------------------------------" >> $FILE
#CK=`cat virsh-vm-create-config | grep ^SERVER | awk '{print $1}' | head -1`
#if [ x$CK != x ]; then
#   cat virsh-vm-create-config | grep ^SERVER > /tmp/rrb.tmp
#   while read i; do
#      NM=`echo $i | tr -s ' ' | cut -f2 '-d '`
#      echo "# $NM" >> $FILE
#      echo "shutdown-server $NM" >> $FILE
#      echo >> $FILE
#   done < /tmp/rrb.tmp
#   echo >> $FILE
#fi


# ---------------------
#         Done
# ---------------------
chmod 755 $FILE
rm -f /tmp/rrb.tmp
echo 
echo "       Run $FILE"
echo
