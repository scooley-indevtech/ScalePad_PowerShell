# Microsoft 365 App Registration Automation Script for Lifecycle Manager
# Requires Microsoft.Graph PowerShell module
# Run as Global Administrator

param(
    [Parameter(Mandatory = $false)]
    [string]$DisplayName = "Lifecycle Manager Microsoft 365 Single Tenant Integration",
    
    [Parameter(Mandatory = $false)]
    [int]$ClientSecretExpiryMonths = 6,
    
    [Parameter(Mandatory = $false)]
    [string]$RedirectUri = "https://app.scalepad.com/account/integration/oauth"
)

# Install and import required modules if not already available
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "Installing Microsoft Graph PowerShell module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Authentication

try {
    # Connect to Microsoft Graph with required permissions
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Green
    Write-Host "You will be prompted to sign in with Global Administrator credentials..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"

    # Define required API permissions
    $requiredPermissions = @(
        @{
            ResourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
            ResourceAccess = @(
                @{ Id = "b0afded3-3588-46d8-8b3d-9842eff778da"; Type = "Role" }, # AuditLog.Read.All
                @{ Id = "7a6ee1e7-141e-4cec-ae74-d9db155731ff"; Type = "Role" }, # DeviceManagementApps.Read.All
                @{ Id = "2f51be20-0bb4-4fed-bf7b-db946066c75e"; Type = "Role" }, # DeviceManagementManagedDevices.Read.All
                @{ Id = "498476ce-e0fe-48b0-b801-37ba7e2685c6"; Type = "Role" }, # Organization.Read.All
                @{ Id = "230c1aed-a721-4c5d-9cb4-a90514e508ef"; Type = "Role" }, # Reports.Read.All
                @{ Id = "df021288-bdef-4463-88db-98f22de89214"; Type = "Role" }, # User.Read.All
                @{ Id = "ee353f83-55ef-4b78-82da-555bfa2b4b95"; Type = "Role" }  # ReportSettings.ReadWrite.All
            )
        }
    )

    # Create the app registration
    Write-Host "Creating app registration: $DisplayName" -ForegroundColor Green
    
    $appParams = @{
        DisplayName = $DisplayName
        SignInAudience = "AzureADMyOrg"  # Single tenant
        RequiredResourceAccess = $requiredPermissions
        Web = @{
            RedirectUris = @($RedirectUri)
        }
    }

    $app = New-MgApplication @appParams
    
    Write-Host "App registration created successfully!" -ForegroundColor Green
    Write-Host "Application (Client) ID: $($app.AppId)" -ForegroundColor Cyan
    Write-Host "Directory (Tenant) ID: $((Get-MgContext).TenantId)" -ForegroundColor Cyan

    # Create client secret
    Write-Host "Creating client secret..." -ForegroundColor Green
    
    $secretParams = @{
        ApplicationId = $app.Id
        PasswordCredential = @{
            DisplayName = "Lifecycle Manager Integration Secret"
            EndDateTime = (Get-Date).AddMonths($ClientSecretExpiryMonths)
        }
    }

    $clientSecret = Add-MgApplicationPassword @secretParams
    
    Write-Host "Client secret created successfully!" -ForegroundColor Green
    Write-Host "Client Secret Value: $($clientSecret.SecretText)" -ForegroundColor Yellow
    Write-Host "Client Secret ID: $($clientSecret.KeyId)" -ForegroundColor Cyan
    Write-Host "Client Secret Expires: $($clientSecret.EndDateTime)" -ForegroundColor Cyan

    # Grant admin consent (requires additional permissions)
    Write-Host "`nAttempting to grant admin consent..." -ForegroundColor Green
    
    try {
        # Create service principal for the app
        $servicePrincipal = New-MgServicePrincipal -AppId $app.AppId
        
        # Grant admin consent for each permission
        foreach ($permission in $requiredPermissions[0].ResourceAccess) {
            $consentParams = @{
                ClientId = $servicePrincipal.Id
                ConsentType = "AllPrincipals"
                ResourceId = (Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'").Id
                Scope = $permission.Id
            }
            
            try {
                New-MgOauth2PermissionGrant @consentParams | Out-Null
            }
            catch {
                Write-Warning "Could not automatically grant consent for permission $($permission.Id): $($_.Exception.Message)"
            }
        }
        
        Write-Host "Admin consent process completed. Please verify in Azure portal." -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not automatically grant admin consent: $($_.Exception.Message)"
        Write-Host "Please manually grant admin consent in the Azure portal." -ForegroundColor Yellow
    }

    # Output summary
    Write-Host "`n=== INTEGRATION SUMMARY ===" -ForegroundColor Magenta
    Write-Host "Application Name: $DisplayName"
    Write-Host "Application (Client) ID: $($app.AppId)"
    Write-Host "Directory (Tenant) ID: $((Get-MsgContext).TenantId)"
    Write-Host "Client Secret Value: $($clientSecret.SecretText)"
    Write-Host "Client Secret Expires: $($clientSecret.EndDateTime)"
    Write-Host "Redirect URI: $RedirectUri"
    Write-Host "`nIMPORTANT: Save the Client Secret Value in a secure location!"
    Write-Host "This value cannot be retrieved again once this session ends."

    # Create output object for programmatic use
    $result = @{
        ApplicationId = $app.AppId
        TenantId = (Get-MgContext).TenantId
        ClientSecretValue = $clientSecret.SecretText
        ClientSecretId = $clientSecret.KeyId
        ClientSecretExpires = $clientSecret.EndDateTime
        DisplayName = $DisplayName
        RedirectUri = $RedirectUri
    }

    return $result

}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.Exception.StackTrace)"
}
finally {
    # Disconnect from Microsoft Graph
    Disconnect-MgGraph
}
