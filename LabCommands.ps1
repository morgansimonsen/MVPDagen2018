# Download WAC
Start-BitsTransfer -Source "http://download.microsoft.com/download/1/0/5/1059800B-F375-451C-B37E-758FFC7C8C8B/WindowsAdminCenter1804.25.msi"
# Import cert
Import-PfxCertificate -FilePath C:\Users\Administrator.HOME-HYPERV1\Downloads\home-hyperv1.pfx `
                        -Exportable -Password ((Get-Credential).password) `
                        -CertStoreLocation Cert:\LocalMachine\My
# Install WAC
msiexec /i WindowsAdminCenter1804.25.msi /qn /L*v log.txt SME_PORT=6516 SME_THUMBPRINT=72245DF7DE63A2280856164BBDFE027E2EFBECD6 SSL_CERTIFICATE_OPTION=installed

# debug
# turn off firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
