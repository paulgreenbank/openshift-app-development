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

# Create master Jenkins build
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi -n ${GUID}-jenkins

# Adjust readiness probe for Jenkins
oc set probe dc jenkins --readiness --initial-delay-seconds=300 -n ${GUID}-jenkins

# Setup Jenkins Mavin ImageStream for Jenkins slave builds
oc new-build --name=jenkins-slave-maven-skopeo-centos7 -D $'FROM openshift/jenkins-slave-maven-centos7:v3.9\nUSER root\nRUN yum -y install skopeo apb && yum clean all\nUSER 1001' -n ${GUID}-jenkins

# Sleep 30 seconds for Image Stream to be created
sleep 30

# Tag Jenkins slave ImageStream to latest
oc tag jenkins-slave-maven-skopeo-centos7 jenkins-slave-maven-skopeo-centos7:latest -n ${GUID}-jenkins

# Wait for Jenkins to fully deploy and become ready
while : ; do
  echo "Checking if Jenkins pod is Ready..."
  oc get pod -n ${GUID}-jenkins | grep -v "deploy\|build" | grep -q "1/1"
  [[ "$?" == "1" ]] || break
  echo "... not quite yet. Sleeping 20 seconds."
  sleep 20
done

# Add version 3.9 tag to Jenkins slave ImageStream
oc tag jenkins-slave-maven-skopeo-centos7:latest jenkins-slave-maven-skopeo-centos7:v3.9 -n ${GUID}-jenkins

# Label Jenkins slave ImageStream for Jenkins to use for slave builds
oc label imagestream jenkins-slave-maven-skopeo-centos7 role=jenkins-slave -n ${GUID}-jenkins

# Create the three pipeline build configs
sed "s/GUID_VARIABLE/${GUID}/g;s/CLUSTER_VARIABLE/${CLUSTER}/g" ./Infrastructure/templates/mlbparks-pipeline_template_build.yaml | oc process -f - | oc create -f - -n ${GUID}-jenkins
sed "s/GUID_VARIABLE/${GUID}/g;s/CLUSTER_VARIABLE/${CLUSTER}/g" ./Infrastructure/templates/nationalparks-pipeline_template_build.yaml | oc process -f - | oc create -f - -n ${GUID}-jenkins
sed "s/GUID_VARIABLE/${GUID}/g;s/CLUSTER_VARIABLE/${CLUSTER}/g" ./Infrastructure/templates/parksmap-pipeline_template_build.yaml | oc process -f - | oc create -f - -n ${GUID}-jenkins
