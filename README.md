## Modules

- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster

## DNS

- https://agwy-ingress-test.razumovsky.me


## Deployment order

- terraform plan
- terraform apply
- Update DNS record
- .\Configure-Kv-CRD.ps1
- .\Configure-Kv-Nodepool-RBAC.ps1
- .\Configure-Deployment.ps1
