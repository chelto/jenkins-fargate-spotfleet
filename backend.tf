terraform {
  required_version = ">=1.0.1"
  required_providers {
    aws = ">=3.0.0"
  }
  backend "s3" {
    region         = "eu-west-2"
    profile        = "default"
    key            = "nameoffile"
    bucket         = "s3bucketname"
    dynamodb_table = "dynamotablename"
  }
}
