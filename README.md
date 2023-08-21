# Azure Health Data Services Reference Architecture

This repo provides reference architecture and reference implementation on how to deploy Azure Health Data Services securely on Azure and integrate with various Azure services.

![ahds reference architecture](./docs/media/ahds-reference-architecture.png)

### Getting Started

- Clone the repo

  ```sh
  git clone https://github.com/Azure/ahds-reference-architecture
  ```

- Optionally open the cloned repo folder in Visual Studio Code to review all the "parameters-\*" files under three folders (01-Network-Hub, 02-Network-LZ & 03-AHDS) to review the values and change as needed per your environment.

  - For example under 01-Network-Hub folder you have following three "parameters-\*" files, make sure to review and update them as needed.

    - parameters-deploy-vm.json
    - parameters-main.json
    - parameters-updateUDR.json

  - By default the script will auto generate a self-signed certificate for the domain name and will upload it to KeyVault. If you already have a certificate, you can upload it to folder 03-ADHS/modules/vnet/certs/ with the name appgw.pfx and update the parameter appGatewayCertType to _custom_ at 03-ADHS/parameters-main.json accordingly.

- Using Visual Studio Code review and change "deployment.sh" file under "Scenarios/Baseline/bicep" folder. For example, change Names and Azure Region as needed.
  <br/>

- Make sure you login to Azure

  ```sh
   az login
  ```

- To start the deployment execute the _deployment.sh_ file from terminal. Or _deployment.azcli_ can be opened in Visual Studio Code and executed line by line as well.
  ```sh
   ./Scenarios/Baseline/bicep/deployment.sh
  ```
- Make sure to update the DNS record for the domain name to point to the public IP address of the Application Gateway. You can find the public IP address of the Application Gateway from the output of the deployment script or from Azure Portal.

### Testing

Once the reference architecture deployed successfully you can test the solution for individual (single file) FHIR message flow using Postman.

- Visit another page and follow the instructions for setting up Postman
- Make API calls to test FHIR service using Postman

To begin, CTRL+click (Windows or Linux) or CMD+click (Mac) on the link below to open a Postman tutorial in a new browser tab.

[Postman Setup Tutorial](https://github.com/microsoft/azure-health-data-services-workshop/blob/main/resources/docs/Postman_FHIR_service_README.md)

- Please note that the fhirurl should be https://{yourdomainname}/fhir and the resource url should be the FHIR service endpoint as in the document.
- You also need to additionally set the APIM subscription key in the header. You can find the APIM subscription key from the _Subscriptions_ blade of the deployed APIM instance. You can use the Built-in all-access subscription key for testing purpose. Set this subscription key as a header with key _Ocp-Apim-Subscription-Key_ in Postman.

To test **bulk upload** functionality, you can use the sample data provided in the [workshop](https://github.com/microsoft/azure-health-data-services-workshop/tree/main/Challenge-03%20-%20Ingest%20to%20FHIR/samples).

- Grant the Postman service client app created for the previous testing, _Storage Blob Data Contributor_ role on the storage account.
- Import the storage environment file from the [here](/Testing/bulk-load-fhir-storage.postman_environment.json) and the collection from [here](/Testing/bulk-load-fhir-storage.postman_collection.json) into Postman.
- Update the environment variables with the values used for the previous testing for the client app.
  - The resource parameter should be the url of the storage account, for example https://eslzxxxxx.blob.core.windows.net
  - The storageurl parameters should be the domain name for application gateway, for example https://{yourdomainname}
- Run the AuthorizeGetToken api first to retrieve the bearer token
- Upload the file by selecting the Body tab in Postman for the Put Blob request, select binary in the radio list and select the good_bundles.zip file to upload.

### Cleanup

- Review and make necessary changes to the _cleanup.sh_ file under "Scenarios/Baseline/bicep" folder. For example, change resource group names, API Management name and Azure deployment names as needed.
- To delete all the resources execute the _cleanup.sh_ file under "Scenarios/Baseline/bicep" folder
  ```sh
   ./Scenarios/Baseline/bicep/cleanup.sh
  ```
