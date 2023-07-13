# backend.tf
terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket = "go-lambda-terraform-backend"
    key    = "go-lambda-test.tfstate"
    region = "us-east-1"
  }
}
