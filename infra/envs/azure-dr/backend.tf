terraform {
  backend "azurerm" {
    storage_account_name = "stpetclinicdrtfstate"
    container_name       = "tfstate"
    key                  = "petclinic/azure-dr/terraform.tfstate"
    use_azuread_auth     = true
  }
}
