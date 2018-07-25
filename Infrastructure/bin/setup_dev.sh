#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

#  Change to Parks Development Environment Project
oc project ${GUID}-parks-dev

# Create MongoDB standalone persistent server from template
oc process -f ../templates/mongodb_template_build.yaml | oc create -f -
