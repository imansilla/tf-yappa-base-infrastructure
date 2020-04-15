# Micro Service Terraform Module
Module to create base infrastruture to run the project "Brain"

### Requirement
None

## Compatibility

This module is meant for use with Terraform 0.12. If you haven't
[upgraded](https://www.terraform.io/upgrade-guides/0-12.html) and
need a Terraform 0.11.x-compatible version of this module, the
last released version intended for Terraform 0.11.x is
[1.0.4](https://registry.terraform.io/modules/GoogleCloudPlatform/lb-internal/google/1.0.4).

## Usage

```hcl
module "bimbo_micro_service" {
  source                    = "../../base_infrastructure"

  # AWS Variables
  region                    = "us-east-1"

}
```

## Resources created

* aws_iam_role.ecs_tasks_execution_role
* aws_iam_role_policy_attachment.ecs_tasks_execution_role
* aws_iam_service_linked_role.AWSServiceRoleForECS

* aws_vpc.main
* aws_vpc_dhcp_options.main
* aws_vpc_dhcp_options_association.dns_resolver
* aws_eip.nat
* aws_internet_gateway.igw
* aws_nat_gateway.ngw

* aws_subnet.private1b
* aws_subnet.private1d
* aws_subnet.public1a
* aws_subnet.public1c

* aws_route_table.private
* aws_route_table.public

* aws_route_table_association.private1b
* aws_route_table_association.private1d
* aws_route_table_association.public1a
* aws_route_table_association.public1c

* aws_lb.alb
* aws_lb_listener.listener
* aws_security_group.allow_http

## Import rutine

* **module.base_infrastructure.aws_eip.nat**

``` 
$ docker-compose run --rm terraform import module.base_infrastructure.aws_eip.nat [EIP_ALLOCATION_ID]

```