#!/bin/bash -x
set -x 
rm  /var/log/crc* > /dev/null 2>&1
rm -rf aws* > /dev/null 2>&1
touch  /var/log/crc_setup.log
chown fedora:fedora /var/log/crc_setup.log 

touch  /var/log/crc_status
chown fedora:fedora /var/log/crc_status 
echo "progressing" >> /var/log/crc_status 2>&1 

echo "Installing required packages ... [Done]"  >> /var/log/crc_setup.log 2>&1
dnf update -y > /dev/null 2>&1
dnf install -y NetworkManager wget git haproxy vim unzip bc libvirt libvirt-daemon-kvm qemu-kvm libguestfs-tools guestfs-tools  /usr/sbin/semanage > /dev/null 2>&1

echo "Setting up AWS Cli... [Done]"  >> /var/log/crc_setup.log 2>&1
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/awscliv2.zip" > /dev/null 2>&1
unzip /awscliv2.zip > /dev/null 2>&1
./aws/install > /dev/null 2>&1

#EBS_VOLUME_ID=$(aws --region=REGION ec2 describe-volumes --filters "Name=tag:environment,Values=crc" --query "Volumes[*].{ID:VolumeId}" --output text)

EBS_VOLUME_ID=$(aws  --region=REGION ec2 describe-volumes --filters "Name=tag:environment,Values=crc" "Name=availability-zone,Values=AZ_NAME" --query "Volumes[*].{ID:VolumeId}" --output text)

#EBS_VOLUME_AZ=$(aws --region=REGION ec2 describe-volumes --filters "Name=tag:environment,Values=crc" --query "Volumes[*].{ID:AvailabilityZone}" --output text)

if [ -n "$EBS_VOLUME_ID" ]; then
    echo "Using existing EBS Volume ..."  >> /var/log/crc_setup.log 2>&1
else
    echo "Creating EBS Volume for CRC ..."  >> /var/log/crc_setup.log 2>&1
    aws --region=REGION ec2 create-volume --volume-type gp2 --size 200 --availability-zone AZ_NAME --tag-specifications 'ResourceType=volume,Tags=[{Key="environment",Value="crc"}]'   >> /var/log/crc_setup.log 2>&1
fi
sleep 10

EC2_INSTANCE_ID=$(aws --region=REGION ec2 describe-instances --filters "Name=instance-type,Values=INSTANCE_TYPE" "Name=instance-state-code,Values=16" --query 'Reservations[*].Instances[*].{Instance:InstanceId}' --output text)
echo "Instance ID :" $EC2_INSTANCE_ID  >> /var/log/crc_setup.log 2>&1

EBS_VOLUME_ID=$(aws  --region=REGION ec2 describe-volumes --filters "Name=tag:environment,Values=crc" "Name=availability-zone,Values=AZ_NAME" --query "Volumes[*].{ID:VolumeId}" --output text)
echo "EBS Volume ID :"$EBS_VOLUME_ID  >> /var/log/crc_setup.log 2>&1

echo "Attaching EBS Volume to CRC Spot Instance ..." >> /var/log/crc_setup.log 2>&1
aws --region=REGION ec2 attach-volume --volume-id $EBS_VOLUME_ID --instance-id $EC2_INSTANCE_ID --device /dev/xvdb >> /var/log/crc_setup.log 2>&1

sleep 10

if [ $(blkid /dev/nvme1n1 | awk '{print $4}' | cut -d '"' -f 2) = "xfs" ]; then
	echo "XFS Filesystem found, just mounting volume ..." >> /var/log/crc_setup.log 2>&1
	echo "/dev/nvme1n1 /home xfs defaults 0 0" >> /etc/fstab
    mount -a
    sudo -u fedora sudo cp /home/fedora/crc /usr/bin/crc
    sudo -u fedora sudo cp /home/fedora/oc /usr/bin/oc
