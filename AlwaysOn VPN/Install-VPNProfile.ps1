<#
  Author: Dietmar Haimann
  Description:
    This script copies the files needed to C:\Program Files (x86)\AlwaysOn VPN and registers the scheduled task.
    Use this script for your ConfigMgr Application to install the profile ONCE per device.
    So you are able to install the profile during OSD too.
    The scheduled task installs the profile for every user who logs on.
  
  Files:
    VPN_Profile_User.ps1
    SetAlwaysOnVPNUserProfile.xml
    Version*.txt
    
  Commandline to run via ConfigMgr Application:
    powershell.exe -ExecutionPolicy ByPass -NoProfile -File "Install_VPNProfile.ps1"
  Detection Method:
    Version191202.txt exists
#>

# Copy files
$FilePath = $PSScriptRoot
$Destination = "${env:ProgramFiles(x86)}\AlwaysOn VPN"
If (Test-Path -Path "$Destination") {
    Remove-Item -Path "$Destination" -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path "$Destination" -Force -ItemType Directory
Get-ChildItem -Path "$FilePath\VPN_Profile_User.ps1" | Copy-Item -Destination $Destination -Force
Get-ChildItem -Path "$FilePath\SetAlwaysOnVPNUserProfile.xml" | Copy-Item -Destination $Destination -Force
Get-ChildItem -Path "$FilePath\Version*.txt" | Copy-Item -Destination $Destination -Force

# Import scheduled task
$Task = Get-Content -Path "$Destination\SetAlwaysOnVPNUserProfile.xml" | Out-String
$null = Register-ScheduledTask -Xml $Task -Force -TaskName "Set AlwaysOn VPN User Profile"
