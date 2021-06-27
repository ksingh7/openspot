## Preamble
### What is crc
Red Hat CodeReady Containers (CRC) brings a minimal single node OpenShift 4 cluster to your local computer. This cluster provides a minimal OpenShift environment for development and testing purposes. [Read more](https://developers.redhat.com/products/codeready-containers/overview)

### What are Spot Instances
Amazon EC2 Spot Instances let you take advantage of unused EC2 capacity in the AWS datacenter. Spot Instances are available at up to a 90% discount compared to On-Demand prices. [Read more](https://aws.amazon.com/ec2/spot/)
### What is OpenSpot
OpenSpot [Open~~Shift on~~ Spot ~~Instance~~] is a tool that helps you deploy CRC on AWS Spot Instances in a fully automated & resilient manner.

##### Features of OpenSpot
- Select Region & AZ of your choice
- Sequentially provision all AWS resources required (as pre-requisite)
  - Key-pair
  - IAM role, policy, instance-policy
  - Security Group
  - user-data as Template
- Launch Spot Instnace
- Configure OS
  - Install all required packages
  - Get CRC/OC binaries
- EBS volume
  - Provision, Attach
  - Detect/Create/Mount filesystem
- CRC Setup
    - Dynamically set CPU/Memory 
    - Expand CRC root disk
- Configure Haproxy & make CRC instance available remotely
- Handle Spot Instance Termination
    - Provision new Spot Instnace 
    - Detect previous instance of CRC and resume that
- Cleanup
  - Destroy all AWS resources requested by openspot

## Setup
### Prerequisite
- AWS CLI must be configured on local machines
- AWS Admin Access & Secret Key
  - If you do not have Admin access, make sure your AWS ID has right capabilites to  provision resources like `IAM roles, policies,instance-policy,key-pair,security group,spot-instance,EBS`
- Test configuration of AWS CLI
```
aws ec2 describe-instances
```
- Get OpenSpot
```
git clone https://github.com/ksingh7/openspot.git
cd openspot/aws
```
## Setting up CRC
```
bash launch.sh -r ap-south-1 -a ap-south-1a -v false
```

### Configure Local Machine to use CRC running on Spot Instance
- Instructions for `MacOS`
```
brew install dnsmasq
mkdir -p /usr/local/etc/dnsmasq.d
touch /usr/local/etc/dnsmasq.d/crc.conf
EIP=$(aws ec2 describe-instances --filters "Name=instance-type,Values=c5n.metal"  --query "Reservations[*].Instances[*].PublicIpAddress" --output=text) ; 
echo "address=/apps-crc.testing/$EIP" > /usr/local/etc/dnsmasq.d/crc.conf ;
echo "address=/api.crc.testing/$EIP" >> /usr/local/etc/dnsmasq.d/crc.conf ;
sudo brew services restart dnsmasq ;
dig apps-crc.testing @127.0.0.1 ;
dig console-openshift-console.apps-crc.testing @127.0.0.1 ;

oc login -u developer -p developer https://api.crc.testing:6443
```
- Instructions for Linux `Fedora`
```
sudo dnf install dnsmasq

sudo tee /etc/NetworkManager/conf.d/use-dnsmasq.conf &>/dev/null <<EOF
[main]
dns=dnsmasq
EOF

EIP=$(aws ec2 describe-instances --filters "Name=instance-type,Values=c5n.metal"  --query "Reservations[*].Instances[*].PublicIpAddress" --output=text) ; 

sudo tee /etc/NetworkManager/dnsmasq.d/crc.conf &>/dev/null <<EOF
address=/apps-crc.testing/$EIP
address=/api.crc.testing/$EIP
EOF

sudo systemctl reload NetworkManager
```
- Connect to CRC OpenShift running on Spot Instance
```
Develoer Account
-----------------
oc login -u developer -p developer https://api.crc.testing:6443

# Open OpenShift Console in your local browser
# URL : https://console-openshift-console.apps-crc.testing
# username : developer
# password : developer

Kubeadmin Account
------------------
ssh fedora@$EIP crc console --credentials
# Get oc login command for kubeadmin user
```
## Additional Commands
- SSH into the instance
```
EIP=$(aws ec2 describe-instances --filters "Name=instance-type,Values=c5n.metal"  --query "Reservations[*].Instances[*].PublicIpAddress" --output=text) ; 
ssh fedora@$EIP
```
- Check progress of Instance setup 
```
ssh  fedora@$EIP cat /var/log/crc_status
ssh  fedora@$EIP tail -f /var/log/crc_setup.log
ssh  fedora@$EIP tail -f /var/log/cloud-init-output.log
ssh  fedora@$EIP wget https://gist.githubusercontent.com/ksingh7/7245aabdf6b9772ca8ef3c4df998d2fa/raw/1e63ba398edd229bf47e9ce99d2ad9d282e7ccc8/pull-secret.txt
```

### Todo
- add tags to instance
- destroy.sh , search by tag instead of instance type
