#!/bin/bash
# CrisisConnect - Cleanup Script
# Removes all GCP resources created for the hackathon

set -e

PROJECT_ID=$(gcloud config get-value project)
REGION=us-central1

echo "=== CrisisConnect Cleanup ==="
echo "Project: $PROJECT_ID"
echo "WARNING: This will delete all CrisisConnect resources!"
read -p "Continue? (y/N): " confirm
if [ "$confirm" != "y" ]; then
    echo "Aborted."
    exit 0
fi

# Delete Cloud Run service
echo "Deleting Cloud Run service..."
gcloud run services delete crisisconnect --region=$REGION --quiet 2>/dev/null || echo "Service not found"

# Delete BigQuery dataset
echo "Deleting BigQuery dataset..."
bq rm -r -f ${PROJECT_ID}:crisis_connect 2>/dev/null || echo "Dataset not found"

# Delete Artifact Registry
echo "Deleting Artifact Registry..."
gcloud artifacts repositories delete cloud-run-source-deploy --location=$REGION --quiet 2>/dev/null || echo "Registry not found"

# Delete VPC connector
echo "Deleting VPC connector..."
gcloud compute networks vpc-access connectors delete crisisconnect-vpc --region=$REGION --quiet 2>/dev/null || echo "VPC connector not found"

# Delete service account
echo "Deleting service account..."
gcloud iam service-accounts delete crisisconnect-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet 2>/dev/null || echo "Service account not found"

# Note: AlloyDB cluster must be deleted manually from Console
echo ""
echo "=== Cleanup Complete ==="
echo "NOTE: AlloyDB cluster must be deleted manually:"
echo "  https://console.cloud.google.com/alloydb/clusters"
