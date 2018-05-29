#File: New-AadApp.ps1
#Copyright (c) Microsoft Corp 2017.

<#

.SYNOPSIS
Creates a web app in AAD and registers it with the SME gateway.

.DESCRIPTION
Create a web application in Azure AD with the name "SME-<gateway>" (if one does not already exist) and add the application settings to Windows Admin Center to enable Azure connectivity.

This script requires internet connectivity.

Upon completion, the script will return the tenant ID where the app was created as well as the web app client ID.

This script depends on 2 powershell modules: Azure RM Resources and Azure AD. To get them execute the 2 following commands:

PS C:\>Install-Module AzureRM.Resources
PS C:\>Install-Module AzureAD

.PARAMETER GatewayEndpoint
Required
Provide the gateway name

.PARAMETER ExistingAadApp
Optional
If you've already created an AAD application registered to your tenant with the appropriate permissions, you can specify the app name. This prevents the script from creating a new AAD app. This script also assumes that the service principal associated with the application is of the same name. If the service principal with the same name does not exist, the script will create a new service principal with the same name as the ExistingAadApp.

.PARAMETER TenantId
Optional
If your account is associated with multiple tenants, specify the tenant ID with this parameter. Otherwise, the script will use the default tenant.

.PARAMETER Credential
Optional
If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.EXAMPLE
.\New-AadApp.ps1 -GatewayEndpoint "https://gateway.contoso.com" 
.\New-AadApp.ps1 -GatewayEndpoint "https://gateway.contoso.com" -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
.\New-AadApp.ps1 -GatewayEndpoint "https://gateway.contoso.com" -ExistingAadApp "SME-AadApp"
.\New-AadApp.ps1 -GatewayEndpoint "https://gateway.diffDomain.com" -Credential usernameForDiffDomain

#>

#Requires -Version 4.0
#Requires -Modules @{ModuleName="AzureRM.Resources";ModuleVersion="3.5.0.0"}
#Requires -Modules @{ModuleName="AzureADPreview";ModuleVersion="2.0.1.2"}

#########################################################################################################> 

param(
    [Parameter(Mandatory = $true)]
    [String]
    $GatewayEndpoint,

    [Parameter(Mandatory = $false)]
    [String]
    $ExistingAadApp,

    [Parameter(Mandatory = $false)]
    [String]
    $TenantId,

    [Parameter(Mandatory = $false)]
    [pscredential]
    $Credential
)

# return access token with the resource ID pointing to AAD Graph endpoint
function Get-AadGraphApiToken
{
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $TenantName
    )
    $PowerShellClientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    $PowerShellRedirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $ResourceAppIdURI = "https://graph.windows.net"
    $Authority = "https://login.windows.net/$TenantName"

    # Microsoft.IdentityModel.Clients should be already loaded
    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $Authority
    $authResult = $authContext.AcquireToken($ResourceAppIdURI, $PowerShellClientId, $PowerShellRedirectUri, "Auto")

    return $authResult.AccessToken
}

###################
# Azure login & get tenant ID
###################

$azureAccount = Login-AzureRmAccount
if (!$azureAccount){
    $err = "Could not log in to Azure account"
    throw $err
}
if ($TenantId) {
    $tenant_id = $TenantId
} else {
   $tenant_id = $azureAccount.Context.Tenant.Id 
}

# now we need to login into AzureAD since it is using different token audience
$ad_tenant_info = $null
try {
    # check if we can get the tenant info, if we can then AzureAD has cached credentials
    # just continue to use them
    $ad_tenant_info = Get-AzureADTenantDetail -ErrorAction Continue
} catch
{
}

if (!$ad_tenant_info)
{
    #if no credentials were found then get the token from ADAL, usually it uses the cookie and will not prompt for credentials twice
    # since we already entered our credentials for Azure RM
    $ad_graph_api_token = Get-AadGraphApiToken $tenant_id

    #now pass this token to AzureAD powershell
    Connect-AzureAD -AadAccessToken $ad_graph_api_token -AccountId "1950a258-227b-4e31-a9cf-717495945fc2" -TenantId $tenant_id | Out-Null
}

###################
# Check if AAD app exists, if not create AAD App
###################

if ($ExistingAadApp) {
    # if ExsitingAadApp parameter provided, check for existence of the specified app
    $app_display_name = $ExistingAadApp
} else {
    # generate the display names for web app in AAD
    $app_display_name = "SME-$GatewayEndpoint"
}

$web_aad_app = Get-AzureRmADApplication -DisplayNameStartWith $app_display_name -Verbose
$service_principal = Get-AzureRmADServicePrincipal -SearchString $app_display_name

