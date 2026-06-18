# Remove the auto log on user
Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath -like "*\AutoTomBot"} | Remove-CimInstance  
Remove-LocalUser -Name "AutoTomBot"
#Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath -like "*\AutoTomBot.DESKTOP-2D8C0IR"} | Remove-CimInstance  

# Disable Auto log on
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "0"
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoLogonSID"
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName"
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword"

# (Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon").GetValue("AutoAdminLogon") 


# Restore the memory
#bcdedit /deletevalue "{current}" removememory

Write-Host "Assuming no errors, AutoTomBot deleted, autologon disable and removememory removed".