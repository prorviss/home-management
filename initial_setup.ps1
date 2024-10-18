$PROJECT_ID = "home-management-438820"
$PROJECT_NUMBER = "656120491361"
$BUCKET_NAME = "orviss-homemanagement-tfstate"
$REGION = "africa-south1"
$SERVICE_ACCOUNT_NAME = "terraform-sa"
$GITHUB_ORG = "prorviss"
$REPO_NAME = "home-management"
$REPO = "$GITHUB_ORG/$REPO_NAME" 
$LOCAL_DIR = "terraform"
$POOL_ID = "gh-actions-pool"
$WORKLOAD_IDENTITY_PROVIDER = "gh-actions-provider"

# Set the Google Cloud project
gcloud config set project $PROJECT_ID

# Ensure you are logged in to the GitHub CLI
gh auth status > $null 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "Please authenticate with GitHub CLI by running: gh auth login"
  exit 1
}

# Check if the GitHub repository already exists
gh repo view $REPO > $null 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Host "Repository $REPO already exists."
}
else {
  # Create the GitHub repository
  Write-Host "Creating GitHub repository $REPO..."
  gh repo create $REPO --public --confirm
  Write-Host "Repository $REPO created."
}

# Enable necessary Google Cloud services
Write-Host "Enabling Google Cloud services..."
gcloud services enable cloudresourcemanager.googleapis.com iam.googleapis.com storage.googleapis.com

# Check if the GCS bucket exists
Write-Host "Checking if GCS bucket gs://$BUCKET_NAME/ exists..."
gsutil ls -p $PROJECT_ID "gs://$BUCKET_NAME/" > $null 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Host "Bucket gs://$BUCKET_NAME/ already exists."
  gsutil versioning set on "gs://$BUCKET_NAME/"
}
else {
  # Create GCS bucket for Terraform state
  Write-Host "Creating GCS bucket gs://$BUCKET_NAME/ for Terraform state..."
  gsutil mb -p $PROJECT_ID -l $REGION "gs://$BUCKET_NAME/"
  gsutil versioning set on "gs://$BUCKET_NAME/"
  Write-Host "Bucket gs://$BUCKET_NAME/ created and versioning enabled."
}

# Create Terraform service account
Write-Host "Creating Terraform service account..."
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --display-name "Terraform Service Account" > $null 2>&1

# Assign roles to the service account
Write-Host "Assigning roles to the service account..."
gcloud projects add-iam-policy-binding $PROJECT_ID --member "serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role "roles/editor" > $null 2>&1
gcloud projects add-iam-policy-binding $PROJECT_ID --member "serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role "roles/storage.admin" > $null 2>&1

# Create Workload Identity Pool
Write-Host "Creating Workload Identity Pool..."
gcloud iam workload-identity-pools create $POOL_ID --project=$PROJECT_ID --location="global" --display-name="Github Actions Pool" > $null 2>&1

# Create Workload Identity Provider
$AttributeMapping = "google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner"
$AttributeCondition = "assertion.repository_owner == '$GITHUB_ORG'"
Write-Host "Creating Workload Identity Provider..."
gcloud iam workload-identity-pools providers create-oidc $WORKLOAD_IDENTITY_PROVIDER `
  --project=$PROJECT_ID `
  --location="global" `
  --workload-identity-pool=$POOL_ID `
  --display-name="Github Actions Provider" `
  --attribute-mapping="$AttributeMapping" `
  --attribute-condition="$AttributeCondition" `
  --issuer-uri="https://token.actions.githubusercontent.com" > $null 2>&1

# Add IAM policy binding for Workload Identity User
$Member = "principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_ORG/$REPO_NAME"
Write-Host "Adding IAM policy binding to the service account..."
gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" `
  --project=$PROJECT_ID `
  --role="roles/iam.workloadIdentityUser" `
  --member="$Member" > $null 2>&1 

# Set GitHub secrets
Write-Host "Setting GitHub secrets..."
$WORKLOAD_IDENTITY_PROVIDER_VALUE = "projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$WORKLOAD_IDENTITY_PROVIDER"
$GOOGLE_SERVICE_ACCOUNT_VALUE = "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"
gh secret set WORKLOAD_IDENTITY_PROVIDER --repo $REPO --body $WORKLOAD_IDENTITY_PROVIDER_VALUE
gh secret set GOOGLE_SERVICE_ACCOUNT --repo $REPO --body $GOOGLE_SERVICE_ACCOUNT_VALUE

# Creating the base Terraform configuration
Write-Host "Creating base Terraform configuration in $LOCAL_DIR..."

if (!(Test-Path -Path "$LOCAL_DIR")) {
  # Create the folder structure
  New-Item -ItemType Directory -Force -Path $LOCAL_DIR

  # Create backend.tf for remote state storage
  $backendTfContent = @"
terraform {
  backend "gcs" {
    bucket  = "$BUCKET_NAME"
    prefix  = "terraform/state"
  }
}
"@
  Set-Content -Path "$LOCAL_DIR\backend.tf" -Value $backendTfContent

  # Create main.tf
  $mainTfContent = @'
provider "google" {
  project = var.project_id
  region  = var.region
}
'@
  Set-Content -Path "$LOCAL_DIR\main.tf" -Value $mainTfContent


  # Create variables.tf
  $variablesTfContent = @"
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
"@
  Set-Content -Path "$LOCAL_DIR\variables.tf" -Value $variablesTfContent

  # Create .gitignore
  $gitignoreContent = @"
# Ignore Terraform state files
*.tfstate
*.tfstate.backup
.terraform/
"@
  Set-Content -Path "$LOCAL_DIR\.gitignore" -Value $gitignoreContent
}
else {
  Write-Host "Terraform folder already exists"
}


# Initialize Terraform to configure the backend
if (!(Test-Path -Path "$LOCAL_DIR\.terraform.lock.hcl")) {
  Set-Location $LOCAL_DIR
  terraform init
  Set-Location ".."
}
else {
  Write-Host "Terraform already initialized"
}

# Check if Git repository is initialized
if (!(Test-Path -Path ".git" -PathType Container)) {
  Write-Host "Initializing Git repository and setting remote..."
  git init
  git remote add origin "git@github.com:$REPO.git"
  git add .
  git commit -m "Initial commit of base Terraform configuration"
  git branch -M main
  git push -u origin main
  Set-Location ".."
}
else {
  Write-Host "Git repository already initialized."
  git fetch --all -Pp
  git pull
}

Write-Host "Terraform configuration has been initialized and pushed to $REPO."
Write-Host "Setup complete. Google Cloud service account key and project ID have been stored as GitHub Secrets."