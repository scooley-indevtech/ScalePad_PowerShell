# Lifecycle Manager Microsoft 365 App Registration Automation

This PowerShell script automates the creation and management of Microsoft Azure App Registrations for integrating Lifecycle Manager with Microsoft 365 environments. It intelligently detects existing app registrations and updates them, or creates new ones as needed, ensuring consistent configuration across deployments with full admin consent automation.

## What This Script Does

**Smart Create or Update Logic:**
- Detects existing app registrations by name and updates them with proper permissions
- Creates new app registrations when none exist
- Automatically configures all required Microsoft Graph API permissions
- Generates client secrets with configurable expiration (default: 24 months)
- Configures authentication settings and redirect URIs
- **Automatically grants admin consent** for all permissions
- Exports credentials to an organized text file for easy reference
- Supports multi-tenant deployments with forced fresh login

## Key Features

- ✅ **Idempotent**: Safe to run multiple times - updates existing apps instead of creating duplicates
- ✅ **Full Automation**: No manual Azure portal steps required
- ✅ **Multi-Tenant Ready**: Forces fresh login for each tenant to prevent credential mix-ups
- ✅ **Auto Admin Consent**: Automatically grants admin consent for all 7 required permissions
- ✅ **Credential Export**: Saves credentials to a domain-named text file for easy reference
- ✅ **Smart Error Handling**: Gracefully handles existing resources and permission conflicts

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
.\CreateOrUpdate-LifeCycleManagerX-AppRegistration.ps1
```

This uses the default settings:
- Display Name: "Lifecycle Manager Microsoft 365 Single Tenant Integration"
- Client Secret Expiry: 24 months
- Redirect URI: "https://app.scalepad.com/account/integration/oauth"

### Custom Configuration
```powershell
# Custom display name
.\CreateOrUpdate-LifeCycleManagerX-AppRegistration.ps1 -DisplayName "My Company LM Integration"

# Custom secret expiration (12 months)
.\CreateOrUpdate-LifeCycleManagerX-AppRegistration.ps1 -ClientSecretExpiryMonths 12

# Custom redirect URI
.\CreateOrUpdate-LifeCycleManagerX-AppRegistration.ps1 -RedirectUri "https://custom.domain.com/oauth"

# All custom parameters
.\CreateOrUpdate-LifeCycleManagerX-AppRegistration.ps1 -DisplayName "Custom Integration" -ClientSecretExpiryMonths 12 -RedirectUri "https://custom.domain.com/oauth"
```

## Authentication Flow

When you run the script:

1. **Previous Session Cleared**: Any existing Graph session is disconnected
2. **Browser Login**: A browser window opens for Azure authentication
3. **Account Selection**: You can choose the correct tenant/account for this deployment
4. **Consent Prompt**: You'll consent to PowerShell module permissions (first run only)
5. **MFA**: Complete any multi-factor authentication if enabled
6. **Script Execution**: The script creates/updates and configures the app registration

## Script Behavior

### For Existing App Registrations
When an app with the same display name already exists:
- ✅ Updates permissions to ensure all 7 required permissions are configured
- ✅ Updates redirect URI if needed
- ✅ Finds or creates service principal
- ✅ Grants admin consent for all permissions
- ⚠️ **Does NOT create a new client secret** (use existing or create manually)

### For New App Registrations
When no app with the display name exists:
- ✅ Creates new app registration with all settings
- ✅ Generates client secret with configured expiration
- ✅ Creates service principal
- ✅ Grants admin consent for all permissions
- ✅ Exports credentials to text file

## Script Output

Upon successful completion, the script displays:

```
================================================================
  LIFECYCLE MANAGER INTEGRATION CREDENTIALS
================================================================
Organization:      contoso.com
Tenant ID:         6b6411163dad-e7c5-4e22-b70f-7a88337c0b67
Application ID:    5f525a71-424c-4309-a7885e9c9c4a529c
Client Secret:     LVP8Q~RvuSP6nLK0KwqM7siw1o_6-M1414m4~RFKn6c1_
================================================================

✓ Credentials exported to: contoso.com-LM-Credentials.txt
```

### Exported Credentials File

The script automatically creates a text file named using the tenant's primary domain:
- **Filename format**: `{primarydomain}-LM-Credentials.txt`
- **Examples**: `contoso.com-LM-Credentials.txt`, `customer.onmicrosoft.com-LM-Credentials.txt`
- **Location**: Current directory
- **Contents**: Tenant ID, Application ID, and Client Secret in a formatted, easy-to-read layout

## Multi-Tenant Deployment

The script is designed for deploying across multiple customer tenants safely:

```powershell
# Tenant 1
.\CreateOrUpdate-LifeCycleManagerX-AppRegistration.ps1
# → Disconnects any previous session
# → Fresh browser login for Tenant 1
# → Creates credentials file: tenant1.com-LM-Credentials.txt

