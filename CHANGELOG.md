# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning v2.0.0](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - In Progress

### Changed

- Configure VNET and subnets
- Configure Application gateway
- Deploy SSL certificate to KeyVault
- Assign Ingress managed identities
    - Resource group AKS: `Reader`
    - Resource group Nodes: `Reader`
    - App Gateway: `Contributor`
    - Gateway subnet: `Contributor`
- Configure akv2k8s CRD using HELM
- Configure Node pool managed identity
    - Keyvault RBAC: `Key Vault Secrets User`
    - Keyvault RBAC: `Key Vault Certificate User`
- Configure test deployment with
    - Ingress controller
    - TLS secret
    - ClusterIP service
