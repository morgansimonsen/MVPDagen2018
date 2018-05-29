<#
Install-WAC.ps1
Morgan Simonsen
#>

Import-PfxCertificate -Exportable:$true -FilePath c:\windows\temp\ls-wac1.pfx -CertStoreLocation Cert:\LocalMachine\My -Password (Get-Credential).password

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