# Tenant 2
.\CreateOrUpdate-LifeCycleManagerX-AppRegistration.ps1
# → Disconnects Tenant 1 session
# → Fresh browser login for Tenant 2  
# → Creates credentials file: tenant2.com-LM-Credentials.txt
```

Each run forces a fresh login, preventing accidental credential reuse across tenants.

## Next Steps

After running the script:

1. **Locate the credentials file** in your current directory
2. **Open the text file** to find all required values
3. **Configure Lifecycle Manager** with the provided values:
   - Azure (Directory) Tenant ID
   - Azure Application (Client) ID  
   - Azure Client Secret Value
4. **Verify the integration** works in Lifecycle Manager
5. **Store credentials securely** in your password manager
6. **Delete the text file** after credentials are saved elsewhere

## Fixing Existing Apps Without Admin Consent

If you have an existing app registration that's missing admin consent:

1. Simply run the script with the **exact same display name**
2. The script will:
   - Find the existing app
   - Update permissions if needed
   - Grant admin consent for all permissions
   - Skip creating a new client secret (use your existing one)

```powershell
# This will fix the existing app and grant admin consent
.\CreateOrUpdate-LifeCycleManagerX-AppRegistration.ps1
```

## Security Considerations

- **Client Secret Storage**: Store client secrets securely in a password manager and never commit them to version control
- **Secret Rotation**: Client secrets expire after 24 months by default - plan for rotation before expiration
- **Least Privilege**: The script uses only the minimum required permissions
- **Audit Trail**: All actions are logged in Azure AD audit logs
- **Credential Files**: Delete exported `.txt` files after transferring credentials to secure storage

## Troubleshooting

### Common Issues

**"Insufficient privileges" error**
- Ensure you're running as Global Administrator
- Check that your account has the required Azure AD roles

**"Microsoft.Graph module not found"**
- The script will attempt to install it automatically
- Manual installation: `Install-Module Microsoft.Graph -Scope CurrentUser`

**"Service principal already exists" (409 Conflict)**
- This error has been handled in the latest version
- The script now properly detects and uses existing service principals

**Admin consent appears granted but Lifecycle Manager still reports missing permissions**
- Wait 5-10 minutes for Azure AD permission propagation
- Sign out and back in to Lifecycle Manager
- Verify all permissions show green checkmarks in Azure portal

**"ReportSettings.ReadWrite.All missing" error in Lifecycle Manager**
- Run the script again on the existing app to grant proper admin consent
- The script will detect the existing app and fix the permissions

### Verifying Admin Consent

To verify permissions were granted correctly:

1. Go to Azure portal → Azure AD → App registrations
2. Find your app: "Lifecycle Manager Microsoft 365 Single Tenant Integration"
3. Click "API permissions"
4. All 7 permissions should show:
   - Status: "Granted for [your organization]"
   - Green checkmark (✓) in the status column

### Getting Help

If you encounter issues:

1. Check the Azure AD audit logs for detailed error information
2. Verify your PowerShell execution policy allows script execution
3. Ensure you have the latest version of the Microsoft.Graph module
4. Run the script again - it's safe to run multiple times

## What's New

### v2.0 (Current)
- **Smart update logic**: Detects and updates existing app registrations
- **Automatic admin consent**: Fully automated permission granting
- **Extended secret lifetime**: Default changed from 6 to 24 months
- **Credential export**: Auto-exports to domain-named text file
- **Multi-tenant safety**: Forces fresh login for each tenant
- **Better error handling**: Gracefully handles existing resources
- **Improved output**: Key credentials displayed prominently at the end

### v1.0
- Initial release
- Automated app registration creation
- Microsoft Graph permissions configuration
- Client secret generation
- Manual admin consent instructions

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

### v2.0.0 - Current Release
- Added smart create-or-update logic for existing apps
- Implemented automatic admin consent granting
- Changed default client secret expiration to 24 months
- Added automatic credential export to domain-named text files
- Added multi-tenant support with forced fresh logins
- Improved service principal handling
- Enhanced error handling and user feedback
- Added prominent credential display at script completion

### v1.0.0 - Initial Release
- Basic app registration creation
- Microsoft Graph permissions configuration
- Client secret generation
- Manual admin consent workflow
