# Lifecycle Manager Microsoft 365 App Registration Automation

This PowerShell script automates the creation of Microsoft Azure App Registrations for integrating Lifecycle Manager with Microsoft 365 environments. It eliminates the manual steps typically required in the Azure portal and ensures consistent configuration across deployments.

## What This Script Does

- Creates a single-tenant Azure App Registration with the proper configuration
- Adds all required Microsoft Graph API permissions for Lifecycle Manager integration
- Generates a client secret with configurable expiration (default: 6 months)
- Configures authentication settings and redirect URIs
- Attempts to grant admin consent automatically
- Outputs all required values for Lifecycle Manager integration setup

## Prerequisites

Before running this script, ensure you have:

- **Global Administrator** permissions in your Azure tenant
- **PowerShell 5.1** or **PowerShell 7+**
- **Microsoft.Graph PowerShell module** (script will install if missing)
- Internet connectivity for Azure authentication

## Required API Permissions

The script automatically configures these Microsoft Graph permissions:

| Permission | Type | Description |
|------------|------|-------------|
| `AuditLog.Read.All` | Application | Read audit log data |
| `DeviceManagementApps.Read.All` | Application | Read device management app data |
| `DeviceManagementManagedDevices.Read.All` | Application | Read managed device data |
| `Organization.Read.All` | Application | Read organization data |
| `Reports.Read.All` | Application | Read usage reports |
| `User.Read.All` | Application | Read all user profiles |
| `ReportSettings.ReadWrite.All` | Application | Read and write report settings |

## Installation

1. Clone this repository or download the script file
2. Open PowerShell as Administrator (recommended)
3. Navigate to the script directory

```powershell
cd path\to\script\directory
```

## Usage

### Basic Usage (Recommended)
```powershell
.\Create-LifeCycleManagerX-AppRegistration.ps1
```

This uses the default settings:
- Display Name: "Lifecycle Manager Microsoft 365 Single Tenant Integration"
- Client Secret Expiry: 6 months
- Redirect URI: "https://app.scalepad.com/account/integration/oauth"

### Custom Configuration
```powershell
# Custom display name
.\Create-LifeCycleManagerX-AppRegistration.ps1 -DisplayName "My Company LM Integration"

# Custom secret expiration (12 months)
.\Create-LifeCycleManagerX-AppRegistration.ps1 -ClientSecretExpiryMonths 12

# Custom redirect URI
.\Create-LifeCycleManagerX-AppRegistration.ps1 -RedirectUri "https://custom.domain.com/oauth"

# All custom parameters
.\Create-LifeCycleManagerX-AppRegistration.ps1 -DisplayName "Custom Integration" -ClientSecretExpiryMonths 12 -RedirectUri "https://custom.domain.com/oauth"
```

## Authentication Flow

When you run the script:

1. **Browser Login**: A browser window opens for Azure authentication
2. **Consent Prompt**: You'll need to consent to PowerShell module permissions
3. **MFA**: Complete any multi-factor authentication if enabled
4. **Script Execution**: The script creates and configures the app registration

## Script Output

Upon successful completion, the script displays:

```
=== INTEGRATION SUMMARY ===
Application Name: Lifecycle Manager Microsoft 365 Single Tenant Integration
Application (Client) ID: 12345678-1234-1234-1234-123456789012
Directory (Tenant) ID: 87654321-4321-4321-4321-210987654321
Client Secret Value: ABC123~XYZ789-SecretValue
Client Secret Expires: 3/28/2026 10:30:00 AM
Redirect URI: https://app.scalepad.com/account/integration/oauth

IMPORTANT: Save the Client Secret Value in a secure location!
This value cannot be retrieved again once this session ends.
```

## Next Steps

After running the script:

1. **Save the output values** in a secure password manager
2. **Verify admin consent** in the Azure portal (Azure AD > App registrations > your app > API permissions)
3. **Configure Lifecycle Manager** with the provided values:
   - Azure (Directory) Tenant ID
   - Azure Application (Client) ID  
   - Azure Client Secret Value

## Security Considerations

- **Client Secret Storage**: Store the client secret securely and never commit it to version control
- **Secret Rotation**: Client secrets expire after 6 months by default - plan for rotation
- **Least Privilege**: The script uses only the minimum required permissions
- **Audit Trail**: All actions are logged in Azure AD audit logs

## Troubleshooting

### Common Issues

**"Insufficient privileges" error**
- Ensure you're running as Global Administrator
- Check that your account has the required Azure AD roles

**"Microsoft.Graph module not found"**
- The script will attempt to install it automatically
- Manual installation: `Install-Module Microsoft.Graph -Scope CurrentUser`

**Admin consent not granted automatically**
- Navigate to Azure portal → Azure AD → App registrations → your app → API permissions
- Click "Grant admin consent" manually

**Browser doesn't open for authentication**
- Try running: `Connect-MgGraph -UseDeviceAuthentication`
- Use the device code flow for authentication

### Getting Help

If you encounter issues:

1. Check the Azure AD audit logs for detailed error information
2. Verify your PowerShell execution policy allows script execution
3. Ensure you have the latest version of the Microsoft.Graph module

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

### v1.0.0
- Initial release
- Automated app registration creation
- Microsoft Graph permissions configuration
- Client secret generation
- Admin consent automation
