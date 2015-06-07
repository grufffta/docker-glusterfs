#!/bin/bash

set -e

[ "$DEBUG" == "1" ] && set -x

echo "=> Waiting for glusterd to start..."
sleep 10

# Check if I'm part of the cluster
NUMBER_OF_PEERS=`gluster peer status | awk '{print $4}'`
if [ ${NUMBER_OF_PEERS} -ne 0 ]; then
   # This container is already part of the cluster
   echo "=> This container is already joined with nodes ${GLUSTER_PEERS}, skipping joining ..."
   exit 0
fi

# Join the cluster - choose a suitable container
ALIVE=0
for PEER in ${GLUSTER_PEERS}; do
   # Skip myself
   if [ "${MY_RANCHER_IP}" == "${PEER}" ]; then
      continue
   fi
   echo "=> Checking if I can reach gluster container ${PEER} ..."
   if ssh ${SSH_OPTS} ${SSH_USER}@${PEER} "hostname" >/dev/null 2>&1; then
      echo "=> Gluster container ${PEER} is alive"
      ALIVE=1
      break
   else
      echo "*** Could not reach gluster container ${PEER} ..."
   fi 
done

if [ ${ALIVE} -eq 0 ]; then
   echo "Could not reach any GlusterFS container from this list: ${GLUSTER_PEERS} - Maybe I am the first node in the cluster? Well, I keep waiting for new containers to join me ..."
   exit 0
fi

echo "=> Joining cluster with container ${PEER} ..."
ssh ${SSH_OPTS} ${SSH_USER}@${PEER} "add-gluster-peer.sh ${MY_RANCHER_IP}"
if [ $? -eq 0 ]; then
   echo "=> Successfully joined cluster with container ${PEER} ..."
else
   echo "=> Error joining cluster with container ${PEER} ..."
fi