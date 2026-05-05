variable "prefix" {
  description = "Your unique prefix — used in all resource names to avoid conflicts"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.prefix))
    error_message = "Prefix must be 3-10 lowercase alphanumeric characters only."
  }
}

variable "aws_region" {
  description = "AWS region to deploy the lab"
  type        = string
  default     = "us-east-1"
}