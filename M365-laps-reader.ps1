#Requires -Version 5.1
<#
.SYNOPSIS
    LAPS Entra Reader - Graphical interface for retrieving LAPS passwords via Microsoft Graph
.NOTES
    Prerequisites : module Microsoft.Graph
    Install-Module Microsoft.Graph -Scope CurrentUser
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ─── Verifying the Microsoft.Graph module ─────────────────────────────────

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Le module Microsoft.Graph n'est pas installé.`n`nVoulez-vous l'installer maintenant ?",
        "Module manquant",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec de l'installation : $_", "Erreur",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error)
            exit
        }
    } else { exit }
}

# ─── Global variables ──────────────────────────────────────────────────────

$script:IsConnected  = $false
$script:ConnectedUser = ""

# ─── Colors & Fonts ──────────────────────────────────────────────────────

$ColorBg         = [System.Drawing.Color]::FromArgb(245, 247, 250)
$ColorCard       = [System.Drawing.Color]::White
$ColorPrimary    = [System.Drawing.Color]::FromArgb(0, 120, 212)
$ColorPrimaryHov = [System.Drawing.Color]::FromArgb(0, 100, 180)
$ColorSuccess    = [System.Drawing.Color]::FromArgb(16, 124, 65)
$ColorDanger     = [System.Drawing.Color]::FromArgb(196, 43, 28)
$ColorText       = [System.Drawing.Color]::FromArgb(32, 32, 32)
$ColorSubtext    = [System.Drawing.Color]::FromArgb(100, 100, 110)
$FontMain        = New-Object System.Drawing.Font("Segoe UI", 9)
$FontBold        = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$FontTitle       = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$FontMono        = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$FontSmall       = New-Object System.Drawing.Font("Segoe UI", 8)

# ─── Main Form ────────────────────────────────────────────────────

$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "LAPS Reader"
$Form.Size            = New-Object System.Drawing.Size(480, 540)
$Form.MinimumSize     = New-Object System.Drawing.Size(480, 540)
$Form.MaximumSize     = New-Object System.Drawing.Size(480, 540)
$Form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.BackColor       = $ColorBg
$Form.Font            = $FontMain
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form.MaximizeBox     = $false

# ─── Header ────────────────────────────────────────────────────────────────

$PanelHeader = New-Object System.Windows.Forms.Panel
$PanelHeader.Size      = New-Object System.Drawing.Size(480, 70)
$PanelHeader.Location  = New-Object System.Drawing.Point(0, 0)
$PanelHeader.BackColor = $ColorPrimary

$LblTitle = New-Object System.Windows.Forms.Label
$LblTitle.Text      = "  LAPS Reader"
$LblTitle.Font      = $FontTitle
$LblTitle.ForeColor = [System.Drawing.Color]::White
$LblTitle.AutoSize  = $false
$LblTitle.Size      = New-Object System.Drawing.Size(440, 36)
$LblTitle.Location  = New-Object System.Drawing.Point(16, 10)

$LblSubtitle = New-Object System.Windows.Forms.Label
$LblSubtitle.Text      = "  Récupération de mots de passe LAPS Entra / Intune"
$LblSubtitle.Font      = $FontSmall
$LblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(200, 230, 255)
$LblSubtitle.AutoSize  = $false
$LblSubtitle.Size      = New-Object System.Drawing.Size(450, 18)
$LblSubtitle.Location  = New-Object System.Drawing.Point(16, 50)

$PanelHeader.Controls.AddRange(@($LblTitle, $LblSubtitle))

# ─── Login Card ─────────────────────────────────────────────────────────

$PanelConn = New-Object System.Windows.Forms.Panel
$PanelConn.Size        = New-Object System.Drawing.Size(440, 80)
$PanelConn.Location    = New-Object System.Drawing.Point(20, 85)
$PanelConn.BackColor   = $ColorCard
$PanelConn.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$LblConnTitle = New-Object System.Windows.Forms.Label
$LblConnTitle.Text      = "Connexion Microsoft"
$LblConnTitle.Font      = $FontBold
$LblConnTitle.ForeColor = $ColorText
$LblConnTitle.AutoSize  = $false
$LblConnTitle.Size      = New-Object System.Drawing.Size(300, 20)
$LblConnTitle.Location  = New-Object System.Drawing.Point(14, 12)

