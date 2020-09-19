#cloud variables

variable "public_key" {
  type = string
}

variable "private_key" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
}

variable "cloudflare_zone" {
  type = string
}

variable "hetzner_api_token" {
  type = string
}

variable "email_address" {
  type = string
}

variable "scores_domain" {
  type = string
}

variable "scores_user" {
  type = string
}

variable "ssh_user" {
  type = string
}
