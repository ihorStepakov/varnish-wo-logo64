#!/bin/bash

SED=$(which sed);

#
# This is an example of reset password hook in Jelastic
#

J_OPENSHIFT_APP_ADM_USER="admin";   ### Specify your admin user ###
#$J_OPENSHIFT_APP_ADM_USER              ;   ### The value of this variable is randomly generated and will be sent to a user by email

function _setPassword() {
    NEO4J_SERVER_PROP_FILE="${CARTRIDGE_APP_HOME}/conf/neo4j-server.properties"
    $SED -i "s/^org.neo4j.server.credentials=.*/org.neo4j.server.credentials=${J_OPENSHIFT_APP_ADM_USER}:${J_OPENSHIFT_APP_ADM_PASSWORD}/" $NEO4J_SERVER_PROP_FILE;
    service cartridge restart;
}





