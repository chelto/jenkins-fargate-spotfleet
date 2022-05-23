//////////////// common vars that will need changing ///////////////

//////// Route 53 & ACM //////////////
variable "domain_name" {
  type        = string
  description = "Existing domain record already setup in route53"
  default     = "thisismysite.com"
}

variable "route53_subdomain" {
  type        = string
  description = "subdomain name which ALB will use for custom domain setup. Needs to match the ACM SSL"
  default     = "jenkins-spots"
}

variable "alb_acm_certificate_arn" {
  type        = string
  description = "The ACM certificate ARN to use for the ALB"
  default     = "arn:aws:acm:eu-west-2:certificaterarm"
}

variable "alb_ingress_allow_cidrs" {
  type        = list(string)
  description = "A list of cidrs to allow inbound into ALB, can be home address and work."
  default     = ["81.96.204.184/32","81.20.48.0/20","62.254.10.157/32"]
}

variable "name_prefix" {
  type        = string
  description = "name prefix to give to all recources in project"
  default     = "Jenkins-spotfleet"
}



variable "default_tags" {
  default = {
    Terraform = "true"
    Project   = "Jenkins-spotfleet"
  }
  description = "Additional resource tags to add to all resources"
  type        = map(string)
}

variable "vpc_id" {
  type        = string
  description = "vpc id with 2 private subnets already existing"
  default     = "VPCID"
}

//////////////// ///////////////


///////////////////////// fargate and spot fleets ////////////////////////////
variable "image" {
  type        = string
  description = "docker image"
  default     = "jenkins/jenkins:lts-jdk11"
}

variable "sshkey" {
  type    = string
  default = "jenkins_aws_KP"
}


variable "spot_fleet_ami" {
  type    = string
  default = "ami-011d0b77694edb3f4"
}


variable "instance-type" {
  type    = list(any)
  default = ["t3.medium", "t3.large", "t2.medium", "t2.large", "t3a.medium", "t3a.large"]
}


variable "controller_cpu" {
  type    = number
  default = 512
}

variable "controller_memory" {
  type    = number
  default = 1024
}


variable "jenkins_controller_task_role_arn" {
  type        = string
  description = "An custom task role to use for the jenkins controller (optional)"
  default     = null
}

variable "ecs_execution_role_arn" {
  type        = string
  description = "An custom execution role to use as the ecs exection role (optional)"
  default     = null
}


variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "defaultprofile" {
  type    = string
  default = "default"
}




#Add the variable webserver-port
variable "controller_port" {
  type    = number
  default = 8080
}

variable "agent_port" {
  type    = number
  default = 5000
}




///////////////// EFS ////////////
variable "efs_enable_encryption" {
  type    = bool
  default = true
}

variable "efs_kms_key_arn" {
  type    = string
  default = null // Defaults to aws/elasticfilesystem
}

variable "efs_performance_mode" {
  type    = string
  default = "generalPurpose" // alternative is maxIO
}

variable "efs_throughput_mode" {
  type    = string
  default = "bursting" // alternative is provisioned
}

variable "efs_provisioned_throughput_in_mibps" {
  type    = number
  default = null // might need to be 0
}

variable "efs_ia_lifecycle_policy" {
  type    = string
  default = null // Valid values are AFTER_7_DAYS AFTER_14_DAYS AFTER_30_DAYS AFTER_60_DAYS AFTER_90_DAYS
}


variable "efs_access_point_uid" {
  type        = number
  description = "The uid number to associate with the EFS access point" // Jenkins 1000
  default     = 1000
}

variable "efs_access_point_gid" {
  type        = number
  description = "The gid number to associate with the EFS access point" // Jenkins 1000
  default     = 1000
}

# BACKUP
variable "efs_enable_backup" {
  type    = bool
  default = true
}

variable "efs_backup_schedule" {
  type    = string
  default = "cron(0 00 * * ? *)"
}

variable "efs_backup_start_window" {
  type        = number
  default     = 60
  description = <<EOF
A value in minutes after a backup is scheduled before a job will be
canceled if it doesnt start successfully
EOF
}

variable "efs_backup_completion_window" {
  type        = number
  default     = 120
  description = <<EOF
A value in minutes after a backup job is successfully started before
it must be completed or it will be canceled by AWS Backup
EOF
}

variable "efs_backup_cold_storage_after_days" {
  type        = number
  default     = 30
  description = "Number of days until backup is moved to cold storage"
}

variable "efs_backup_delete_after_days" {
  type        = number
  default     = 120
  description = <<EOF
Number of days until backup is deleted. If cold storage transition
'efs_backup_cold_storage_after_days' is declared, the delete value must
be 90 days greater
EOF
}




///////// alb//////////////////////////
variable "alb_type_internal" {
  type    = bool
  default = false
}

variable "alb_enable_access_logs" {
  type    = bool
  default = false
}

variable "alb_access_logs_bucket_name" {
  type    = string
  default = null
}

variable "alb_access_logs_s3_prefix" {
  type    = bool
  default = null
}