$StatusDot = New-Object System.Windows.Forms.Panel
$StatusDot.Size      = New-Object System.Drawing.Size(10, 10)
$StatusDot.Location  = New-Object System.Drawing.Point(14, 44)
$StatusDot.BackColor = [System.Drawing.Color]::FromArgb(170, 170, 175)

$LblConnStatus = New-Object System.Windows.Forms.Label
$LblConnStatus.Text      = "Non connecté"
$LblConnStatus.Font      = $FontMain
$LblConnStatus.ForeColor = $ColorSubtext
$LblConnStatus.AutoSize  = $false
$LblConnStatus.Size      = New-Object System.Drawing.Size(265, 18)
$LblConnStatus.Location  = New-Object System.Drawing.Point(30, 40)

$BtnConnect = New-Object System.Windows.Forms.Button
$BtnConnect.Text      = "Se connecter"
$BtnConnect.Size      = New-Object System.Drawing.Size(120, 32)
$BtnConnect.Location  = New-Object System.Drawing.Point(306, 34)
$BtnConnect.BackColor = $ColorPrimary
$BtnConnect.ForeColor = [System.Drawing.Color]::White
$BtnConnect.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnConnect.FlatAppearance.BorderSize = 0
$BtnConnect.Font      = $FontBold
$BtnConnect.Cursor    = [System.Windows.Forms.Cursors]::Hand

$BtnConnect.Add_MouseEnter({ $BtnConnect.BackColor = $ColorPrimaryHov })
$BtnConnect.Add_MouseLeave({
    if ($script:IsConnected) { $BtnConnect.BackColor = $ColorDanger }
    else { $BtnConnect.BackColor = $ColorPrimary }
})

$PanelConn.Controls.AddRange(@($LblConnTitle, $StatusDot, $LblConnStatus, $BtnConnect))

# ─── Search Map ─────────────────────────────────────────────────────────

$PanelSearch = New-Object System.Windows.Forms.Panel
$PanelSearch.Size        = New-Object System.Drawing.Size(440, 110)
$PanelSearch.Location    = New-Object System.Drawing.Point(20, 180)
$PanelSearch.BackColor   = $ColorCard
$PanelSearch.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$LblSearchTitle = New-Object System.Windows.Forms.Label
$LblSearchTitle.Text      = "Nom de la machine"
$LblSearchTitle.Font      = $FontBold
$LblSearchTitle.ForeColor = $ColorText
$LblSearchTitle.AutoSize  = $false
$LblSearchTitle.Size      = New-Object System.Drawing.Size(400, 20)
$LblSearchTitle.Location  = New-Object System.Drawing.Point(14, 12)

$TxtPC = New-Object System.Windows.Forms.TextBox
$TxtPC.Size        = New-Object System.Drawing.Size(290, 28)
$TxtPC.Location    = New-Object System.Drawing.Point(14, 38)
$TxtPC.Font        = $FontMain
$TxtPC.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$TxtPC.Text        = "Ex: PC-DUPONT-01"
$TxtPC.ForeColor   = $ColorSubtext
$TxtPC.Enabled     = $false

$TxtPC.Add_GotFocus({
    if ($TxtPC.Text -eq "Ex: PC-DUPONT-01") {
        $TxtPC.Text      = ""
        $TxtPC.ForeColor = $ColorText
    }
})
$TxtPC.Add_LostFocus({
    if ($TxtPC.Text -eq "") {
        $TxtPC.Text      = "Ex: PC-DUPONT-01"
        $TxtPC.ForeColor = $ColorSubtext
    }
})

$BtnSearch = New-Object System.Windows.Forms.Button
$BtnSearch.Text      = "Rechercher"
$BtnSearch.Size      = New-Object System.Drawing.Size(120, 28)
$BtnSearch.Location  = New-Object System.Drawing.Point(308, 38)
$BtnSearch.BackColor = $ColorPrimary
$BtnSearch.ForeColor = [System.Drawing.Color]::White
$BtnSearch.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnSearch.FlatAppearance.BorderSize = 0
$BtnSearch.Font      = $FontBold
$BtnSearch.Cursor    = [System.Windows.Forms.Cursors]::Hand
$BtnSearch.Enabled   = $false

$BtnSearch.Add_MouseEnter({ if ($BtnSearch.Enabled) { $BtnSearch.BackColor = $ColorPrimaryHov } })
$BtnSearch.Add_MouseLeave({ if ($BtnSearch.Enabled) { $BtnSearch.BackColor = $ColorPrimary } })

