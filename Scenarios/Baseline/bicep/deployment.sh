#!/bin/bash

cd Scenarios/Baseline/bicep

# Registering Resource Providers
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.ContainerInstance
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.HealthcareApis
az provider register --namespace Microsoft.Diagnostics
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Web

# Checking registration status
az provider show --namespace Microsoft.Network
az provider show --namespace Microsoft.Compute
az provider show --namespace Microsoft.ContainerInstance
az provider show --namespace Microsoft.KeyVault
az provider show --namespace Microsoft.ManagedIdentity
az provider show --namespace Microsoft.Storage
az provider show --namespace Microsoft.HealthcareApis
az provider show --namespace Microsoft.Diagnostics
az provider show --namespace Microsoft.ContainerRegistry
az provider show --namespace Microsoft.Web

# To see the resource types for a resource provider
az provider show --namespace Microsoft.Network --query "resourceTypes[*].resourceType" --out table
az provider show --namespace Microsoft.Compute --query "resourceTypes[*].resourceType" --out table
az provider show --namespace Microsoft.ContainerInstance --query "resourceTypes[*].resourceType" --out table
az provider show --namespace Microsoft.KeyVault --query "resourceTypes[*].resourceType" --out table
az provider show --namespace Microsoft.ManagedIdentity --query "resourceTypes[*].resourceType" --out table
az provider show --namespace Microsoft.Storage --query "resourceTypes[*].resourceType" --out table
az provider show --namespace Microsoft.HealthcareApis --query "resourceTypes[*].resourceType" --out table
az provider show --namespace Microsoft.Diagnostics --query "resourceTypes[*].resourceType" --out table
az provider show --namespace Microsoft.ContainerRegistry --query "resourceTypes[*].resourceType" --out table
az provider show --namespace Microsoft.Web --query "resourceTypes[*].resourceType" --out table


# AZ CLI
# 01-Network-Hub
# *** The JumpBox VM User Name and Password will be auto generated and will be saved at the Key Vault under HUB Resource Group
# You have to give yourself access in order to read the both Secrets with username and password
az deployment sub create -n "ESLZ-HUB-AHDS" -l "EastUS" -f 01-Network-Hub/main.bicep -p 01-Network-Hub/parameters-main.json
az deployment sub create -n "ESLZ-AHDS-HUB-UDR" -l "EastUS" -f 01-Network-Hub/updateUDR.bicep -p 01-Network-Hub/parameters-updateUDR.json
az deployment sub create -n "ESLZ-HUB-VM" -l "EastUS" -f 01-Network-Hub/deploy-vm.bicep -p 01-Network-Hub/parameters-deploy-vm.json

# 02-Network-LZ
# Bash
rgSpoke=ESLZ-AHDS-SPOKE
# Powershell
$rgSpoke="ESLZ-AHDS-SPOKE"
az deployment sub create -n "ESLZ-Spoke-AHDS" -l "EastUS" -f 02-Network-LZ/main.bicep -p 02-Network-LZ/parameters-main.json -p rgName=$rgSpoke

# 03-AHDS
# ** Important Note ** Review (or Update) 03-AHDS/parameters-main.json file to make sure APIMName on line 36 is globally unique and not used by any one else 
# ** and that APIM name should match Application Gateway backend pool value (primaryBackendEndFQDN) on line 81.
az deployment sub create -n "ESLZ-AHDS" -l "EastUS" -f 03-AHDS/main.bicep -p 03-AHDS/parameters-main.json -p rgName=$rgSpoke

# Victor ToDo: Prompt for Region and Application Gateway FQDN
# Victor ToDo: Print the Public IP of the Application Gateway and add a statement saying they must create a DNS record for this IP


# Full Cleanup
# Delete Resource Groups
# az group delete -n ESLZ-AHDS-HUB -y --no-wait
# az group delete -n ESLZ-AHDS-SPOKE -y --no-wait
# az apim deletedservice purge --service-name APIM-AHDS --location EastUS
# # Delete Deployments
# az deployment sub delete -n ESLZ-HUB-AHDS -y --no-wait
# az deployment sub delete -n ESLZ-AHDS-HUB-UDR --no-wait
# az deployment sub delete -n ESLZ-HUB-VM --no-wait
# az deployment sub delete -n ESLZ-Spoke-AHDS --no-wait
# az deployment sub delete -n ESLZ-AHDS-Supporting --no-wait