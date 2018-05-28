Find-AzureRmResource -ResourceGroupNameEquals "RG-PackerTest" | `
    where { $_.resourcetype -ne "Microsoft.Compute/images"} | `
    % { Remove-AzureRmResource -ResourceId $_.resourceid -Force }