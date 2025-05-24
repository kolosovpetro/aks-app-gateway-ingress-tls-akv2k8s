$rgNodepool = terraform output -raw rg_node_pool
$kvName = terraform output -raw kv_name

Write-Warning "Rg nodepool: $rgNodepool"

$principalId = az identity show --name "aks-d01-agentpool" --resource-group $rgNodepool --query principalId --output tsv

Write-Warning "Principal ID: $principalId"

az role assignment create `
    --assignee $principalId `
    --role "Key Vault Secrets User" `
    --scope $(az keyvault show --name $kvName --query id -o tsv)

az role assignment create `
    --assignee $principalId `
    --role "Key Vault Certificate User" `
    --scope $(az keyvault show --name $kvName --query id -o tsv)

