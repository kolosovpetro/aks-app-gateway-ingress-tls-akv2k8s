# Azure Application Gateway Ingress AKS

This repository provisions an Azure Kubernetes Service (AKS) cluster with Application Gateway Ingress Controller (AGIC),
integrated Key Vault secret sync (akv2k8s), and Cloudflare DNS automation.

- https://agwy-ingress-test.razumovsky.me

## Overview

The project deploys a production-ready AKS environment with the following:

- Azure Virtual Network and subnets
- Application Gateway with a custom domain SSL certificate
- Key Vault for secure certificate storage
- AGIC configured with proper identity and RBAC
- akv2k8s for syncing secrets and certificates from Key Vault
- Sample application with Ingress, TLS, and service definition
- Cloudflare integration using PowerShell to update DNS records automatically

## Deployment order

- terraform plan
- terraform apply
- .\Configure-Cloudflare-Records.ps1
- .\Configure-Kv-CRD.ps1
- .\Configure-Deployment.ps1

## Configuration

- Configure Virtual Network and dedicated subnets:
    - Application Gateway Subnet
    - AKS Subnet

- Deploy and configure Application Gateway

- Upload and manage SSL certificate in Azure Key Vault

- Assign managed identity permissions (RBAC):

  ### Ingress Managed Identity:
    - Reader on AKS Resource Group
    - Reader on Node Resource Group
    - Contributor on Application Gateway
    - Contributor on Gateway Subnet

  ### Node Pool Managed Identity:
    - Key Vault Secrets User on Key Vault
    - Key Vault Certificates Officer on Key Vault

- Configure `akv2k8s` via Helm with CRDs for syncing Key Vault secrets

- Deploy a test application with:
    - Ingress resource with TLS
    - ClusterIP Service
    - Synced certificate from Key Vault via akv2k8s

- PowerShell scripts for automating DNS updates on Cloudflare

## Requirements

- Terraform CLI
- Azure CLI
- PowerShell Core
- Helm v3
- kubectl
- Cloudflare API Token with DNS edit rights
- Azure subscription with:
    - Key Vault
    - Application Gateway
    - Sufficient IAM permissions to assign roles

## Notes

- Role assignments may require a propagation delay (~5 minutes)
- Ensure AKS has Managed Identity enabled (User Assigned recommended)
- AGIC must be configured with the correct Application Gateway name and resource group
- Key Vault must have `public network access` enabled or appropriate private link settings

## Docs

- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster
- https://medium.com/@rhodrifreer/a-terraform-aks-and-application-gateway-tutorial-part-1-91958633519e