$LblHint = New-Object System.Windows.Forms.Label
$LblHint.Text      = "Entrez le nom exact du poste tel qu'il apparaît dans Entra/Intune"
$LblHint.Font      = $FontSmall
$LblHint.ForeColor = $ColorSubtext
$LblHint.AutoSize  = $false
$LblHint.Size      = New-Object System.Drawing.Size(420, 16)
$LblHint.Location  = New-Object System.Drawing.Point(14, 72)

$PanelSearch.Controls.AddRange(@($LblSearchTitle, $TxtPC, $BtnSearch, $LblHint))

# ─── Results Card ──────────────────────────────────────────────────────────

$PanelResult = New-Object System.Windows.Forms.Panel
$PanelResult.Size        = New-Object System.Drawing.Size(440, 170)
$PanelResult.Location    = New-Object System.Drawing.Point(20, 305)
$PanelResult.BackColor   = $ColorCard
$PanelResult.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$LblResultTitle = New-Object System.Windows.Forms.Label
$LblResultTitle.Text      = "Résultat"
$LblResultTitle.Font      = $FontBold
$LblResultTitle.ForeColor = $ColorText
$LblResultTitle.AutoSize  = $false
$LblResultTitle.Size      = New-Object System.Drawing.Size(200, 20)
$LblResultTitle.Location  = New-Object System.Drawing.Point(14, 12)

$LblDevice = New-Object System.Windows.Forms.Label
$LblDevice.Text      = ""
$LblDevice.Font      = $FontMain
$LblDevice.ForeColor = $ColorSubtext
$LblDevice.AutoSize  = $false
$LblDevice.Size      = New-Object System.Drawing.Size(410, 18)
$LblDevice.Location  = New-Object System.Drawing.Point(14, 35)

$LblPasswordLabel = New-Object System.Windows.Forms.Label
$LblPasswordLabel.Text      = "Mot de passe administrateur local :"
$LblPasswordLabel.Font      = $FontSmall
$LblPasswordLabel.ForeColor = $ColorSubtext
$LblPasswordLabel.AutoSize  = $false
$LblPasswordLabel.Size      = New-Object System.Drawing.Size(300, 16)
$LblPasswordLabel.Location  = New-Object System.Drawing.Point(14, 58)
$LblPasswordLabel.Visible   = $false

$PanelPassword = New-Object System.Windows.Forms.Panel
$PanelPassword.Size        = New-Object System.Drawing.Size(412, 44)
$PanelPassword.Location    = New-Object System.Drawing.Point(14, 76)
$PanelPassword.BackColor   = [System.Drawing.Color]::FromArgb(240, 248, 255)
$PanelPassword.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$PanelPassword.Visible     = $false

$LblPassword = New-Object System.Windows.Forms.Label
$LblPassword.Text      = ""
$LblPassword.Font      = $FontMono
$LblPassword.ForeColor = $ColorPrimary
$LblPassword.AutoSize  = $false
$LblPassword.Size      = New-Object System.Drawing.Size(310, 38)
$LblPassword.Location  = New-Object System.Drawing.Point(8, 6)
$LblPassword.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

$BtnCopy = New-Object System.Windows.Forms.Button
$BtnCopy.Text      = "Copier"
$BtnCopy.Size      = New-Object System.Drawing.Size(82, 30)
$BtnCopy.Location  = New-Object System.Drawing.Point(320, 6)
$BtnCopy.BackColor = [System.Drawing.Color]::FromArgb(230, 244, 255)
$BtnCopy.ForeColor = $ColorPrimary
$BtnCopy.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnCopy.FlatAppearance.BorderColor = $ColorPrimary
$BtnCopy.FlatAppearance.BorderSize  = 1
$BtnCopy.Font      = $FontSmall
$BtnCopy.Cursor    = [System.Windows.Forms.Cursors]::Hand

$BtnCopy.Add_Click({
    if ($LblPassword.Text -ne "") {
        [System.Windows.Forms.Clipboard]::SetText($LblPassword.Text)
        $BtnCopy.Text      = "Copie OK"
        $BtnCopy.BackColor = [System.Drawing.Color]::FromArgb(220, 248, 228)
        $BtnCopy.ForeColor = $ColorSuccess
        $TimerCopy = New-Object System.Windows.Forms.Timer
        $TimerCopy.Interval = 2000
        $TimerCopy.Add_Tick({
            $BtnCopy.Text      = "Copier"
            $BtnCopy.BackColor = [System.Drawing.Color]::FromArgb(230, 244, 255)
            $BtnCopy.ForeColor = $ColorPrimary
            $TimerCopy.Stop()
        })
        $TimerCopy.Start()
    }
})

