# This script is called from the Send-Email function to instaniate the $Images variable
# In the function's scope. The following command tells PSScriptAnalyzer to suppress the rule.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments','')]

$Images = @{
    
}