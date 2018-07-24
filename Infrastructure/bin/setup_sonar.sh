#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
GENERATED_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
GENERATED_DATABASE=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 8 | head -n 1)
echo "Setting up Sonarqube in project $GUID-sonarqube"

# Change to Nexus Project
oc project ${GUID}-sonarqube

# Create secret for database password from /dev/urandom
oc create secret generic sonar-secrets --from-literal DATABASE_PASSWORD=${GENERATED_PASSWORD} --from-literal DATABASE_USER=sonar --from-literal DATABASE_NAME=${GENERATED_DATABASE} --from-literal JDBC_URL=jdbc:postgresql://postgresql/${GENERATED_DATABASE}

# Process template and create database for environment
sed "s/GUID/${GUID}/g" ../templates/sonarqube_postgres_template_build.yaml | oc process -f - | oc create -f -

# Wait for Nexus to fully deploy and become ready
while : ; do
  echo "Checking if Sonarqube database is Ready..."
  oc get pod -n ${GUID}-sonarqube | grep -v deploy | grep -q "1/1"
  [[ "$?" == "1" ]] || break
  echo "... not quite yet. Sleeping 20 seconds."
  sleep 20
done

# Setup Nexus ImageStream for build
oc import-image sonarqube:6.7.4 --from=wkulhanek/sonarqube:6.7.4 --confirm

# Process template and create sonarqube application for environment
sed "s/GUID/${GUID}/g" ../templates/sonarqube_application_template_build.yaml | oc process -f - | oc create -f -

# Expose Sonarqube Route
oc expose svc sonarqube
