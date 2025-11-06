variable "api_port" {
  type    = number
  default = 3000
}

variable "pg_user" {
  type    = string
  default = "app"
}

variable "pg_password" {
  type    = string
  default = "appsecret"
}

variable "pg_db" {
  type    = string
  default = "catalogue"
}