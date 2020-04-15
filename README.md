# tf-brain-base-infrastructure

This project uses Terraform Cloud to storage the terraform.tfstate file.
To upload modifications run:

```
docker-compose run -rm terraform apply
```

Before that, you have to export the variable TOKEN with the terraform token for API access.