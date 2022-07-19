variable "instance_az" {
  type        = string
  description = "(required) AZ to place the instance in"
  validation {
    condition     = var.instance_az != ""
    error_message = "AZ can't be empty"
  }
}
