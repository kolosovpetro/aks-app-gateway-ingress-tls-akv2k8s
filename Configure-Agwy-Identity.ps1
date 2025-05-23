# Get AGIC identity from AKS cluster

$rgName = $( terraform output -raw rg_name )
$AksName = $( terraform output -raw aks_name )
$AgwName = $( terraform output -raw agwy_name )

$AGIC_PRINCIPAL_ID = $( az aks show `
--name $AksName `
--resource-group $rgName `
--query "addonProfiles.ingressApplicationGateway.identity.clientId" `
--output tsv )

$SCOPE = $( az network application-gateway show `
--name $AgwName `
--resource-group $rgName `
--query "id" -o tsv )

Write-Host "Client id: $AGIC_PRINCIPAL_ID"
Write-Host "Scope: $SCOPE"
Write-Host "RG name: $rgName"


# Assign Contributor on App Gateway
az role assignment create `
--assignee $AGIC_PRINCIPAL_ID `
--role "Contributor" `
--scope $SCOPE

## Assign Reader on App Gateway's Resource Group
#az role assignment create \
#--assignee $AGIC_PRINCIPAL_ID \
#--role "Reader" \
#--scope $(az group show --name <rg-name> --query "id" -o tsv)
