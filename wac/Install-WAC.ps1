<#
Install-WAC.ps1
Morgan Simonsen
#>

# start transcript
$WindowsTempFolder = Join-Path -Path $env:SystemRoot -ChildPath "temp"
Start-Transcript -Path (Join-Path -Path $env:SystemRoot -ChildPath "\temp\wacinstall.log" )

# temp folder
$WACInstallerDestinationFolder = $WindowsTempFolder

# install azure modules
Get-PackageProvider -Name NuGet -ForceBootstrap #Bootstrap NuGet
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted #Set PSGallery as trusted repo
Install-Module -Name AzureRM

# get password from KV
$response = Invoke-WebRequest -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net&client_id=81af743d-f80b-4e47-931d-6ecb9187db85" `
                              -Headers @{Metadata="true"} -UseBasicParsing
$content =$response.Content | ConvertFrom-Json
$KeyVaultToken = $content.access_token
$kvsecret = (Invoke-WebRequest -Uri "https://wac-kv.vault.azure.net/secrets/pfxpassword?api-version=2016-10-01" -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"} -UseBasicParsing).content
$pfxpassword = ($kvsecret | ConvertFrom-Json).value

# import certificate
$secpasswd = ConvertTo-SecureString $pfxpassword -AsPlainText -Force
$pfxcreds = New-Object System.Management.Automation.PSCredential ("foo", $secpasswd)
Start-BitsTransfer -Source "https://github.com/morgansimonsen/MVPDagen2018/raw/master/wac/ls-wac1.pfx" -Destination $WACInstallerDestinationFolder
Import-PfxCertificate -Exportable:$true -FilePath c:\windows\temp\ls-wac1.pfx -CertStoreLocation Cert:\LocalMachine\My -Password $pfxcreds.password

# install net fw
$netfwdownloadurl = "https://download.microsoft.com/download/3/3/2/332D9665-37D5-467A-84E1-D07101375B8C/NDP472-KB4054531-Web.exe"
$netfwInstallerFileBaseName = $netfwdownloadurl.Substring($netfwdownloadurl.LastIndexOf("/") + 1)
$netfwInstallerFileFullName = Join-Path -Path $WACInstallerDestinationFolder -ChildPath $netfwInstallerFileBaseName
Start-BitsTransfer -Source $netfwdownloadurl -Destination $WACInstallerDestinationFolder
Start-Process -FilePath $netfwInstallerFileFullName -ArgumentList "/q /norestart" -Wait

$WACInstallerDestinationFolder = "c:\windows\temp"
$WACDownloadUrl = "http://download.microsoft.com/download/1/0/5/1059800B-F375-451C-B37E-758FFC7C8C8B/WindowsAdminCenter1804.25.msi"
$WACInstallerFileBaseName = $WACDownloadUrl.Substring($WACDownloadUrl.LastIndexOf("/") + 1)
$WACInstallerFileFullName = Join-Path -Path $WACInstallerDestinationFolder -ChildPath $WACInstallerFileBaseName
Start-BitsTransfer -Source $WACDownloadUrl -Destination $WACInstallerDestinationFolder

$DataStamp = get-date -Format yyyyMMddTHHmmss
$logFile = '{0}-{1}.log' -f $WACInstallerFileFullName,$DataStamp
$MSIArguments = @(
    "/i"
    ('"{0}"' -f $WACInstallerFileFullName)
    "/qn"
    "/norestart"
    "SME_PORT=443"
    "SSL_CERTIFICATE_OPTION=installed"
    "SME_THUMBPRINT=27A14CE6E5CDA0583C71EB99EC306A53FA46778A"
    "/L*v"
    $logFile
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow 

Add-WindowsFeature -Name RSAT-Storage-Replica

Stop-Transcript