$PanelPassword.Controls.AddRange(@($LblPassword, $BtnCopy))

$LblExpiry = New-Object System.Windows.Forms.Label
$LblExpiry.Text      = ""
$LblExpiry.Font      = $FontSmall
$LblExpiry.ForeColor = $ColorSubtext
$LblExpiry.AutoSize  = $false
$LblExpiry.Size      = New-Object System.Drawing.Size(410, 16)
$LblExpiry.Location  = New-Object System.Drawing.Point(14, 126)
$LblExpiry.Visible   = $false

$PanelResult.Controls.AddRange(@($LblResultTitle, $LblDevice, $LblPasswordLabel, $PanelPassword, $LblExpiry))

# ─── Status bar ─────────────────────────────────────────────────────────

$StatusBar   = New-Object System.Windows.Forms.StatusStrip
$StatusBar.BackColor = [System.Drawing.Color]::FromArgb(230, 233, 238)
$StatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$StatusLabel.Text      = "Prêt"
$StatusLabel.ForeColor = $ColorSubtext
$StatusLabel.Font      = $FontSmall
$StatusBar.Items.Add($StatusLabel) | Out-Null

# ─── Adding controls to the form ───────────────────────────────────────

$Form.Controls.AddRange(@($PanelHeader, $PanelConn, $PanelSearch, $PanelResult, $StatusBar))

# ─── Connection Status Logic ──────────────────────────────────────────────────

function Set-ConnectedState {
    param([bool]$Connected, [string]$UserName = "")
    $script:IsConnected   = $Connected
    $script:ConnectedUser = $UserName

    if ($Connected) {
        $LblConnStatus.Text       = "Connecté : $UserName"
        $LblConnStatus.ForeColor  = $ColorSuccess
        $StatusDot.BackColor      = $ColorSuccess
        $BtnConnect.Text          = "Déconnecter"
        $BtnConnect.BackColor     = $ColorDanger
        $TxtPC.Enabled            = $true
        $BtnSearch.Enabled        = $true
        $StatusLabel.Text         = "Connecté à Microsoft Graph"
    } else {
        $LblConnStatus.Text       = "Non connecté"
        $LblConnStatus.ForeColor  = $ColorSubtext
        $StatusDot.BackColor      = [System.Drawing.Color]::FromArgb(170, 170, 175)
        $BtnConnect.Text          = "Se connecter"
        $BtnConnect.BackColor     = $ColorPrimary
        $TxtPC.Enabled            = $false
        $BtnSearch.Enabled        = $false
        $TxtPC.Text               = "Ex: PC-DUPONT-01"
        $TxtPC.ForeColor          = $ColorSubtext
        $LblDevice.Text           = ""
        $LblPassword.Text         = ""
        $LblExpiry.Text           = ""
        $LblPasswordLabel.Visible = $false
        $PanelPassword.Visible    = $false
        $LblExpiry.Visible        = $false
        $StatusLabel.Text         = "Déconnecté"
    }
}

# ─── Login button ────────────────────────────────────────────────────────

$BtnConnect.Add_Click({
    if ($script:IsConnected) {
        try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
        Set-ConnectedState -Connected $false
    } else {
        $BtnConnect.Enabled = $false
        $BtnConnect.Text    = "Connexion..."
        $StatusLabel.Text   = "Connexion en cours..."
        $Form.Refresh()

        try {
            Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
            Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop

            Connect-MgGraph `
                -Scopes "DeviceLocalCredential.Read.All","Device.Read.All" `
                -NoWelcome `
                -ErrorAction Stop

            $ctx  = Get-MgContext
            $user = $ctx.Account

            # Verify that the necessary scopes have been granted
            $granted = $ctx.Scopes
            $missing = @()
            if ($granted -notcontains "DeviceLocalCredential.Read.All") { $missing += "DeviceLocalCredential.Read.All" }
            if ($granted -notcontains "Device.Read.All") { $missing += "Device.Read.All" }

            if ($missing.Count -gt 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Connexion réussie mais les permissions suivantes n'ont PAS été accordées :`n`n  - $($missing -join "`n  - ")`n`nUn administrateur doit consentir ces permissions pour l'application 'Microsoft Graph Command Line Tools' dans Entra ID > Applications d'entreprise.",
                    "Permissions manquantes",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning)
            }

            Set-ConnectedState -Connected $true -UserName $user
        } catch {
            $BtnConnect.Text      = "Se connecter"
            $BtnConnect.BackColor = $ColorPrimary
            $StatusLabel.Text     = "Échec de la connexion"
            [System.Windows.Forms.MessageBox]::Show(
                "Impossible de se connecter :`n`n$_",
                "Erreur de connexion",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        $BtnConnect.Enabled = $true
    }
})

