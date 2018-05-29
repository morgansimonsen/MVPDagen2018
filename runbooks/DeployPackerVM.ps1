$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$uri = "https://outlook.office.com/webhook/aece0949-c7b2-48a5-9dc2-f4351e5dc925@8fec7cb8-30e7-4d8a-98ae-6e64853af4a3/IncomingWebhook/59a5ebb5dd7f4741bd0e9f515169f776/e64f54d5-1068-453c-9772-b1d403cce6fb"
$vmName = "ls-srv-"+ -join ((48..57) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$PackerImageName = "ws1709-2018-05-23-233900"

$body = ConvertTo-Json -Depth 4 @{
    title = 'New Deployment Notification'
    text = "A VM deployment was started..."
    sections = @(
        @{
            activityTitle = 'Deployment'
            activitySubtitle = 'MVP Dagen 2018'
            activityText = 'A change was evaluated and new results are available.'
            activityImage = 'https://applets.imgix.net/https%3A%2F%2Fassets.ifttt.com%2Fimages%2Fchannels%2F95451298%2Ficons%2Fon_color_large.png%3Fversion%3D0?ixlib=rails-2.1.3&w=240&h=240&auto=compress&s=c19887ddbffbcd296b7c3b37abcd9891'
        },
        @{
            title = 'Details'
            facts = @(
                @{
                name = 'VM Name'
                value = $vmName
                },
                @{
                name = 'Packer image'
                value = $PackerImageName
                }
            )
        }
    )
}


Invoke-RestMethod -uri $uri -Method Post -body $body -ContentType 'application/json'

$secpasswd = ConvertTo-SecureString "VeryStrongP@ssw0rd!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("localadmin", $secpasswd)

# Variables for common values
$resourceGroup = "RG-PackerTest"
$location = "westeurope"
$PackerImageId = "/subscriptions/3cf46281-f639-44bc-a338-11697697bb2a/resourceGroups/RG-PackerTest/providers/Microsoft.Compute/images/ws1709-2018-05-23-233900"
$image = Get-AzureRmImage -ResourceGroupName $resourceGroup -ImageName $PackerImageName
$vmName = "ls-srv-"+ -join ((48..57) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$vmSize = "Standard_D2s_v3"
$subnetId = "/subscriptions/3cf46281-f639-44bc-a338-11697697bb2a/resourceGroups/LangskipNetwork/providers/Microsoft.Network/virtualNetworks/vNet-Langskip-WE/subnets/Servers-Static"

Write-Output ("Creating VM: "+$vmName)

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name ("NIC-"+$vmName ) -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $subnetId

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred | `
Set-AzureRmVMSourceImage -Id $image.Id | `
Add-AzureRmVMNetworkInterface -Id $nic.Id

# Create a virtual machine
New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig

# Configure WinRM Trusted hosts
Set-AzureRmVMCustomScriptExtension -ResourceGroupName $resourceGroup `
    -VMName $vmName `
    -Location $location `
    -FileUri "https://raw.githubusercontent.com/morgansimonsen/MVPDagen2018/master/wac/Enable-WACRemoteManagementAzureVM.ps1" `
    -Run "powershell.exe -ExecutionPolicy Unrestricted -file Enable-WACRemoteManagementAzureVM.ps1" `
    -Name "WinRMScriptExtension"
