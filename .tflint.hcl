# tflint configuration.
#
# Kept deliberately small: the bundled ruleset catches real errors and unused
# declarations. Rules that are style preference, not correctness, are left off
# so the gate fails on things that matter and not on taste.

config {
  format = "compact"
  call_module_type = "local"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}
