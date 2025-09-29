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
    # Disconnect any existing sessions to ensure fresh login
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    } catch {
        # Ignore errors if not connected
    }

    # Connect to Microsoft Graph with required permissions
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Green
    Write-Host "You will be prompted to sign in with Global Administrator credentials..." -ForegroundColor Yellow
    Write-Host "Please ensure you select the correct tenant/account for this integration." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All", "AppRoleAssignment.ReadWrite.All"

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

    # Create service principal and grant admin consent
    Write-Host "`nCreating service principal..." -ForegroundColor Green
    
    try {
        $servicePrincipal = New-MgServicePrincipal -AppId $app.AppId
        Write-Host "Service principal created successfully!" -ForegroundColor Green
        
        # Grant admin consent for Microsoft Graph permissions
        Write-Host "`nGranting admin consent for Microsoft Graph permissions..." -ForegroundColor Yellow
        
        # Get the Microsoft Graph service principal
        $graphServicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
        
        if ($graphServicePrincipal) {
            $consentSuccessCount = 0
            $consentFailCount = 0
            
            # Grant consent for each application permission (Role type)
            foreach ($permission in $requiredPermissions[0].ResourceAccess | Where-Object { $_.Type -eq "Role" }) {
                $permissionId = $permission.Id
                
                # Find the app role in Microsoft Graph service principal
                $appRole = $graphServicePrincipal.AppRoles | Where-Object { $_.Id -eq $permissionId }
                
                if ($appRole) {
                    Write-Host "  Granting consent for: $($appRole.Value)" -ForegroundColor White
                    
                    # Check if this permission is already granted
                    $existingAssignment = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $servicePrincipal.Id | 
                        Where-Object { $_.AppRoleId -eq $permissionId -and $_.ResourceId -eq $graphServicePrincipal.Id }
                    
                    if ($existingAssignment) {
                        Write-Host "    ✓ Already granted" -ForegroundColor Green
                        $consentSuccessCount++
                    } else {
                        try {
                            # Grant the app role assignment (admin consent)
                            $assignment = @{
                                PrincipalId = $servicePrincipal.Id
                                ResourceId = $graphServicePrincipal.Id
                                AppRoleId = $permissionId
                            }
                            
                            New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $servicePrincipal.Id -BodyParameter $assignment | Out-Null
                            Write-Host "    ✓ Granted successfully" -ForegroundColor Green
                            $consentSuccessCount++
                        } catch {
                            Write-Host "    ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
                            $consentFailCount++
                        }
                    }
                } else {
                    Write-Host "    ✗ App role not found for permission ID: $permissionId" -ForegroundColor Red
                    $consentFailCount++
                }
            }
            
            Write-Host "`nAdmin consent summary:" -ForegroundColor Cyan
            Write-Host "  ✓ Successfully granted: $consentSuccessCount permissions" -ForegroundColor Green
            if ($consentFailCount -gt 0) {
                Write-Host "  ✗ Failed to grant: $consentFailCount permissions" -ForegroundColor Red
                Write-Host "  Please manually grant any failed permissions in the Azure portal." -ForegroundColor Yellow
            } else {
                Write-Host "  🎉 All permissions granted successfully!" -ForegroundColor Green
            }
        } else {
            Write-Warning "Could not find Microsoft Graph service principal for admin consent"
            Write-Host "Please manually grant admin consent in the Azure portal." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "Could not create service principal or grant admin consent: $($_.Exception.Message)"
        Write-Host "You may need to create it manually in the Azure portal and grant admin consent." -ForegroundColor Yellow
    }

    # Output summary
    Write-Host "`n=== INTEGRATION SUMMARY ===" -ForegroundColor Magenta
    Write-Host "Application Name: $DisplayName"
    Write-Host "Application (Client) ID: $($app.AppId)"
    Write-Host "Directory (Tenant) ID: $((Get-MgContext).TenantId)"
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
