variable "region" {
  default = "ap-south-1"
}


variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for instances"
  type        = string
  default     = "id_rsa"
}