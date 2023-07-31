$PREFIX="aks"
$RG="$PREFIX-rg"
$NODE_RG = "$PREFIX-node-rg"
$LOC="eastus"
$PLUGIN="kubenet"
$AKSNAME=$prefix
$VNET_NAME="$PREFIX-vnet"
$AKSSUBNET_NAME="aks-subnet"
$FWSUBNET_NAME="AzureFirewallSubnet"
$FWNAME="$PREFIX-fw"
$FWPUBLICIP_NAME="$PREFIX-fwpublicip"
$FWIPCONFIG_NAME="$PREFIX-fwconfig"
$FWROUTE_TABLE_NAME="$PREFIX-fwrt"
$FWROUTE_NAME="$PREFIX-fwrn"
$FWROUTE_NAME_INTERNET="$PREFIX-fwinternet"

# Create a virtual network with multiple subnets
az group create --name $RG --location $LOC
az network vnet create --resource-group $RG --name $VNET_NAME --location $LOC --address-prefixes 10.42.0.0/16 --subnet-name $AKSSUBNET_NAME --subnet-prefix 10.42.1.0/24
az network vnet subnet create --resource-group $RG --vnet-name $VNET_NAME --name $FWSUBNET_NAME --address-prefix 10.42.2.0/24

# Create and set up an Azure Firewall with a UDR
az network public-ip create -g $RG -n $FWPUBLICIP_NAME -l $LOC --sku "Standard"
az extension add --name azure-firewall
az network firewall create -g $RG -n $FWNAME -l $LOC --enable-dns-proxy true
az network firewall ip-config create -g $RG -f $FWNAME -n $FWIPCONFIG_NAME --public-ip-address $FWPUBLICIP_NAME --vnet-name $VNET_NAME
$FWPUBLIC_IP=$(az network public-ip show -g $RG -n $FWPUBLICIP_NAME --query "ipAddress" -o tsv)
$FWPRIVATE_IP=$(az network firewall show -g $RG -n $FWNAME --query "ipConfigurations[0].privateIpAddress" -o tsv)

# Create a UDR with a hop to Azure Firewall
az network route-table create -g $RG -l $LOC --name $FWROUTE_TABLE_NAME
az network route-table route create -g $RG --name $FWROUTE_NAME --route-table-name $FWROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FWPRIVATE_IP
az network route-table route create -g $RG --name $FWROUTE_NAME_INTERNET --route-table-name $FWROUTE_TABLE_NAME --address-prefix $FWPUBLIC_IP/32 --next-hop-type Internet

# Add firewall rules
az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'apiudp' --protocols 'UDP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 1194 --action allow --priority 100
az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'apitcp' --protocols 'TCP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 9000
az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'time' --protocols 'UDP' --source-addresses '*' --destination-fqdns 'ntp.ubuntu.com' --destination-ports 123
az network firewall application-rule create -g $RG -f $FWNAME --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 100

# Associate the route table to AKS
az network vnet subnet update -g $RG --vnet-name $VNET_NAME --name $AKSSUBNET_NAME --route-table $FWROUTE_TABLE_NAME

# Deploy an AKS cluster with a UDR outbound type to the existing network
$SUBNETID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME --name $AKSSUBNET_NAME --query id -o tsv)

# Create user-assigned identities
$CONTROL_PLANE_IDENTITY_NAME = "controlPlaneIdentity"
az identity create --name $CONTROL_PLANE_IDENTITY_NAME --resource-group $RG
$CONTROL_PLANE_IDENTITY_ID = $(az identity show --resource-group $RG --name $CONTROL_PLANE_IDENTITY_NAME --query id -o tsv)
$CONTROL_PLANE_IDENTITY_OBJECT_ID = $(az identity show --resource-group $RG --name $CONTROL_PLANE_IDENTITY_NAME --query principalId -o tsv)
az role assignment create --role "Contributor" --assignee-object-id $CONTROL_PLANE_IDENTITY_OBJECT_ID --resource-group $RG

$KUBELET_IDENTITY_NAME = "kubeletIdentity"
az identity create --name $KUBELET_IDENTITY_NAME --resource-group $RG
$KUBELET_IDENTITY_ID = $(az identity show --resource-group $RG --name $KUBELET_IDENTITY_NAME --query id -o tsv)
$KUBELET_IDENTITY_OBJECT_ID = $(az identity show --resource-group $RG --name $KUBELET_IDENTITY_NAME --query principalId -o tsv)
az role assignment create --role "Contributor" --assignee-object-id $KUBELET_IDENTITY_OBJECT_ID --resource-group $RG

# From VA docs
az aks create --resource-group $RG --name $AKSNAME --vnet-subnet-id $SUBNETID --enable-managed-identity --enable-private-cluster --assign-identity $CONTROL_PLANE_IDENTITY_ID --assign-kubelet-identity $KUBELET_IDENTITY_ID --node-resource-group $NODE_RG --private-dns-zone none --outbound-type userDefinedRouting --network-plugin $PLUGIN --generate-ssh-keys