plugin "azurerm" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

config {
  # Lint referenced local modules as well as the root module.
  call_module_type = "all"
}
