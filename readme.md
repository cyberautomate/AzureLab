## My Azure Lab ##

- [My Azure Lab](#my-azure-lab)

- All infrastructure built in Azure will be built using Bicep. If you're not aware of Bicep, start here: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/

Deploy the Keyvault
```.\deploy-keyvault.ps1 -ResourceGroupName HUB -Location westus2 -ParameterFile ./parameters/keyvault.dev.parameters.json -ShowParameters```