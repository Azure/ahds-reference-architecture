# Full Cleanup
# Delete Resource Groups
az group delete -n ESLZ-AHDS-HUB -y --no-wait
az group delete -n ESLZ-AHDS-SPOKE -y --no-wait
# Make sure you get the right APIM and replace it
az apim deletedservice purge --service-name APIM-AHDS --location EastUS
# Delete Deployments
az deployment sub delete -n ESLZ-HUB-AHDS -y --no-wait
az deployment sub delete -n ESLZ-AHDS-HUB-UDR --no-wait
az deployment sub delete -n ESLZ-HUB-VM --no-wait
az deployment sub delete -n ESLZ-Spoke-AHDS --no-wait
az deployment sub delete -n ESLZ-AHDS-Supporting --no-wait