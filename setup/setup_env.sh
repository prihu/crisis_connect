#!/bin/bash
# CrisisConnect - GCP Environment Setup
# Run this FIRST before anything else

set -e

echo "=== CrisisConnect GCP Setup ==="

# Get project info
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

echo "Project ID: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"

# Enable required APIs
echo "Enabling APIs..."
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  aiplatform.googleapis.com \
  compute.googleapis.com \
  alloydb.googleapis.com \
  vpcaccess.googleapis.com \
  bigquery.googleapis.com \
  cloudresourcemanager.googleapis.com

echo "APIs enabled."

# Create service account
SA_NAME=crisisconnect-sa
SERVICE_ACCOUNT=${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

echo "Creating service account: $SERVICE_ACCOUNT"
gcloud iam service-accounts create ${SA_NAME} \
  --display-name="CrisisConnect Service Account" 2>/dev/null || echo "Service account already exists"

# Grant IAM roles
echo "Granting IAM roles..."
for ROLE in \
  roles/aiplatform.user \
  roles/bigquery.dataViewer \
  roles/bigquery.jobUser \
  roles/alloydb.client \
  roles/vpcaccess.user \
  roles/logging.logWriter; do
  echo "  Granting $ROLE..."
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="$ROLE" \
    --quiet
done

# Create .env file
echo "Creating .env file..."
cat <<EOF > .env
GOOGLE_GENAI_USE_VERTEXAI=1
GOOGLE_CLOUD_PROJECT=$PROJECT_ID
GOOGLE_CLOUD_LOCATION=us-central1
MODEL=gemini-2.5-flash
SA_NAME=$SA_NAME
SERVICE_ACCOUNT=$SERVICE_ACCOUNT
EOF

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Add GOOGLE_MAPS_API_KEY to .env (get from Google Cloud Console > APIs > Credentials)"
echo "  2. Add ALLOYDB_INSTANCE_URI, ALLOYDB_USER, ALLOYDB_PASSWORD, ALLOYDB_DB to .env"
echo "  3. Run setup_bigquery.sh to create BigQuery dataset"
echo "  4. Run setup_alloydb.sql in AlloyDB Studio to create schema + seed data"
