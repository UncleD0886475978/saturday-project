variable "aws_region" {
  default = "us-east-1"
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI (update per region: https://console.aws.amazon.com/ec2/home#Images)"
  default     = "ami-0332d564d76dbd8d6"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in your AWS account"
  type        = string
  default     = "saturday-project-key"
}
