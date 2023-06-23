#!/bin/bash

# This part was tested and it's working fine
# read -p "Inform Azure Region to be deployed? " answerAzRegion
# azRegions=$(az account list-locations --query '[].name' -o tsv)
# if [[ $azRegions == *$answerAzRegion* ]]; then
#   echo "Azure Region found: $answerAzRegion"
# else
#   echo "Region $answerAzRegion Not found"
#   echo ""
#   echo "Use one of the available Azure Regions:"
#   echo $azRegions
#   exit;
# fi

# read -p "Inform Azure Application Gateway FQDN? " answerAppGWFQDN
# echo "Azure Aplication Gateway FQDN: $answerAppGWFQDN"

# End of working part
#=======================================================================


##################################
# From this part bellow is working in progress
##################################


# List of required azure providers
azProviders=("Microsoft.Network" "Microsoft.Compute" "Microsoft.ContainerInstance" "Microsoft.KeyVault" "Microsoft.ManagedIdentity" "Microsoft.Storage" "Microsoft.HealthcareApis" "Microsoft.Diagnostics" "Microsoft.ContainerRegistry" "Microsoft.Web")

# Checking if a required provider is not registered and save in array azProvidersNotRegistered
azProvidersNotRegistered=()
for provider in "${azProviders[@]}"
do
  registrationState=$(az provider show --namespace $provider --query "[registrationState]" --output tsv)
  if [ "$registrationState" != "Registered" ]; then
    echo "Found an Azure Resource Provider not registred: $provider"
    $azProvidersNotRegistered+=(provider)
  fi
done

# Registering all missing required Azure providers
if (( ${#azProvidersNotRegistered[@]} > 0 )); then
  echo "Registering required Azure Providers"
  for provider in "${azProvidersNotRegistered[@]}"
  do
    echo "Registering Azure Provider: $provider"
    az provider register --namespace $provider
  done
fi

# Checking the status of missing Azure Providers
if (( ${#azProvidersNotRegistered[@]} > 0 )); then
  while [ ${#azProvidersNotRegistered[@]} > 0 ]
  do
    for provider in "${azProvidersNotRegistered[@]}"
    do
      registrationState=$(az provider show --namespace $provider --query "[registrationState]" --output tsv)
      if [ "$registrationState" != "Registered" ]; then
        echo "Waiting for Azure provider $provider to be registered!"
      else
        echo "Azure provider $provider registered!"

        # Removing element that was already registered from array
        # Possible Bug: Need to check if it would cause a buffer overflow
        #               since I'm changing the element that's been used by the for loop.
        for elementProvider in "${azProvidersNotRegistered[@]}";
        do
          if [[ "${azProvidersNotRegistered[$elementProvider]}" == "${provider}" ]]; then
            unset azProvidersNotRegistered[$elementProvider]
          fi
        done
      fi
    done
    echo "Waiting 10 seconds to check the missing providers again"
    sleep 10
  done
  echo "Done registering required Azure Providers"
fi

echo Done