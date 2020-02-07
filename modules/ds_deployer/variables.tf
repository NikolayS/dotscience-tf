variable hub_hostname{
      description = "Hostname of the Dotscience Hub, the deployer uses this to connect to the Hub"
      type = string
}

variable "webrelay_key" {
  description = "Key from https://my.webhookrelay.com/tokens (temporarily while we migrate to in-cluster relay)"
  type = string
  default = "b06e261f-074e-47b5-bfbe-4d6d94ccd6f4"
}

variable "webrelay_secret" {
  description = "Secret from https://my.webhookrelay.com/tokens (temporarily while we migrate to in-cluster relay)"
  type = string
  default = "4rAW5vq0D7uN"
}
