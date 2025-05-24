helm repo add spv-charts https://charts.spvapi.no
helm repo update
helm install akv2k8s spv-charts/akv2k8s --namespace akv2k8s-system --create-namespace
