# !/bin/sh
# set -x

# CLIs required:
# * oc

# Before running this script:
# * login to your OpenShift Cluster
# * Use this command to get operator name - oc get packagemanifests -n openshift-marketplace

# Set Variables
OPERATOR_NAME=$1 
FILE=operator-desc.yaml 

# Checking if user is logged-in to OpenShift Cluster
echo "\noc whoami"
oc whoami

if [ $? == 1 ] 
then
    echo '\nYou are not logged-in. Login to OpenShift Cluster (oc login)\n'
    exit 0
fi

OPERATOR_INFO=`oc get packagemanifests -n openshift-marketplace|grep $OPERATOR_NAME`
echo "\n**Operator Info:\n $OPERATOR_INFO"

if [ -f "$FILE" ]; then
    rm -f $FILE
fi

echo "\n**Fetching the operator details..."
oc describe packagemanifests $OPERATOR_NAME -n openshift-marketplace > $FILE
echo "$FILE created"

echo "\n**Verifying if the operator can be installed in 'AllNamespaces' mode..."
SUPPORT=`cat $FILE | grep -i 'allnamespaces' -B 1 |grep -i 'supported' | cut -d ':' -f 2 | xargs`

if [ "$SUPPORT" = "true" ]; then
    echo "'$OPERATOR_NAME' operator supports installation in 'AllNamespaces' mode"
else
    echo "'$OPERATOR_NAME' operator does not support installation in 'AllNamespaces' mode. Hence exiting.\n"
    exit 0
fi

echo "\n**Creating Subscription object YAML..."
SUBSCRIPTION_FILE=subscription.yaml
cp subscription.yaml.template $SUBSCRIPTION_FILE

## replace operator-name
operator_name=`cat $FILE | grep -E '^Name\b' | cut -d ':' -f 2 | xargs`
echo "operator name = $operator_name"
sed -i "" "s/<operator_name>/$operator_name/g" $SUBSCRIPTION_FILE

## replace source-name
source_name=`cat $FILE | grep 'Catalog Source:' | cut -d ':' -f 2 | xargs`
echo "source name = $source_name"
sed -i "" "s/<source-name>/$source_name/g" $SUBSCRIPTION_FILE

## replace channel-name
channel_name=`cat $FILE | grep 'Default Channel:' | cut -d ':' -f 2 | xargs`
echo "channel name = $channel_name"
sed -i "" "s/<channel-name>/$channel_name/g" $SUBSCRIPTION_FILE

## replace namespace-name
echo "namespace name = openshift-operators"
sed -i "" "s/<namespace_name>/openshift-operators/g" $SUBSCRIPTION_FILE

echo "\nSubscription object(yaml) is created."
echo "\n**$SUBSCRIPTION_FILE: \n"
cat $SUBSCRIPTION_FILE

echo "\n\n**Creating subscription of operator $OPERATOR_NAME: "
oc apply -f $SUBSCRIPTION_FILE

sleep 30
echo "\nSubscription has been created."

csv_name=`cat $FILE | grep 'Current CSV:' | cut -d ':' -f 2 | xargs`
echo "\nSubscribed operator name = $csv_name"
echo "Use this subscribed operator name to create service instance in a project.\n"