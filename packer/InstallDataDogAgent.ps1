# InstallDataDogAgent.ps1
# Morgan Simonsen
# Install DataDog agent
# v0.1


[CmdletBinding(
)]
Param(
)

# User changeable variables
$packageName = "DataDog Agent"
$dataDogAgentInstallerDestinationFolder = "C:\Windows\Temp"
$dataDogAgentInstallerSourceURL = "https://s3.amazonaws.com/ddagent-windows-stable/datadog-agent-6-latest.amd64.msi"
$dataDogAgentInstallerFileBaseName = $dataDogAgentInstallerSourceURL.Substring($dataDogAgentInstallerSourceURL.LastIndexOf("/") + 1)
$dataDogAgentInstallerFileFullName = Join-Path -Path $dataDogAgentInstallerDestinationFolder -ChildPath $datadogagentInstallerFileBaseName

Write-Output "Downloading $packageName..."
# Set up TLS 1.2 support
[Net.ServicePointManager]::SecurityProtocol = 
  [Net.SecurityProtocolType]::Tls12 -bor `
  [Net.SecurityProtocolType]::Tls11 -bor `
  [Net.SecurityProtocolType]::Tls

Invoke-WebRequest -Uri $dataDogAgentInstallerSourceURL `
                    -OutFile ( Join-Path -Path $dataDogAgentInstallerDestinationFolder -ChildPath $dataDogAgentInstallerFileBaseName )

Write-Output "Success: $?"
get-childitem $dataDogAgentInstallerDestinationFolder

Write-Output "Installing $packageName..."
$DataStamp = get-date -Format yyyyMMddTHHmmss
$logFile = '{0}-{1}.log' -f $dataDogAgentInstallerFileFullName,$DataStamp
$MSIArguments = @(
    "/i"
    ('"{0}"' -f $dataDogAgentInstallerFileFullName)
    "/qn"
    "/norestart"
    "APIKEY=e8fd5deabfec60c6179b8508df68b5ee"
    "/L*v"
    $logFile
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow 

Get-Content -Path $logFile | Write-Verbose

Write-Output "Configure $packageName..."
# Stop package service and set it to manual statup mode
# we set it to automatic when we provision the instance
$datadogagentServices = Get-Service -Include "*datadog*"
ForEach ( $datadogagentService in $datadogagentServices)
{
    Write-Output ("Name of service is: "+$datadogagentService.name)
    Stop-Service -Name $datadogagentService.Name -Force
    Set-Service -Name $datadogagentService.Name -StartupType Manual
}
# enable process config
Add-Content -Path (Join-path $env:programdata "Datadog\datadog.yaml") -Value "`r`nprocess_config:`r`n  enabled: true"