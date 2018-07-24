#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Change to Nexus Project
oc project ${GUID}-jenkins

# Create master Jenkins build
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi

# Setup Jenkins Mavin ImageStream for Jenkins slave builds
oc new-build --name=jenkins-slave-maven-skopeo-centos7 -D $'FROM openshift/jenkins-slave-maven-centos7:v3.9\nUSER root\nRUN yum -y install skopeo apb && yum clean all\nUSER 1001'

# Sleep 30 seconds for Image Stream to be created
sleep 30

# Tag Jenkins slave ImageStream to version 3.9
oc tag jenkins-slave-maven-skopeo-centos7:latest jenkins-slave-maven-skopeo-centos7:v3.9

# Label Jenkins slave ImageStream for Jenkins to use for slave builds
oc label imagestream jenkins-slave-maven-skopeo-centos7 role=jenkins-slave

# Create the three pipeline build configs
sed "s/GUID_VARIABLE/${GUID}/g;s/CLUSTER_VARIABLE/${CLUSTER}/g" ../templates/mlbparks-pipeline_template_build.yaml | oc process -f - | oc create -f -
sed "s/GUID_VARIABLE/${GUID}/g;s/CLUSTER_VARIABLE/${CLUSTER}/g" ../templates/nationalparks-pipeline_template_build.yaml | oc process -f - | oc create -f -
sed "s/GUID_VARIABLE/${GUID}/g;s/CLUSTER_VARIABLE/${CLUSTER}/g" ../templates/parksmap-pipeline_template_build.yaml | oc process -f - | oc create -f -