if (!$web_aad_app)
{
    if (!$ExistingAadApp) {
        # build redirect and reply URLs for AAD Application
        $redirect_url = "$GatewayEndpoint/"
        $reply_urls = "$GatewayEndpoint/*"

        Write-Output "Creating AAD Application $app_display_name ..."
        # get required resource access for the following Azure service principals
        $MsftWebApiSP = Get-AzureRmADServicePrincipal -SearchString "Windows Azure Service Management API"
        $AadSP = Get-AzureRmADServicePrincipal -SearchString "Windows Azure Active Directory"  
        
        $req1 = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
        ResourceAppId= $MsftWebApiSP.ApplicationId.Guid ;
        ResourceAccess=[Microsoft.Open.AzureAD.Model.ResourceAccess]@{
        Id = "41094075-9dad-400e-a0bd-54e686782033"; #access scope: Delegated permission to Access Azure Service Management as organization users 
        Type = "Scope"}} ;
        
        $req2 = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
        ResourceAppId= $AadSP.ApplicationId.Guid ;
        ResourceAccess=[Microsoft.Open.AzureAD.Model.ResourceAccess]@{
        Id = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"; #access scope: Delegated permission to sign in and read user profile
        Type = "Scope"}}

        $userAppRole= [Microsoft.Open.AzureAD.Model.AppRole]@{
        AllowedMemberTypes= [String[]] @("User");
        Description= "Gateway users can access and use the gateway, but not configure the gateway.";
        DisplayName= "Gateway User";
        Id= New-Guid;
        IsEnabled= "true";
        Value= "User"}

        $adminAppRole= [Microsoft.Open.AzureAD.Model.AppRole]@{
        AllowedMemberTypes= [String[]] @("User");
        Description= "Gateway administrators can modify gateway configurations.";
        DisplayName= "Gateway Administrator";
        Id= New-Guid;
        IsEnabled= "true";
        Value= "Admin"}

        $web_aad_app = New-AzureADApplication -DisplayName $app_display_name -AppRoles $userAppRole, $adminAppRole -IdentifierUris $redirect_url -ReplyUrls $reply_urls -GroupMembershipClaims "All" -Oauth2AllowImplicitFlow $true -RequiredResourceAccess $req1, $req2

        # re-fetch the client app after creation
        $web_aad_app = Get-AzureRmADApplication -DisplayNameStartWith $app_display_name -Verbose

        if (!$web_aad_app)
        {
            $err = "Cannot create application '$app_display_name' in Azure AD"
            throw $err
        } else {
            Write-Output "Successfully created AAD Application $app_display_name"
        }

        # we need to sleep for a while to make sure AAD is update
        Sleep 20
    } else {
        $err = "No AAD Application could be found named $ExistingAadApp. `
            Please re-run this script with a valid AAD App Name. `
            You can also re-run this script without the -ExistingAadApp `
            paramater to create a new AAD app."
        throw $err
    } 
} else {
    Write-Output "AAD Application already exists for $app_display_name. Application not created"
}

#Create Service Principal for AAD Applicaiton
if (!$service_principal) {
    $service_principal = New-AzureRmADServicePrincipal -ApplicationId $web_aad_app.ApplicationId.Guid
    if (!$service_principal) {
        $err = "Failed to create a service principal for '$app_display_name'"
        throw $err
    }
}

$client_id = $web_aad_app.ApplicationId.Guid.ToString()
$object_id = $service_principal.Id.Guid.ToString()

Write-Output "AadClientId: $client_id`nAadTenantId: $tenant_id"

#############################
# Register AAD App with SME Gateway
#############################

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$url = "$GatewayEndpoint/api/siterecovery/aadappConfig";
$body=@"
{'properties':{
            'tenant': '$tenant_id',
            'clientId': '$client_id'           
        }
}
"@;

$clientCertificateThumbprint = ''
if ($GatewayEndpoint.StartsWith('https://localhost',"CurrentCultureIgnoreCase"))
{
	$clientCertificateThumbprint = (Get-ItemProperty "HKLM:\Software\Microsoft\ServerManagementGateway").ClientCertificateThumbprint
}

if($clientCertificateThumbprint)
{
	$response = Invoke-WebRequest -Uri $url -Body $body -Method Put -CertificateThumbprint $clientCertificateThumbprint -UseBasicParsing -UserAgent "PowerShell"
}
else
{
    if ($Credential){
        $response = Invoke-WebRequest -Uri $url -Body $body -Method Put  -Credential $Credential -UseBasicParsing -UserAgent "PowerShell" 
    } else {
        $response = Invoke-WebRequest -Uri $url -Body $body -Method Put -UseDefaultCredentials -UseBasicParsing -UserAgent "PowerShell"
    }
    
}

if ($response.StatusCode -ne 200 ) 
{
    $err = "Failed to register the application with the gateway"
    throw $err
}

$url = "$GatewayEndpoint/api/gateway/aad/writeAppInfo";
$body=@"
{'properties':{
             'redirectUri' : '$gatewayEndpoint',
             'appObjectId' : '$object_id'
        }
}
"@;

if($clientCertificateThumbprint)
{
	$response = Invoke-WebRequest -Uri $url -Body $body -Method Put -CertificateThumbprint $clientCertificateThumbprint -UseBasicParsing -UserAgent "PowerShell"
}
else
{
    if ($Credential){
        $response = Invoke-WebRequest -Uri $url -Body $body -Method Put  -Credential $Credential -UseBasicParsing -UserAgent "PowerShell" 
    } else {
        $response = Invoke-WebRequest -Uri $url -Body $body -Method Put -UseDefaultCredentials -UseBasicParsing -UserAgent "PowerShell"
    }
}

if ($response.StatusCode -ne 200 ) 
{
    $err = "Failed to register the application with the gateway"
    throw $err
}

Write-Output "Windows Admin Center Azure Setup Complete"