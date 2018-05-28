# InstallOpenSSH-Win.ps1
# Morgan Simonsen
# Install the Windows port of OpenSSH
# https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH
# https://www.server-world.info/en/note?os=Windows_Server_2016&p=openssh

[CmdletBinding(
)]
Param(
)

# User changeable variables
$packageName = "OpenSSH"
$OpenSSHDirectoryName = "OpenSSH" #What to rename the OpenSSH folder to once it is extracted
$OpenSSHArchiveSourceFolder = "install-media/" #The S3 bucket folder where the archive is copied from
$OpenSSHArchiveDestinationFolder = "C:\Windows\Temp" #Where the archive is downloaded to
$OpenSSHArchiveSourceURL = "https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.6.1.0p1-Beta/OpenSSH-Win64.zip"


$OpenSSHArchiveFilename = $OpenSSHArchiveSourceURL.Substring($OpenSSHArchiveSourceURL.LastIndexOf("/") + 1)

# Copy archive from S3 bucket
Write-Output "Downloading $packageName..."
#Copy-S3Object -BucketName "nbim-t-s3-eu-west-1-files" `
#                -Key ($OpenSSHArchiveSourceFolder+$OpenSSHArchiveFilename) `
#                -LocalFile (Join-Path -Path $OpenSSHArchiveDestinationFolder -ChildPath $OpenSSHArchiveFilename) `
#                -Region "eu-west-1"

#aws s3 cp s3://nbim-t-s3-eu-west-1-files/install-media/OpenSSH-Win64.zip C:\Windows\Temp\OpenSSH-Win64.zip

# BITS does not work when running in an elevated prompt like Packer starts
# Throws error:
# Start-BitsTransfer : The operation being requested was not performed because the user has not logged on to the network.
# The specified service does not exist. (Exception from HRESULT: 0x800704DD)
#Start-BitsTransfer -Source $OpenSSHArchiveSourceURL -Destination $OpenSSHArchiveDestinationFolder
# Set up TLS 1.2 support
[Net.ServicePointManager]::SecurityProtocol = 
  [Net.SecurityProtocolType]::Tls12 -bor `
  [Net.SecurityProtocolType]::Tls11 -bor `
  [Net.SecurityProtocolType]::Tls

Invoke-WebRequest -Uri $OpenSSHArchiveSourceURL `
                    -OutFile (Join-Path -Path $OpenSSHArchiveDestinationFolder -ChildPath $OpenSSHArchiveFilename)

Write-Output "Success: $?"
get-childitem $OpenSSHArchiveDestinationFolder

Write-Output "Installing $packageName..."

# Test for ZIP archive
If (!(Test-Path -Path (Join-Path -Path $OpenSSHArchiveDestinationFolder -ChildPath $OpenSSHArchiveFilename) ))
{
    Write-Output "Source archive not found!"
    Write-Output "Exiting..."
    Exit
}

# Expand binaries
Expand-Archive -Path (Join-Path -Path $OpenSSHArchiveDestinationFolder -ChildPath $OpenSSHArchiveFilename) -DestinationPath $env:ProgramFiles 
# Rename folder
Rename-Item -Path $env:ProgramFiles\OpenSSH-Win64 -NewName $OpenSSHDirectoryName
# Execute installer
& $env:ProgramFiles\$OpenSSHDirectoryName\install-sshd.ps1

Write-Output "Configure $packageName..."
# Set service to manual
Set-Service -Name sshd -StartupType Manual

# Add SSH firewall rule
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -Program "%ProgramFiles%\$OpenSSHDirectoryName\sshd.exe"
# Configure default ssh shell
New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -ErrorAction SilentlyContinue
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" -Value "c:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Force
