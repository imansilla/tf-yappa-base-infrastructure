#empty
terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "nubity-inc"

    workspaces {
      name = "brain-base-infrastructure"
    }
  }
}
