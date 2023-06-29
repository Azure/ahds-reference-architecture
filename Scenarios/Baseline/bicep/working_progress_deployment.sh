#!/bin/bash

###################
# Prompt and Validating Azure Region
###################
read -p "Inform Azure Region to be deployed? " answerAzRegion
azRegions=$(az account list-locations --query '[].name' -o tsv)
if [[ $azRegions == *$answerAzRegion* ]]; then
  echo "Azure Region found: $answerAzRegion"
else
  echo "Region $answerAzRegion Not found"
  echo ""
  echo "Use one of the available Azure Regions:"
  echo $azRegions
  exit;
fi

###################
# Prompt Azure Aplication Gateway FQDN
###################
read -p "Inform Azure Application Gateway FQDN? " answerAppGWFQDN
echo "Azure Aplication Gateway FQDN: $answerAppGWFQDN"

###################
# List of required azure providers
###################
azProviders=("Microsoft.Network" "Microsoft.Compute" "Microsoft.ContainerInstance" "Microsoft.KeyVault" "Microsoft.ManagedIdentity" "Microsoft.Storage" "Microsoft.HealthcareApis" "Microsoft.Diagnostics" "Microsoft.ContainerRegistry" "Microsoft.Web")

###################
# Checking if a required provider is not registered and save in array azProvidersNotRegistered
###################
azProvidersNotRegistered=()
for provider in "${azProviders[@]}"
do
  registrationState=$(az provider show --namespace $provider --query "[registrationState]" --output tsv)
  if [ "$registrationState" != "Registered" ]; then
    #echo "Found an Azure Resource Provider not registred: $provider"
    azProvidersNotRegistered+=($provider)
    #echo "${azProvidersNotRegistered[@]}"
  fi
done

###################
# Registering all missing required Azure providers
###################
if (( ${#azProvidersNotRegistered[@]} > 0 )); then
  echo "Registering required Azure Providers"
  echo ""
  for provider in "${azProvidersNotRegistered[@]}"
  do
    echo "Registering Azure Provider: $provider"
    az provider register --namespace $provider
  done
fi
echo ""

###################
# Function to remove an element of an array
###################
remove_array_element_byname(){
    index=0
    name=$1[@]
    param2=$2
    fun_arr=("${!name}")

    for element in "${fun_arr[@]}"
    do
      if [[ $element == $param2 ]]; then
        foundindex=$index
      fi
      index=$(($index + 1))
    done
    unset fun_arr[$foundindex]
    ret_val=("${fun_arr[@]}")
}

###################
# Checking the status of missing Azure Providers
###################
if (( ${#azProvidersNotRegistered[@]} > 0 )); then
  copy_azProvidersNotRegistered=("${azProvidersNotRegistered[@]}")
  while (( ${#copy_azProvidersNotRegistered[@]} > 0 ))
  do
    elementcount=0
    for provider in "${azProvidersNotRegistered[@]}"
    do
      registrationState=$(az provider show --namespace $provider --query "[registrationState]" --output tsv)
      if [ "$registrationState" != "Registered" ]; then
        echo "Waiting for Azure provider $provider ..."
      else
        echo "Azure provider $provider registered!"
        remove_array_element_byname copy_azProvidersNotRegistered $provider
        ret_remove_array_element_byname=("${ret_val[@]}")
        copy_azProvidersNotRegistered=("${ret_remove_array_element_byname[@]}")
      fi
    done
    azProvidersNotRegistered=("${copy_azProvidersNotRegistered[@]}")
    echo ""

    echo "Amount of providers waiting to be registered: ${#azProvidersNotRegistered[@]}"
    echo "Waiting 10 seconds to check the missing providers again"
    echo "############################################################"
    sleep 10
    clear
  done
  echo "Done registering required Azure Providers"
fi

# End of working part
#=======================================================================

######################################################
######################################################
######################################################
#### From this part bellow is working in progress ####
######################################################
######################################################
######################################################

# AZ CLI
# 01-Network-Hub
# *** The JumpBox VM User Name and Password will be auto generated and will be saved at the Key Vault under HUB Resource Group
# You have to give yourself access in order to read the both Secrets with username and password
az deployment sub create -n "ESLZ-HUB-AHDS" -l $answerAzRegion -f 01-Network-Hub/main.bicep -p 01-Network-Hub/parameters-main.json
az deployment sub create -n "ESLZ-AHDS-HUB-UDR" -l $answerAzRegion -f 01-Network-Hub/updateUDR.bicep -p 01-Network-Hub/parameters-updateUDR.json
az deployment sub create -n "ESLZ-HUB-VM" -l $answerAzRegion -f 01-Network-Hub/deploy-vm.bicep -p 01-Network-Hub/parameters-deploy-vm.json

# 02-Network-LZ
rgSpoke=ESLZ-AHDS-SPOKE
az deployment sub create -n "ESLZ-Spoke-AHDS" -l $answerAzRegion -f 02-Network-LZ/main.bicep -p 02-Network-LZ/parameters-main.json -p rgName=$rgSpoke

# 03-AHDS
# ** Important Note ** Review (or Update) 03-AHDS/parameters-main.json file to make sure APIMName on line 36 is globally unique and not used by any one else
# ** and that APIM name should match Application Gateway backend pool value (primaryBackendEndFQDN) on line 81.
# az deployment group create -g "ESLZ-HUB" -n "test-public-ip" -f test.bicep --query "properties.outputs.publicipappgw.value" -o tsv
publicipappgw=$(az deployment sub create -n "ESLZ-AHDS" -l $answerAzRegion -f 03-AHDS/main.bicep -p 03-AHDS/parameters-main.json -p rgName=$rgSpoke -p appGatewayFQDN=$answerAppGWFQDN --query "properties.outputs.publicipappgw.value" -o tsv)
echo "Please create a DNS record for the Application Gateway Public IP: $publicipappgw with the FQDN: $answerAppGWFQDN"

# Victor ToDo: Prompt for Region and Application Gateway FQDN - Done
# Victor ToDo: Print the Public IP of the Application Gateway and add a statement saying they must create a DNS record for this IP

echo Done