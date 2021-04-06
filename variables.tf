variable "env" {
  description = "Environment which the lambda runs in"
}

variable "asa_team" {
  description = "Okta ASA team"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to encrypt ASA API secrets in SSM"
}

variable "asa_api_key_path" {
  description = "Path to ASA API key in SSM"
}

variable "asa_api_secret_path" {
  description = "Path to ASA API secret in SSM"
}
