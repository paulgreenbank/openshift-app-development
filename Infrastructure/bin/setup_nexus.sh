#!/bin/bash
# Setup Nexus Project

if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Change to Nexus Project
oc project ${GUID}-nexus

# Setup Nexus ImageStream for build
oc import-image nexus3 --from=sonatype/nexus3 --confirm

# Process template and create environment
sed "s/GUID/${GUID}/g" ../templates/nexus_template_build.yaml | oc process -f - | oc create -f -

# Wait for Nexus to fully deploy and become ready
while : ; do
  echo "Checking if Nexus is Ready..."
  #oc get pod -n ${GUID}-nexus | grep -v deploy | grep "1/1"
  curl -i http://$(oc get route nexus3 --template='{{ .spec.host }}') 2>&1 /dev/null | grep 'HTTP/1.1 200 OK' > /dev/null
  [[ "$?" == "1" ]] || break
  echo "... not quite yet. Sleeping 20 seconds."
  sleep 20
done

# Setup Nexus Repositoies via script sourced from
# https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
./configure_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}')
