# LAPS Reader

A lightweight Windows GUI tool (PowerShell + WinForms) that lets IT staff retrieve **Windows LAPS** passwords for Entra ID / Intune-joined devices, without giving them access to the Intune or Entra admin portals.

It connects to Microsoft Graph, looks up a device by name, and displays the local administrator password with a one-click copy button.

---

## Features

- Simple graphical interface, no console window once compiled
- Sign in / sign out with Microsoft Graph (interactive authentication)
- Search a device by its display name
- Displays the local administrator password and its last backup date
- One-click copy to clipboard
- Detects and warns when required Graph permissions have not been consented

---

## Requirements

- **Windows 10 / 11** with **PowerShell 5.1** or later
- **Microsoft.Graph** PowerShell module
  ```powershell
  Install-Module Microsoft.Graph -Scope CurrentUser
  ```
  The script offers to install it automatically on first launch if it is missing.
- An Entra ID account with rights to read LAPS passwords (for example the **Cloud Device Administrator** role, or a custom role with the `microsoft.directory/deviceLocalCredentials/password/read` permission)

---

## Required Graph permissions

The application requests two delegated scopes:

| Scope | Purpose |
|-------|---------|
| `Device.Read.All` | Look up the device by name |
| `DeviceLocalCredential.Read.All` | Read the LAPS password |

> **Important:** these scopes usually require **admin consent** on the *Microsoft Graph Command Line Tools* enterprise application. A Global Administrator should grant consent once for the whole tenant:
> ```powershell
> Connect-MgGraph -Scopes "DeviceLocalCredential.Read.All","Device.Read.All"
> ```
> On the sign-in screen, tick **"Consent on behalf of your organization"** before approving. Alternatively, grant admin consent from **Entra ID > Enterprise applications > Microsoft Graph Command Line Tools > Permissions**.

---

## Usage

1. Launch the script (or the compiled `.exe`):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\M365-laps-reader.ps1
   ```
2. Click **Se connecter** and authenticate with your Microsoft account.
3. Enter the exact device name as it appears in Entra / Intune.
4. Click **Rechercher** (or press Enter).
5. The local administrator password is displayed. Use **Copier** to copy it.

---

## Compiling to a standalone .exe (PS2EXE)

Compiling produces a single executable you can distribute to IT staff, with no visible PowerShell console.

### 1. Install PS2EXE

```powershell
Install-Module PS2EXE -Scope CurrentUser
```

### 2. Compile

```powershell
Invoke-PS2EXE `
    -InputFile  ".\M365-laps-reader.ps1" `
    -OutputFile ".\M365-laps-reader.exe" `
    -NoConsole `
    -IconFile   ".\app.ico" `
    -Title       "LAPS Reader" `
    -Description "LAPS password reader for Entra / Intune" `
    -Company     "Conexia Sàrl" `
    -Version     "1.0.1"
```

| Parameter | Purpose |
|-----------|---------|
| `-NoConsole` | Hides the PowerShell console so only the GUI window appears (**required**) |
| `-Title` / `-Description` / `-Company` / `-Version` | Metadata shown in the file properties |

> **Note:** the compiled `.exe` still requires the **Microsoft.Graph** module to be installed on the machine where it runs. The module is not embedded in the executable. Either install it on each machine, or ship it alongside the tool.

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Insufficient privileges` / `Authorization_RequestDenied` | Required scopes not consented | Grant admin consent for `DeviceLocalCredential.Read.All` and `Device.Read.All` (see above) |
| `BadRequest` on search | Wrong device identifier or endpoint | Already handled in the current version (uses `DeviceId` and the `/directory/deviceLocalCredentials/` endpoint) |
| `The property 'PlaceholderText' cannot be found` | Old .NET Framework | Already handled (manual placeholder logic) |
| Accents or symbols display incorrectly | File not saved as UTF-8 with BOM | Re-save the script as **UTF-8 with BOM** |
| Module not found | `Microsoft.Graph` missing | `Install-Module Microsoft.Graph -Scope CurrentUser` |

---

## Security notes

- LAPS password reads are logged in **Entra ID audit logs**, so every retrieval is traceable.
- Grant the underlying directory role only to the people who genuinely need it.
- Consider scoping access with an **Administrative Unit** if staff should only see a subset of devices.
- The password is held in memory only while displayed and is never written to disk.

---

## How it works

1. `Connect-MgGraph` authenticates the user and requests the two delegated scopes.
2. `Get-MgDevice` resolves the device name to its Azure AD `DeviceId`.
3. A direct Graph call retrieves the LAPS credential:
   ```
   GET https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials/{deviceId}?$select=credentials
   ```
4. The Base64-encoded password is decoded and shown in the UI.

This is the same API the Intune portal uses to display LAPS passwords.

## Licence

This project is distributed under the **MIT** license. You are free to use, modify, and redistribute it, including for commercial purposes, provided you retain the copyright notice. See the [`LICENSE`](LICENSE) file for the full text.This project is distributed under the **MIT** license. You are free to use, modify, and redistribute it, including for commercial purposes, provided you retain the copyright notice. See the [`LICENSE`](LICENSE) file for the full text.This project is distributed under the **MIT** license. You are free to use, modify, and redistribute it, including for commercial purposes, provided you retain the copyright notice. See the [`LICENSE`](LICENSE) file for the full text.