#!/bin/bash

echo "Create VPC"
VPCID=`aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output text | awk '{print $7}' | head -n1`
echo "Create Private subnet"
SBNETID1=`aws ec2 create-subnet --vpc-id $VPCID --cidr-block 10.0.1.0/24 --output text | awk '{print $9}'`
echo "Create Public subnet"
SBNETID0=`aws ec2 create-subnet --vpc-id $VPCID --cidr-block 10.0.0.0/24 --output text | awk '{print $9}'`
echo "Create Gateway"
GWID=`aws ec2 create-internet-gateway --output text | awk '{print $2}'`
echo "Attach GW"
aws ec2 attach-internet-gateway --vpc-id $VPCID --internet-gateway-id $GWID
echo "Create Route table public"
RTB=`aws ec2 create-route-table --vpc-id  $VPCID --output text | grep $VPCID | awk '{print $2}'`
echo "Create route for public"
aws ec2 create-route --route-table-id $RTB --destination-cidr-block 0.0.0.0/0 --gateway-id $GWID
echo "Assoc route table"
aws ec2 associate-route-table  --subnet-id $SBNETID0 --route-table-id $RTB
echo "Create ssh key"
aws ec2 create-key-pair --key-name AwsCliKeyPaircli4 --query 'KeyMaterial' --output text > AwsCliKeyPaircli4.pem
echo "Permission on key"
chmod 400 AwsCliKeyPaircli4.pem
echo "Create Security group"
SGID=`aws ec2 create-security-group --group-name SSHAccess --description "Security group for SSH access" --vpc-id $VPCID --output text`
echo "Create inbound rules"
aws ec2 authorize-security-group-ingress --group-id $SGID --protocol tcp --port 22 --cidr 0.0.0.0/0
echo "Run NAT instance"
IFACEID=`aws ec2 run-instances --image-id ami-184dc970 --count 1 --instance-type t2.micro --key-name AwsCliKeyPaircli4 --security-group-ids $SGID --subnet-id $SBNETID0 --associate-public-ip-address --output text | grep NETWORKINTERFACES | awk '{print $3}'`
echo "Change source for NAT"
aws ec2 modify-network-interface-attribute --network-interface-id $IFACEID --no-source-dest-check
echo "Create route table"
RTBPRIVATE=`aws ec2 create-route-table --vpc-id  $VPCID --output text | grep $VPCID | awk '{print $2}'`
echo "Preparations .."
sleep 15
NATID=`aws ec2 describe-instances --query 'Reservations[*].Instances[*].[Placement.AvailabilityZone, State.Name, InstanceId]' --output text  | grep running | head -n1 | awk '{print $3}'`
echo "Create route"
aws ec2 create-route --route-table-id $RTBPRIVATE --destination-cidr-block 0.0.0.0/0 --instance-id $NATID
echo "Assoc route table"
aws ec2 associate-route-table  --subnet-id $SBNETID1 --route-table-id $RTBPRIVATE
echo "Run ec2 instance"
aws ec2 run-instances --image-id ami-aa2ea6d0 --count 1 --instance-type t2.micro --key-name AwsCliKeyPaircli4 --security-group-ids $SGID --subnet-id $SBNETID1
echo "Change SG "
aws ec2 authorize-security-group-ingress --group-id $SGID --protocol all --source-group $SGID
