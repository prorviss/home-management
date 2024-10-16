#!/bin/bash

# Variables - Replace these with your actual values
PROJECT_ID="home-manager-438719"
PROJECT_NUMBER="337114112835"
BUCKET_NAME="orviss-homemanager-tfstate"
REGION="africa-south1"
SERVICE_ACCOUNT_NAME="terraform-sa"
GITHUB_ORG="prorviss"
REPO_NAME="home-manager"  # Just the repository name, without owner
REPO="$GITHUB_ORG/$REPO_NAME"  # Full GitHub repo in owner/repo format
LOCAL_DIR="terraform-base-config"
POOL_ID="github-actions-pool"
WORKLOAD_IDENTITY_PROVIDER="github-actions-provider"

gcloud config set project "$PROJECT_ID"

# Ensure you are logged in to the GitHub CLI
if ! gh auth status > /dev/null 2>&1; then
    echo "Please authenticate with GitHub CLI by running: gh auth login"
    exit 1
fi

# Check if the GitHub repository already exists
if gh repo view "$REPO" > /dev/null 2>&1; then
    echo "Repository $REPO already exists."
else
    # Create the GitHub repository
    echo "Creating GitHub repository $REPO..."
    gh repo create "$REPO" --public --confirm
    echo "Repository $REPO created."
fi

# Enable necessary Google Cloud services
echo "Enabling Google Cloud services..."
gcloud services enable cloudresourcemanager.googleapis.com iam.googleapis.com storage.googleapis.com

# Create GCS bucket for Terraform state
echo "Creating GCS bucket for Terraform state..."
gsutil mb -p "$PROJECT_ID" -l "$REGION" gs://"$BUCKET_NAME"/
gsutil versioning set on gs://"$BUCKET_NAME"/

# Create Terraform service account
echo "Creating Terraform service account..."
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
  --display-name "Terraform Service Account"

# Assign roles to the service account
echo "Assigning roles to the service account..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud iam workload-identity-pools create "$POOL_ID" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="Github Actions Pool"

gcloud iam workload-identity-pools providers create-oidc "$WORKLOAD_IDENTITY_PROVIDER" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="$POOL_ID" \
  --display-name="Github Actions Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == '$GITHUB_ORG'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_NAME@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_ORG/$REPO_NAME"
  
gh secret set WORKLOAD_IDENTITY_PROVIDER --repo "$REPO" --body "projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$WORKLOAD_IDENTITY_PROVIDER"
gh secret set GOOGLE_SERVICE_ACCOUNT --repo "$REPO" --body "$SERVICE_ACCOUNT_NAME@${PROJECT_ID}.iam.gserviceaccount.com"

# Creating the base Terraform configuration
echo "Creating base Terraform configuration in $LOCAL_DIR..."

# Make the folder structure
mkdir -p "$LOCAL_DIR"

# Create backend.tf for remote state storage
cat > "$LOCAL_DIR/backend.tf" <<EOL
terraform {
  backend "gcs" {
    bucket  = "$BUCKET_NAME"
    prefix  = "terraform/state"
  }
}
EOL

# Create main.tf
cat > "$LOCAL_DIR/main.tf" <<EOL
provider "google" {
  project     = var.project_id
  region      = var.region
}

resource "google_storage_bucket" "example_bucket" {
  name     = "example-terraform-bucket-\${var.project_id}"
  location = var.region
}
EOL

# Create variables.tf
cat > "$LOCAL_DIR/variables.tf" <<EOL
variable "project_id" {
  description = "The project ID to deploy resources in"
  type        = string
  default     = "$PROJECT_ID"
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "$REGION"
}
EOL

# Create .gitignore
cat > "$LOCAL_DIR/.gitignore" <<EOL
# Ignore Terraform state files
*.tfstate
*.tfstate.backup
.terraform/
EOL

echo "Moving key file..."
mv "$KEY_FILE" "$LOCAL_DIR"
 
# Initialize Terraform to configure the backend
cd "$LOCAL_DIR"

terraform init

cd ".."

if [ ! -d ".git" ]; then
    echo "Initializing Git repository and setting remote..."
    cd "$LOCAL_DIR"
    git init
    git remote add origin "git@github.com:$REPO.git"
    git add .
    git commit -m "Initial commit of base Terraform configuration"
    git branch -M main
    git push -u origin main
else
    echo "Git repository already initialized."
    git fetch --all -Pp
    git pull
fi

echo "Terraform configuration has been initialized and pushed to $REPO."

echo "Setup complete. Google Cloud service account key and project ID have been stored as GitHub Secrets."