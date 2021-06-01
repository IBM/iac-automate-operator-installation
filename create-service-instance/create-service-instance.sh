# !/bin/sh
# set -x

# CLIs required
# * oc
# * odo

# Before running this script:
# * login to your OpenShift Cluster
# * Get subscribed operator name (if not known already) using the command - 'odo catalog list services'


# Set Variables
SUBSCRIBED_OPERATOR_NAME=$1
PROJECT_NAME=$2

# Checking if required arguments are provided
if [ $# != 2 ]
  then
    echo "\nRequired arguments are not provided."
    echo "\n**usage: ./create-service-instance.sh <SUBSCRIBED_OPERATOR_NAME> <PROJECT_NAME>\n"
    exit 0
fi

# Checking if user is logged-in to OpenShift Cluster
echo "\noc whoami"
oc whoami

if [ $? == 1 ] 
then
    echo "\nYou are not logged-in. Login to OpenShift Cluster (oc login).\n"
    exit 0
else
    echo "\nAlready logged-in to OpenShift Cluster."
fi

echo "\n**Verifying if namespace '$PROJECT_NAME' exists already"
oc get projects | grep $PROJECT_NAME

if [ $? == 0 ]
then 
    echo "\nNamespace '$PROJECT_NAME' exists already. Switching to the required namespace..\n"
    oc project $PROJECT_NAME
else
    echo "Namespace '$PROJECT_NAME' does not exist."
    echo "\n**Creating new namespace '$PROJECT_NAME'.."
    oc new-project $PROJECT_NAME
    echo "\n**Waiting (60 seconds) for the new project to setup completely.."
    sleep 60
fi

echo "\n**Verifying operator availability and Finding available CRDs of the operator '$SUBSCRIBED_OPERATOR_NAME'.."
odo catalog list services | grep $SUBSCRIBED_OPERATOR_NAME

if [ $? == 1 ] 
then
    echo "\nOperator '$SUBSCRIBED_OPERATOR_NAME' is not available in your namespace. Please install the operator before creating its instance."
    exit 0
fi

CRDs=`odo catalog list services | grep $SUBSCRIBED_OPERATOR_NAME | awk '{print $2}'`

# considering first CRD to install
CRD=`echo $CRDs | awk -F',' '{print $1}'`
echo "\n**Considering first CRD to install - $CRD"

# ask user to provide its choice
echo "\n**Do you want to modify the default configuration of CRD (yes/no):"
read choice

# create service instance using odo CLI
if [ $choice == "yes" ]
then
    CONFIG_NAME=crd.yaml
    odo service create $SUBSCRIBED_OPERATOR_NAME/$CRD --dry-run > $CONFIG_NAME
    echo "\n**CRD configuration - '$CONFIG_NAME' has been created." 
    echo "Please open '$CONFIG_NAME' in another terminal and modify as per your requirement."
    echo "\nAfter completing the required changes, press any key to proceed:\n"
    read input
    echo "\n**Creating service instance with modified configuration.."
    odo service create --from-file $CONFIG_NAME
else
    echo "\n**Creating service instance with default configuration - $SUBSCRIBED_OPERATOR_NAME/$CRD\n"
    odo service create $SUBSCRIBED_OPERATOR_NAME/$CRD
fi

# check the status of service instance 
SERVICE_INSTANCE_STATUS=`odo service list  | grep $CRD`
if [ $? == 0 ] 
then
    echo '\nService instance has been created successfully.\n'
else
    echo '\nService instance creation failed.'
    exit 0
fi

DEPLOYMENT_NAME=`odo service list  | grep $CRD | awk '{print $1}' | awk -F'/' '{print $2}'`

# check the status of pod
echo "\n**Checking the pod status.."
oc get pods | grep $DEPLOYMENT_NAME

POD_STATUS=`oc get pods | grep $DEPLOYMENT_NAME | awk '{print $3}'`
echo "\nPod is $POD_STATUS"

while [ "$POD_STATUS" != "Running" ]; do
    echo "Wating for pod status to be in 'Running' state. Current status is $POD_STATUS"
    sleep 5;
    if [ "$POD_STATUS" == "Error" ]; then
        echo "There is an error in pod running. Please check logs."
        exit 0
    fi
    POD_STATUS=`oc get pods | grep $DEPLOYMENT_NAME | awk '{print $3}'`
done

# check the status of service
echo "\n**Checking the service status.."
oc get svc | grep $DEPLOYMENT_NAME

# get the route
echo "\n**Getting the route.."
oc get routes | grep $DEPLOYMENT_NAME

ROUTE=`oc get routes | grep $DEPLOYMENT_NAME | awk '{print $2}'`

echo "\nYou are all set to access the service instance. Access the route at 'http://$ROUTE'.\n"
