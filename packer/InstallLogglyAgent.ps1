# InstallLogglyAgent.ps1
# Morgan Simonsen
# Install Loggly agent
# v0.1


[CmdletBinding(
)]
Param(
)

# User changeable variables
$packageName = "Loggly Agent"
$LogglyAgentInstallerDestinationFolder = "C:\Windows\Temp"
$LogglyAgentInstallerSourceURL = "https://nxlog.co/system/files/products/files/348/nxlog-ce-2.10.2102.msi"
$LogglyAgentInstallerFileBaseName = $LogglyAgentInstallerSourceURL.Substring($LogglyAgentInstallerSourceURL.LastIndexOf("/") + 1)
$LogglyAgentInstallerFileFullName = Join-Path -Path $LogglyAgentInstallerDestinationFolder -ChildPath $LogglyagentInstallerFileBaseName
$LogglyAgentMasterConfigFileName = "nxlog.conf.temp"
$LogglyAgentConfigFileName = "C:\Program Files (x86)\nxlog\conf\nxlog.conf"

Write-Output "Downloading $packageName..."
# Set up TLS 1.2 support
[Net.ServicePointManager]::SecurityProtocol = 
  [Net.SecurityProtocolType]::Tls12 -bor `
  [Net.SecurityProtocolType]::Tls11 -bor `
  [Net.SecurityProtocolType]::Tls

Invoke-WebRequest -Uri $LogglyAgentInstallerSourceURL `
                    -OutFile ( Join-Path -Path $LogglyAgentInstallerDestinationFolder -ChildPath $LogglyAgentInstallerFileBaseName )

Write-Output "Success: $?"
get-childitem $LogglyAgentInstallerDestinationFolder

Write-Output "Installing $packageName..."
$DataStamp = get-date -Format yyyyMMddTHHmmss
$logFile = '{0}-{1}.log' -f $LogglyAgentInstallerFileFullName,$DataStamp
$MSIArguments = @(
    "/i"
    ('"{0}"' -f $LogglyAgentInstallerFileFullName)
    "/quiet"
    "/norestart"
    "/L*v"
    $logFile
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow 

Get-Content -Path $logFile | Write-Verbose

Write-Output "Configure $packageName..."
# Stop package service and set it to manual statup mode
# we set it to automatic when we provision the instance
$LogglyagentServices = Get-Service -Include "*Loggly*"
ForEach ( $LogglyagentService in $LogglyagentServices)
{
    Write-Output ("Name of service is: "+$LogglyagentService.name)
    Stop-Service -Name $LogglyagentService.Name -Force
    Set-Service -Name $LogglyagentService.Name -StartupType Manual
}
# configure
Copy-Item -Path (Join-Path -Path $LogglyAgentInstallerDestinationFolder -ChildPath $LogglyAgentMasterConfigFileName) -Destination $LogglyAgentConfigFileName -Force