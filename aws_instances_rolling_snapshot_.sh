#!/bin/bash
# Filename    : aws_instances_rolling_snapshot.sh
# Created by  : Dhiraj Thareja - 
# Version     : 1.2
# Company     : Awesome Actually 
# Description : Creates snapshots & add tags for a list of instances using instance ids. Also takes care of retention & deletion


RETENTION=15
DATE=`date +'%d-%m-%Y#%H:%M'`
LOG_FILE=/var/log/snapshots_$DATE.log #update the path for your choice
FROM="your@email.com" #provide some random email id as from address
TO="your@email.com" #Update the email id which you want to recive email alerts"
REGION="us-east-1"
SNAPSHOT_INFO='/var/log/snapshots-info.txt'


for i in `cat /opt/instance_ids`; do
ec2-describe-instances --region $REGION $i > /dev/zero
if [ $? != 0 ]
then
echo "Invalid instance ID($i). Please check the list" | tee -a $LOG_FILE
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
        DATE=`date +'%d-%m-%Y#%H:%M'`
        echo "Initiating snapshot for the volume $j" | tee -a $LOG_FILE
        SNAP_DESC="($i)${DATE}"
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
                echo " "
                echo "Deleting snapshots which are older than $RETENTION days"
                ec2-describe-snapshots --region $REGION --show-empty-fields --filter "volume-id=$j" | grep completed | awk '{print $2 " " $5}' > $SNAPSHOT_INFO
                while read SNAP_INFO
                do
                        DATE=`date +%Y-%m-%d`
                        SNAP_ID=`echo $SNAP_INFO | awk '{print $1}'`
                        SNAP_DATE=`echo $SNAP_INFO | awk '{print $2}' | awk -F"T" '{print $1}'`
                #Getting the no.of days difference between a snapshot and present day.
                        RETENTION_DIFF=`echo $(($(($(date -d "$DATE" "+%s") - $(date -d "$SNAP_DATE" "+%s"))) / 86400))`
                        echo "Retention diff for the snapshot $SNAP_ID is $RETENTION_DIFF"
                #Deleting the Snapshots which are older than the Retention Period
                        if [ $RETENTION -lt $RETENTION_DIFF ];
                        then
                                ec2-delete-snapshot $SNAP_ID --region $REGION | tee -a /tmp/snap_del
                                sleep 1
                                echo DELETING `cat /tmp/snap_del` Volume $VOL_ID | tee -a /var/logs/snap_deletion
                        fi
                done < $SNAPSHOT_INFO
                fi
        done
echo "****Script Execution Completed*****"
fi
done