else
	echo "No Filesystem found, creating XFS filesystem ..." >> /var/log/crc_setup.log 2>&1
        mkfs.xfs /dev/nvme1n1  >> /var/log/crc_setup.log 2>&1
        mount /dev/nvme1n1 /mnt
        cp -rp /home/fedora /mnt/
        echo "/dev/nvme1n1 /home xfs defaults 0 0" >> /etc/fstab
        umount /mnt
        mount -a  >> /var/log/crc_setup.log 2>&1
        sudo -u fedora echo "Downloading latest version of CRC ..." >> /var/log/crc_setup.log 2>&1
        sudo -u fedora wget https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz -q --show-progres -O /home/fedora/crc-linux-amd64.tar.xz

        sudo -u fedora echo "Downloading latest version of OC client ..." >> /var/log/crc_setup.log 2>&1
        sudo -u fedora wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz -q --show-progress -O /home/fedora/openshift-client-linux.tar.gz

        sudo -u fedora echo "Extracting CRC binary ..." >> /var/log/crc_setup.log 2>&1
        sudo -u fedora tar xvf /home/fedora/crc-linux-amd64.tar.xz -C /home/fedora  >> /var/log/crc_setup.log 2>&1 
        sudo -u fedora sudo cp /home/fedora/crc-linux-*-amd64/crc /usr/bin/crc
        sudo -u fedora sudo cp /home/fedora/crc-linux-*-amd64/crc /home/fedora/crc

        sudo -u fedora echo "Extracting OC binary ..." >> /var/log/crc_setup.log 2>&1
        sudo -u fedora tar xvf /home/fedora/openshift-client-linux.tar.gz -C /home/fedora  >> /var/log/crc_setup.log 2>&1
        sudo -u fedora sudo cp /home/fedora/oc /usr/bin/oc

        sudo -u fedora rm -rf /home/fedora/crc-linux* > /dev/null 2>&1
        sudo -u fedora rm /home/fedora/openshift-client*  > /dev/null 2>&1

        sudo -u fedora echo "Cleaning up leftovers ... [Done]" >> /var/log/crc_setup.log 2>&1
fi

echo "Calculating CPU cores for  CRC usage ..."  >> /var/log/crc_setup.log 2>&1
CPU_TEMP=$(echo "$(lscpu | grep -v "NUMA" | grep -i "CPU(s):" | awk '{print $2}')*0.90" | bc)
CPU=$(printf '%.0f\n' $CPU_TEMP)

echo "Calculating Memory for CRC usage ..."  >> /var/log/crc_setup.log 2>&1
MEMORY_TEMP=$(echo "$(free -m | grep -i mem | awk '{print $2}') * 0.90" | bc)
MEMORY=$(printf '%.0f\n' $MEMORY_TEMP)

sudo -u fedora echo "Setting up CRC ..." >> /var/log/crc_setup.log 2>&1
sudo -u fedora crc config set cpus $CPU >> /var/log/crc_setup.log 2>&1
sudo -u fedora crc config set memory $MEMORY >> /var/log/crc_setup.log 2>&1
sudo -u fedora crc config set enable-cluster-monitoring true >> /var/log/crc_setup.log 2>&1
sudo -u fedora crc config set consent-telemetry yes >> /var/log/crc_setup.log 2>&1
sudo -u fedora crc config view >> /var/log/crc_setup.log 2>&1

sudo -u fedora echo "===== CRC Setup Completed ====" >> /var/log/crc_setup.log 2>&1
sudo -u wget https://raw.githubusercontent.com/ksingh7/openspot/main/aws/assets/post_install.sh -O /home/fedora/post_install.sh
sudo -u chmod +x /home/fedora/post_install.sh
sudo -u fedora echo "===== You can now SSH into the instance for post installation setup ====" >> /var/log/crc_setup.log 2>&1
sudo -u fedora echo "===== Post Installation scrip file location : /home/fedora/post_install.sh ====" >> /var/log/crc_setup.log 2>&1
echo "completed" > /var/log/crc_status 2>&1 