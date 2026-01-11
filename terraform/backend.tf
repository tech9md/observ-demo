# Terraform Backend Configuration
# Uses GCS for state storage with locking
#
# For GitHub Actions, the bucket and prefix are configured via CLI:
#   terraform init -backend-config="bucket=PROJECT_ID-tfstate" -backend-config="prefix=observ-demo/ENVIRONMENT"
#
# For local development:
#   1. Create the state bucket first:
#      gsutil mb -p PROJECT_ID -l REGION -b on gs://PROJECT_ID-tfstate
#      gsutil versioning set on gs://PROJECT_ID-tfstate
#   2. Run: terraform init -backend-config="bucket=YOUR_PROJECT_ID-tfstate"

terraform {
  backend "gcs" {
    # These values are configured via -backend-config CLI arguments
    # bucket = "configured-via-cli"
    # prefix = "configured-via-cli"
  }
}
