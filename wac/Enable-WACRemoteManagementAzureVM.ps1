<#
These steps are necessary to allow WAC to connect to and manage an Azure IaaS VM
#>
winrm quickconfig -quiet -force
Set-Item WSMan:localhost\Client\TrustedHosts -Value '10.1.0.4,ls-wac1.langskip.no,ls-wac1' -Force