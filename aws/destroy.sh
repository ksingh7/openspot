#!/bin/bash
# bash destroy.sh -r ap-south-1 -a ap-south-1a -d false -v false
# Author: karan.singh731987@gmail.com , karan@redhat.com (Karan Singh)

main() {

if [ "$DEBUG" == "true"  ]; then
    echo "Enabling Verbose output ..."
    set -x
fi

if [ -n "$REGION" ]; then
    echo "Deleting CRC resources in Region : $REGION ..."
else
    REGION=$(aws configure get region)
    echo "No Region provided, Deleting CRC resources in Region : $REGION ..."
fi

if [ -n "$AZ_NAME" ]; then
    echo "Deleting CRC resources in AZ : $AZ_NAME ..."
else
    AZ_NAME="$REGION"c
    echo "No AZ provided, Deleting CRC resources inn AZ : $AZ_NAME ..."
fi
echo "Terminating up Spot Instance ..."
#To be removed later
#EC2_INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=instance-type,Values=c5n.metal" "Name=instance-state-code,Values=16" "Name=availability-zone,Values=$AZ_NAME" --query 'Reservations[*].Instances[*].{Instance:InstanceId}' --output text)
EC2_INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:environment,Values=crc" "Name=tag:availability-zone,Values=$AZ_NAME" "Name=instance-state-code,Values=16" "Name=availability-zone,Values=$AZ_NAME" --query 'Reservations[*].Instances[*].{Instance:InstanceId}' --output text)

SG_ID=$(aws ec2 describe-security-groups --filter "Name=group-name,Values=crc-sg" --query 'SecurityGroups[*].[GroupId]' --output text)
# Temporarily changing the security group of instance
aws ec2 modify-instance-attribute --instance-id $EC2_INSTANCE_ID --groups $SG_ID > /dev/null
aws ec2 terminate-instances --instance-ids $EC2_INSTANCE_ID > /dev/null

echo "Deleting Spot Request ..."
SPOT_REQUEST_ID=$(aws ec2 describe-spot-instance-requests  --filters "Name=state,Values=open,active" "Name=tag:environment,Values=crc" "Name=availability-zone-group,Values=$REGION" --query "SpotInstanceRequests[*].[SpotInstanceRequestId]" --output text) 
aws ec2 cancel-spot-instance-requests --spot-instance-request-ids $SPOT_REQUEST_ID  > /dev/null

EBS_VOLUME_ID=$(aws  ec2 describe-volumes --filters "Name=tag:environment,Values=crc" "Name=availability-zone,Values=$AZ_NAME" --query "Volumes[*].{ID:VolumeId}" --output text)

echo "Detaching volume"
aws ec2 detach-volume --volume-id $EBS_VOLUME_ID > /dev/null

if [[ "$DELETE_EBS" == "true" ]]; then
    echo "Destroying EBS Volume ..."
    aws ec2 delete-volume --volume-id $EBS_VOLUME_ID > /dev/null
fi

echo "Removing Role from Instance Profile ... [Done]"
aws iam remove-role-from-instance-profile --instance-profile-name crc-Instance-Profile --role-name crc-ec2-volume-role > /dev/null

echo "Deleting Role Policy ... [Done]"
aws iam delete-role-policy --role-name crc-ec2-volume-role --policy-name crc-ec20-volume-policy > /dev/null

echo "Deleting Role ... [Done]"
aws iam delete-role --role-name crc-ec2-volume-role > /dev/null

echo "Deleting Instance Profile ... [Done]"
aws iam delete-instance-profile --instance-profile-name crc-Instance-Profile > /dev/null

echo "Deleting Key Pair ... [Done]"
aws --region $REGION ec2 delete-key-pair --key-name crc-key-pair

echo "Deleting Security Group... [Done]"
aws ec2 delete-security-group --group-name crc-sg > /dev/null 2>&1

}

usage() {
cat << EOT
    usage $0 -r "AWS_Region_Name" -a "AWS_AZ_NAME" -d "true or false" -v "true or false"
    OPTIONS
    -r "AWS Region Name : Optional, if not provided, will use AWS CLI default value"
    -a "AWS Availablity Zone Name : Optional, if not provided, will use AWS CLI default value"
    -d "Delete EBS Volume (true or false), default = false"
    -v "Optional, used for verbose output (true or false), default = false"
    -h "Show help menu"
EOT
}

while getopts r:a:d:v:h option; do
    case $option in
        r)
            REGION="$OPTARG"
            ;;
        a)
            AZ_NAME="$OPTARG"
            ;;
        d)
            DELETE_EBS="$OPTARG"
            ;;
        v)
            DEBUG="$OPTARG"
            ;;
        \?)
            echo "wrong option."
            usage
            exit 1
            ;;
        h)
            usage
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

main