# ─── LAPS Search Function ─────────────────────────────────────────────────

function Search-LapsPassword {
    $pcName = $TxtPC.Text.Trim()
    if ($pcName -eq "" -or $pcName -eq "Ex: PC-DUPONT-01") {
        [System.Windows.Forms.MessageBox]::Show("Veuillez entrer un nom de machine.", "Champ vide",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $BtnSearch.Enabled        = $false
    $BtnSearch.Text           = "Recherche..."
    $StatusLabel.Text         = "Recherche de : $pcName"
    $LblDevice.Text           = ""
    $LblPassword.Text         = ""
    $LblExpiry.Text           = ""
    $LblPasswordLabel.Visible = $false
    $PanelPassword.Visible    = $false
    $LblExpiry.Visible        = $false
    $Form.Refresh()

    try {
        # Search for a device by name
        $device = Get-MgDevice -Filter "displayName eq '$pcName'" -ErrorAction Stop

        if (-not $device) {
            $LblDevice.Text      = "Machine introuvable dans Entra ID"
            $LblDevice.ForeColor = $ColorDanger
            $StatusLabel.Text    = "Machine non trouvée"
            return
        }

        # If there are multiple results, take the first one
        if ($device -is [array]) { $device = $device[0] }

        $LblDevice.Text      = "$($device.DisplayName)  (OS: $($device.OperatingSystem))"
        $LblDevice.ForeColor = $ColorSuccess

        # The LAPS API indexes by DeviceId (Azure AD ID), not by object ID
        $azureDeviceId = $device.DeviceId
        if (-not $azureDeviceId) { $azureDeviceId = $device.Id }

        # Retrieving the LAPS Password via the Graph API
        $uri      = "https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials/$azureDeviceId" + '?$select=credentials'
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop

        $creds = $response.credentials
        if (-not $creds -or $creds.Count -eq 0) {
            $LblDevice.Text      = "Machine trouvee, aucun mot de passe LAPS disponible"
            $LblDevice.ForeColor = [System.Drawing.Color]::FromArgb(180, 120, 0)
            $StatusLabel.Text    = "Aucun mot de passe LAPS"
            return
        }

        $cred     = $creds[0]
        $password = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($cred.passwordBase64))

        $LblPassword.Text         = $password
        $LblPasswordLabel.Visible = $true
        $PanelPassword.Visible    = $true

        if ($cred.backupDateTime) {
            try {
                $dt = [System.DateTimeOffset]::Parse(
                    [string]$cred.backupDateTime,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::AssumeUniversal
                ).LocalDateTime
                $LblExpiry.Text    = "Dernière mise à jour : $($dt.ToString('dd/MM/yyyy HH:mm'))"
                $LblExpiry.Visible = $true
            } catch {
                $LblExpiry.Text    = "Dernière mise à jour : $($cred.backupDateTime)"
                $LblExpiry.Visible = $true
            }
        }

        $StatusLabel.Text = "Mot de passe récupéré avec succès"

    } catch {
        $errMsg = $_.Exception.Message
        # Attempt to extract the details from the Graph response body
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            try {
                $errJson = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($errJson.error.message) { $errMsg = $errJson.error.message }
            } catch {}
        }
        $LblDevice.Text      = "Erreur : $errMsg"
        $LblDevice.ForeColor = $ColorDanger
        $StatusLabel.Text    = "Erreur lors de la récupération"
    } finally {
        $BtnSearch.Enabled = $true
        $BtnSearch.Text    = "Rechercher"
    }
}

$BtnSearch.Add_Click({ Search-LapsPassword })

$TxtPC.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        Search-LapsPassword
        $e.SuppressKeyPress = $true
    }
})

# ─── Launch ───────────────────────────────────────────────────────────────

[System.Windows.Forms.Application]::EnableVisualStyles()
[void]$Form.ShowDialog()