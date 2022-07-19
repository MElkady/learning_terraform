# Learning Terraform

A terraform playground

## Running

First, create your own `backend.conf` using the template in `backend.conf.template` then run:

```
terraform init --backend-config=backend.conf
terraform plan
terraform apply
```

## Cleaning up

```
terraform destroy --auto-approve
```
