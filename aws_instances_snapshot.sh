#!/bin/bash
# Filename    : aws_instances_snapshot.sh
# Created by  : Dhiraj Thareja - 
# Version     : 1.1
# Company     : AwesomeActually.com
# Description : Creates snapshots & add tags for a list of instances using instance ids. 



DATE=`date +'%m-%d-%Y-%H%M%S'`
LOG_FILE=/var/log/snapshots_$DATE.log #update the path for your choice
FROM="your@email.com" #provide some random email id as from address
TO="your@email.com" #Update the email id which you want to recive email alerts"
REGION="us-east-1"
INSTANCES=/opt/instances

for i in `cat $INSTANCES`; do
ec2-describe-instances --region $REGION $i > /dev/zero
if [ $? != 0 ]
then
echo "Invalid instance ID. Please check the list" | tee -a $LOG_FILE
echo "Jump to next instance" | tee -a $LOG_FILE
echo "#################"
sleep 2
else
echo "Instance ID $i"
echo "Describing the volumes attached to instance $i" | tee -a $LOG_FILE
VOLUME=`ec2-describe-volumes | grep $i | awk '{ print $2 }'`
echo $VOLUME | tee -a $LOG_FILE
sleep 1
echo "Describing the tags for the instance $i" | tee -a $LOG_FILE
ec2-describe-tags --region $REGION  --filter "resource-id=$i" | tee -a $LOG_FILE
        for j in `ec2-describe-volumes | grep $i | awk '{ print $2 }'` ; do
        DATE=`date +'%m-%d-%Y#%H:%M:%S'`
        echo "Initiating snapshot for the volume $j" | tee -a $LOG_FILE
        SNAP_DESC="($i)_${DATE}"
        echo "Snap description $SNAP_DESC" | tee -a $LOG_FILE
        ec2-create-snapshot --description $SNAP_DESC --region $REGION $j
                if [ $? != 0 ]
                then
                echo "Snaphot creation failed for volume $j" | tee -a $LOG_FILE
                # mail -s "Snaphot creation failed for volume $j" -r $FROM $TO
                else
                echo "Snapshot is created. Will be available in few mins." | tee -a $LOG_FILE
                echo     ".............."
                sleep 5
                        for tag in Name Owner StackName CustomerName
                        do
                        echo " " | tee -a $LOG_FILE
                        echo "####Update the tag "#$tag#"####" | tee -a $LOG_FILE
                        ec2-describe-tags --region $REGION  --filter "resource-id=$i"  --filter "key=$tag" |  grep -o "$tag.*" | cut -f 2- | while read y
                                do
                                echo "Describing snap id" | tee -a $LOG_FILE
                                SNAP_ID=`ec2-describe-snapshots | grep $j | grep "$SNAP_DESC" | awk '{ print $2 }'`
                                echo "Snap ID: $SNAP_ID" | tee -a $LOG_FILE
                                sleep 2
                                ec2-create-tags --region $REGION $SNAP_ID --tag  $tag="$y"
                                if [ $? != 0 ]
                                then
                                echo "Updating tag($tag) failed for the snaphsot $SNAP_ID" | tee -a $LOG_FILE
#Uncomment below mail command if you want to recive alerts. You will need to have Postfix and mailx installed in your server
#                               mail -s "Updating tag($tag) failed for the snaphsot $SNAP_ID" -r $FROM $TO
                                fi
                                echo "Updated the tag($tag) for snapshot $SNAP_ID" | tee -a $LOG_FILE
                                done
                        done
                echo "###################################" | tee -a $LOG_FILE
                echo "snapshot is created for volume $j and updated the tags" | tee -a $LOG_FILE
                echo "###################################" | tee -a $LOG_FILE
                fi
        done
echo "****Script Execution Completed*****"
fi
done
