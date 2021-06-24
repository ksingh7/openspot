```
bash launch.sh
ssh -i "ksingh-mumbai.pem" fedora@ec2-13-235-62-230.ap-south-1.compute.amazonaws.com cat /var/log/crc_status
ssh -i "ksingh-mumbai.pem" fedora@ec2-13-233-149-189.ap-south-1.compute.amazonaws.com tail -f /var/log/crc_setup.log
ssh -i "ksingh-mumbai.pem" fedora@ec2-13-235-62-230.ap-south-1.compute.amazonaws.com tail -f /var/log/cloud-init-output.log
ssh -i "ksingh-mumbai.pem" fedora@ec2-13-235-62-230.ap-south-1.compute.amazonaws.com
wget https://gist.githubusercontent.com/ksingh7/7245aabdf6b9772ca8ef3c4df998d2fa/raw/1e63ba398edd229bf47e9ce99d2ad9d282e7ccc8/pull-secret.txt

alias crcssh='ssh -i ~/.crc/machines/crc/id_ecdsa core@"$(crc ip)"'
crc stop

- wget post_install.sh on to instance and execute once instnace is ready
- add tags to instance
- destroy.sh , search by tag instead of instance type
- parameterize delete.sh , full delete , or delete just instance
- add getops to bash script (launch and delete

```

- SSH into the instance
```
EIP=$(aws ec2 describe-instances --filters "Name=instance-type,Values=c5n.metal" "Name=availability-zone,Values=ap-south-1a" --query "Reservations[*].Instances[*].PublicIpAddress" --output=text) ; 
ssh fedora@$EIP
```

- Configure Local machine to use CRC on Spot
```
sudo rm /usr/local/etc/dnsmasq.d/crc.conf ;
EIP=$(aws ec2 describe-instances --filters "Name=instance-type,Values=c5n.metal" "Name=availability-zone,Values=ap-south-1a" --query "Reservations[*].Instances[*].PublicIpAddress" --output=text) ; 
echo "address=/apps-crc.testing/$EIP" >> /usr/local/etc/dnsmasq.d/crc.conf ;
echo "address=/api.crc.testing/$EIP" >> /usr/local/etc/dnsmasq.d/crc.conf ;
sudo brew services restart dnsmasq ;
dig apps-crc.testing @127.0.0.1 ;
dig console-openshift-console.apps-crc.testing @127.0.0.1 ;

```
