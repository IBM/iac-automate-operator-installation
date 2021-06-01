# !/bin/sh
# set -x

# CLIs required:
# * oc

# Before running this script:
# * login to your OpenShift Cluster
# * Use this command to get operator name - oc get packagemanifests -n openshift-marketplace


# Set Variables
PROJECT_NAME=test ##it will be asked during script execution
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

echo "\n**Verifying if the operator can be installed in 'SingleNamespace' mode..."
SUPPORT=`cat $FILE | grep -i 'SingleNamespace' -B 1 |grep -i 'supported' | cut -d ':' -f 2 | xargs`

if [ "$SUPPORT" = "true" ]; then
    echo "'$OPERATOR_NAME' operator supports installation in 'SingleNamespace' mode"
else
    echo "'$OPERATOR_NAME' operator does not support installation in 'SingleNamespace' mode. Hence exiting.\n"
    exit 0
fi

echo "\n**Provide a namespace/project name where you want to install the operator: "
read PROJECT_NAME

echo "\n**Checking if project exists already.."
oc get projects | grep $PROJECT_NAME

if [ $? == 1 ] 
then
    echo "\nProject does not exist. Creating new project $PROJECT_NAME"
    oc new-project $PROJECT_NAME
else
    echo "\nProject exists."
    echo "\n**Switching to the required project..\n"
    oc project $PROJECT_NAME
fi

echo "\n**Checking if operator group exists..\n"
OP_GRP_EXISTS=`oc get og | grep -i -E '^Name\b'| cut -d ' ' -f 1 |xargs`

if [ $OP_GRP_EXISTS ] 
then 
    echo "Operator Group exists, details are:\n"
    oc get og
else
    echo "\n**Creating operator group yaml..."
    OPERATOR_GROUP_CONFIG=operator-group.yaml
    cp operator-group.yaml.template $OPERATOR_GROUP_CONFIG

    ## replace operator-group-name
    operator_group_name=olm-operator
    echo "operator group name = olm-operator"
    sed -i "" "s/<operator_group_name>/$operator_group_name/g" $OPERATOR_GROUP_CONFIG

    ## replace project-name
    echo "namespace name = $PROJECT_NAME"
    sed -i "" "s/<namespace_name>/$PROJECT_NAME/g" $OPERATOR_GROUP_CONFIG

    echo "\nOperator group configuration has been created."
    echo "\n**$OPERATOR_GROUP_CONFIG:"
    cat $OPERATOR_GROUP_CONFIG

    echo "\n\n**Creating operator group in '$PROJECT_NAME' namespace:"
    oc apply -f $OPERATOR_GROUP_CONFIG

    sleep 5
    echo "\n**oc get og\n"
    oc get og
    echo "\n'$operator_group_name' has been created successfully."
fi

echo "\n**Creating Subscription object..."
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
echo "namespace name = $PROJECT_NAME"
sed -i "" "s/<namespace_name>/$PROJECT_NAME/g" $SUBSCRIPTION_FILE

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