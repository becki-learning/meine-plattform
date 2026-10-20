variable "region" {
  type    = string
  default = "us-east-1"
}

variable "projekt" {
  description = "Präfix für alle Namen"
  type        = string
  default     = "meine-plattform"
}

variable "meine_ip" {
  description = "Deine öffentliche IP – setzt das Makefile automatisch (TF_VAR_meine_ip)"
  type        = string
}

variable "bastion_typ" {
  type    = string
  default = "t3.micro"
}

variable "master_typ" {
  type    = string
  default = "t3.small"
}

variable "worker_typ" {
  type    = string
  default = "t3.medium"
}

variable "worker_anzahl" {
  type    = number
  default = 3
}
