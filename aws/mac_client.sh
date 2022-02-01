#!/bin/bash
brew install dnsmasq ;
mkdir -p /usr/local/etc/dnsmasq.d ;
rm /usr/local/etc/dnsmasq.d/crc.conf ;
EIP=$(aws ec2 describe-instances --filters "Name=instance-type,Values=c5n.metal"  --query "Reservations[*].Instances[*].PublicIpAddress" --output=text) ;
echo "address=/apps-crc.testing/$EIP" > /usr/local/etc/dnsmasq.d/crc.conf ;
echo "address=/api.crc.testing/$EIP" >> /usr/local/etc/dnsmasq.d/crc.conf ;
sudo brew services restart dnsmasq ;
dig apps-crc.testing @127.0.0.1 ;
dig console-openshift-console.apps-crc.testing @127.0.0.1 ;
