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

    # Check if app registration already exists
    Write-Host "Checking for existing app registration with name: $DisplayName" -ForegroundColor Green
    
    $existingApp = Get-MgApplication -Filter "DisplayName eq '$DisplayName'"
    
    if ($existingApp) {
        Write-Host "Found existing app registration!" -ForegroundColor Yellow
        Write-Host "Application (Client) ID: $($existingApp.AppId)" -ForegroundColor Cyan
        Write-Host "Directory (Tenant) ID: $((Get-MgContext).TenantId)" -ForegroundColor Cyan
        
        $app = $existingApp
        $isNewApp = $false
        
        Write-Host "Updating existing app registration with required permissions..." -ForegroundColor Green
        
        # Update the existing app with required permissions
        try {
            $updateParams = @{
                RequiredResourceAccess = $requiredPermissions
                Web = @{
                    RedirectUris = @($RedirectUri)
                }
            }
            Update-MgApplication -ApplicationId $app.Id @updateParams
            Write-Host "App registration updated successfully!" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to update app registration: $($_.Exception.Message)"
            Write-Host "Continuing with existing configuration..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No existing app registration found. Creating new one..." -ForegroundColor Green
        
        # Create the app registration
        $appParams = @{
            DisplayName = $DisplayName
            SignInAudience = "AzureADMyOrg"  # Single tenant
            RequiredResourceAccess = $requiredPermissions
            Web = @{
                RedirectUris = @($RedirectUri)
            }
        }

        $app = New-MgApplication @appParams
        $isNewApp = $true
        
        Write-Host "App registration created successfully!" -ForegroundColor Green
        Write-Host "Application (Client) ID: $($app.AppId)" -ForegroundColor Cyan
        Write-Host "Directory (Tenant) ID: $((Get-MgContext).TenantId)" -ForegroundColor Cyan
    }

    # Create client secret (only for new apps or if requested)
    $clientSecret = $null
    
    if ($isNewApp) {
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
    } else {
        Write-Host "Skipping client secret creation for existing app." -ForegroundColor Yellow
        Write-Host "If you need a new client secret, create one manually in the Azure portal." -ForegroundColor Cyan
    }

    # Create or find service principal and grant admin consent
    Write-Host "`nChecking for existing service principal..." -ForegroundColor Green
    
    try {
        # Check if service principal already exists
        $servicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '$($app.AppId)'"
        
        if ($servicePrincipal) {
            Write-Host "Found existing service principal!" -ForegroundColor Yellow
            Write-Host "Service Principal ID: $($servicePrincipal.Id)" -ForegroundColor Cyan
        } else {
            Write-Host "Creating new service principal..." -ForegroundColor Green
            $servicePrincipal = New-MgServicePrincipal -AppId $app.AppId
            Write-Host "Service principal created successfully!" -ForegroundColor Green
            Write-Host "Service Principal ID: $($servicePrincipal.Id)" -ForegroundColor Cyan
        }
        
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
    
    if ($clientSecret) {
        Write-Host "Client Secret Value: $($clientSecret.SecretText)"
        Write-Host "Client Secret Expires: $($clientSecret.EndDateTime)"
        Write-Host "`nIMPORTANT: Save the Client Secret Value in a secure location!"
        Write-Host "This value cannot be retrieved again once this session ends."
    } else {
        Write-Host "Client Secret: Use existing secret or create new one in Azure portal"
    }
    
    Write-Host "Redirect URI: $RedirectUri"

    # Create output object for programmatic use
    $result = @{
        ApplicationId = $app.AppId
        TenantId = (Get-MgContext).TenantId
        DisplayName = $DisplayName
        RedirectUri = $RedirectUri
        IsNewApp = $isNewApp
        ServicePrincipalId = $servicePrincipal.Id
    }
    
    if ($clientSecret) {
        $result.ClientSecretValue = $clientSecret.SecretText
        $result.ClientSecretId = $clientSecret.KeyId
        $result.ClientSecretExpires = $clientSecret.EndDateTime
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
