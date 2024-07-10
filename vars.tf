variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "security_group_id" {
  description = "ID of the security group"
  type        = string
}

variable "security_group_region" {
  description = "Region of the security group"
  type        = string
}

variable "port" {
  description = "Port to open in the security group"
  type        = number
}

variable "expiration_time" {
  description = "Number of seconds the IP should be allowed"
  type        = number
}

variable "log_group_name_allow_access" {
  description = "CloudWatch log group name for allow access function"
  type        = string
}

variable "log_group_name_revoke_access" {
  description = "CloudWatch log group name for revoke access function"
  type        = string
}

variable "cognito_domain" {
  description = "Cognito domain for Hosted UI"
  type        = string
}

variable "callback_path" {
  description = "Callback URLs for the Cognito Hosted UI"
  type        = string
}
