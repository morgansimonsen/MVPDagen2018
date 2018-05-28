<#
Install-WAC.ps1
Morgan Simonsen
#>

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
    "SME_PORT=6516"
    "SSL_CERTIFICATE_OPTION=generate"
    "/L*v"
    $logFile
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow 
