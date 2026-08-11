variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Unique prefix for all resource names (lowercase letters and numbers only)"
  type        = string
}
