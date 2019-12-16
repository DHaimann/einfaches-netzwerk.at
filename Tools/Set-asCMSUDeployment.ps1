Function Test-asIsAdmin {
    $Global:Component = $MyInvocation.MyCommand.Name
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Output "Uups, you do not have admin rights to run this script.`nPlease re-run this script as an Administrator!"
        Break
    } Else {
        Write-Output "Script runs with admin rights"
    }
}

Function Import-asCMModule {
    $Global:SiteCode = "<sitecode>"
    $ProviderMachineName = "<siteserver>"
    $Global:Component = $MyInvocation.MyCommand.Name
 
    If ((Get-Module ConfigurationManager) -eq $null) {
        Try {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
        }
        Catch {
            Write-Output "Uups, could not import the ConfigMgr-Module."
            Break
        }
    }
 
    If ((Get-PSDrive -Name $Global:SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
        New-PSDrive -Name $Global:SiteCode -PSProvider CMSite -Root $ProviderMachineName
    }
 
    $Global:CurrentLocation = Get-Location
}

Function Set-asCMSUDeployment {
    BEGIN {
        # Check admin if needed
        Test-asIsAdmin
        $Global:Component = $MyInvocation.MyCommand.Name

        #Import ConfigMgr-Modul if needed
        Import-asCMModule
        $Global:Component = $MyInvocation.MyCommand.Name
    }

    PROCESS {
        $CurrentLocation = Get-Location
        Set-Location "$($SiteCode):\"

        # Build date format to determine Windows Update Group
        $Month = Get-Date -UFormat %Y-%m

        # Get the next possible deployment starttime and deadline
        $Date = Get-Date

        for($i=1; $i -le 7; $i++)
        {        
            If ($Date.AddDays($i).DayOfWeek -eq 'Monday')
            {
                $NextMonday = $Date.AddDays($i)
                $StartRing2 = (($NextMonday).Date).AddHours(4)
                $DeadlineRing2 = (($NextMonday).Date).AddHours(12)
                $StartRing3 = (($NextMonday.AddDays(7)).Date).AddHours(4)
                $DeadlineRing3 = (($NextMonday.AddDays(7)).Date).AddHours(12)
                $StartProd = (($NextMonday.AddDays(21)).Date).AddHours(4)
                $DeadlineProd = (($NextMonday.AddDays(24)).Date).AddHours(12)
                break
            }
        }

        # Get Software Update Group
        $SUGroup = Get-CMSoftwareUpdateGroup -Name "Microsoft Software*$($Month)*"

        # Rename and enable RING 1 Deployment
        Get-CMSoftwareUpdateDeployment -Name *$($Month)* | Set-CMSoftwareUpdateDeployment -NewDeploymentName "Microsoft Software Updates $($Month) Ring 1" -Enable $true | Out-Null

        # Create RING 2 Deployment
        $SUGroup | `
        New-CMSoftwareUpdateDeployment -DeploymentName "Microsoft Software Updates $($Month) Ring 2" -Description "Microsoft Software Updates -Ring 2" -CollectionName "Software Updates - Ring 2" `
        -DeploymentType Required -SendWakeupPacket $false -VerbosityLevel OnlyErrorMessages `
        -TimeBasedOn LocalTime -AvailableDateTime $StartRing2 -DeadlineDateTime $DeadlineRing2 `
        -UserNotification DisplaySoftwareCenterOnly -SoftwareInstallation $true -AllowRestart $false -RestartServer $true -RestartWorkstation $true -PersistOnWriteFilterDevice $false -RequirePostRebootFullScan $true `
        -GenerateSuccessAlert $false -DisableOperationsManagerAlert $false -GenerateOperationsManagerAlert $false `
        -ProtectedType RemoteDistributionPoint -UnprotectedType UnprotectedDistributionPoint -DownloadFromMicrosoftUpdate $false -UseMeteredNetwork $false -UseBranchCache $true | Out-Null

        # Create RING 3 Deployment
        $SUGroup | `
        New-CMSoftwareUpdateDeployment -DeploymentName "Microsoft Software Updates $($Month) Ring 3" -Description "Microsoft Software Updates - Ring 3" -CollectionName "Software Updates - Ring 3" `
        -DeploymentType Required -SendWakeupPacket $false -VerbosityLevel OnlyErrorMessages `
        -TimeBasedOn LocalTime -AvailableDateTime $StartRing3 -DeadlineDateTime $DeadlineRing3 `
        -UserNotification DisplaySoftwareCenterOnly -SoftwareInstallation $true -AllowRestart $false -RestartServer $true -RestartWorkstation $true -PersistOnWriteFilterDevice $false -RequirePostRebootFullScan $true `
        -GenerateSuccessAlert $false -DisableOperationsManagerAlert $false -GenerateOperationsManagerAlert $false `
        -ProtectedType RemoteDistributionPoint -UnprotectedType UnprotectedDistributionPoint -DownloadFromMicrosoftUpdate $false -UseMeteredNetwork $false -UseBranchCache $true | Out-Null

        # Create RING Prod Deployment
        $SUGroup | `
        New-CMSoftwareUpdateDeployment -DeploymentName "Microsoft Software Updates $($Month) Prod" -Description "Microsoft Software Updates - Prod" -CollectionName "Software Updates - Prod" `
        -DeploymentType Required -SendWakeupPacket $false -VerbosityLevel OnlyErrorMessages `
        -TimeBasedOn LocalTime -AvailableDateTime $StartProd -DeadlineDateTime $DeadlineProd `
        -UserNotification DisplaySoftwareCenterOnly -SoftwareInstallation $true -AllowRestart $false -RestartServer $true -RestartWorkstation $true -PersistOnWriteFilterDevice $false -RequirePostRebootFullScan $true `
        -GenerateSuccessAlert $true -PercentSuccess 95 -TimeValue 3 -TimeUnit Weeks -DisableOperationsManagerAlert $false -GenerateOperationsManagerAlert $false `
        -ProtectedType RemoteDistributionPoint -UnprotectedType UnprotectedDistributionPoint -DownloadFromMicrosoftUpdate $false -UseMeteredNetwork $false -UseBranchCache $true | Out-Null

        # Rename Software Update Group
        $SUGroup | Set-CMSoftwareUpdateGroup -NewName "Microsoft Software Updates $($Month)" | Out-Null
            }

    END {
        Set-Location $CurrentLocation
    }
}