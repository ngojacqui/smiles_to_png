#!/bin/bash 

## Create dataset to store the cheminformatics functions

bq mk  --force=true --description "Dataset that will contain the cheminformatics functions" --label=package:cheminformatics  --dataset "cheminformatics" 

## Create connection

## Check if connection already exists 

bq show --location=US --format=prettyjson --connection "cheminformatics-connection" > /dev/null 2>&1

status=$?

## if the connection exists, continue. otherwise, create the connection

if [ $status -eq 0 ]
 then
    echo "Connection cheminformatics-connect already exists"
 else
    echo "Creating connection cheminformatics-connect"
    bq mk --connection --display_name="Cheminformatics Connection" --connection_type=CLOUD_RESOURCE --location=US "cheminformatics-connection"
fi

## Get Service Account associated to Connection

SERVICE_ACCOUNT=$(bq show --location=US --format=prettyjson --connection "cheminformatics-connection" | jq -r '.cloudResource.serviceAccountId')

echo "Connection cheminformatics-connect service account: ${SERVICE_ACCOUNT}"

## Give service account the cloud run invoker role (necessary for cloud functions gen2)

PROJ=$(gcloud config list --format 'value(core.project)')

####### Begin creating cloud functions  

PERM="roles/cloudfunctions.invoker"

TIMEOUT=3600s
MEMORY=512MB
MAX_INSTANCES=1000

## start installation by folder

cd rdkit_png

## install rdkit-draw-png

gcloud beta functions deploy rdkit-draw-png \
     --quiet --gen2 --region "us-east1" --entry-point rdkit_draw_png --runtime python39 --trigger-http \
     --memory=$MEMORY --timeout=$TIMEOUT --max-instances=$MAX_INSTANCES \
     --update-labels package=cheminformatics --update-labels function_type=remote_function --update-labels software_package=rdkitpng

CLOUD_TRIGGER_URL=$(gcloud beta functions describe rdkit-draw-png --gen2 --region "us-east1" --format=json | jq -r '.serviceConfig.uri')

gcloud beta functions add-iam-policy-binding "rdkit-draw-png" --region "us-east1" --member=serviceAccount:${SERVICE_ACCOUNT} --role=${PERM} --gen2

gcloud run services add-iam-policy-binding "rdkit-draw-png" --region "us-east1" --member=serviceAccount:${SERVICE_ACCOUNT} --role="roles/run.invoker"

bq query --use_legacy_sql=false --parameter="url::${CLOUD_TRIGGER_URL}" 'CREATE or REPLACE FUNCTION cheminformatics.rdkit_draw_png(smiles STRING) RETURNS STRING REMOTE WITH CONNECTION `us.cheminformatics-connection` OPTIONS (endpoint = @url, max_batching_rows = 1000)'

cd ..


## wait one minute for permissions to propagate
echo "Waiting for permissions to propagate ..."
sleep 90