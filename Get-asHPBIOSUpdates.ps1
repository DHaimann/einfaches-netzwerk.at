<#
	Author: Dietmar Haimann
	Requirements:
		Must have:
			Client Management Solutions - HP Client Management Script Library
			https://ftp.hp.com/pub/caps-softpaq/cmit/hp-cmsl.html
		
			ConfigMgr-Console installed
			
			The followings folders:
				C:\Util\DriverFactory\ 				> place the script in this folder
				C:\Util\DriverFactory\Extrafiles 	> place the password.bin, ssm.cab and ssm.exe in this folder
				C:\Util\DriverFactory\Models		> place the HPModels.csv in this folder
				C:\DriverFactory					> this is the folder where the magic happens (automatically created)
				
			File called C:\Util\DriverFactory\Models\HPModels.csv with the following content:
			
			Manufacturer;HPModel;ProdCode
			HP;HP EliteBook 840 G1;198F
			HP;HP EliteBook 840 G2;2216
			HP;HP EliteBook 840 G3;8079
			
			Network share for source files like
			\\fileserver\Sources$\OSD\HP BIOS Update Packages
			
			Search for #modify on the left and adjust for your needs!
			
		Optional:
			SMTP Username and Password
			SMTP Server Name
			Sender E-Mail Address
			Recipient E-Mail Address
			
			Microsoft Teams with configured incoming webhook
			https://www.scconfigmgr.com/2017/10/06/configmgr-osd-notification-service-teams/
			
	Description:
		The script does the following:
			Creates folders C:\DriverFactory\Download, C:\DriverFactory\Extracted, C:\DriverFactory\TempFolder
			Reads HPModels.csv
			Connects to HP and fetch BIOS version for models
			Compairs the existing ConfigMgr package version
			If version is different it downloads the new version
			Extracts the files and copies the files to file server
				\\fileserver\Sources$\OSD\HP BIOS Update Packages\HP EliteDesk 800 G5 DM 65W\02.02.00
				\\fileserver\Sources$\OSD\HP BIOS Update Packages\HP EliteDesk 800 G5 DM 65W\02.03.01
				...
			Creates ConfigMgr package in configurable folder structure
				Manufacturer:	HP
				Name:			BIOS - HP EliteDesk 800 G5 DM 65W\02
				Version:		02.03.01
				Description:	Model 8594, Version 02.03.01, Release Date 2019-10-15
				
			Distributes the package to DP group
			Writes cmtrace readable log to C:\DriverFactory\Get-asHPBIOSUpdates.log
				Could not retrieve BIOS information for Model HP Z4 G4 Workstation Win10 1909	Get-asHPBIOSUpdates	28.10.2019 10:50:27	0 (0x0000)
				Will try older Win10 version	Get-asHPBIOSUpdates	28.10.2019 10:50:27	0 (0x0000)
				@{Id=sp99558; Name=HP Z4G4 Workstation System BIOS; Category=BIOS; Version=01.86; Vendor=HP Inc.; ReleaseType=Recommended; SSM=true; DPB=false; Url=ftp.hp.com/pub/softpaq/sp99501-100000/sp99558.exe; ReleaseNotes=ftp.hp.com/pub/softpaq/sp99501-100000/sp99558.html; Metadata=ftp.hp.com/pub/softpaq/sp99501-100000/sp99558.cva; MD5=48d9197e84227ae16dbc94349412542a; Size=31021840; ReleaseDate=2019-10-08}	Get-asHPBIOSUpdates	28.10.2019 10:50:30	0 (0x0000)
				ConfigMgr package <PACKAGEID> version for HP Z4 G4 Workstation is 01.83, update available to 01.86	Get-asHPBIOSUpdates	28.10.2019 10:50:30	0 (0x0000)
				C:\DriverFactory\Temp created	Get-asHPBIOSUpdates	28.10.2019 10:50:30	0 (0x0000)
				C:\DriverFactory\Extracted\HP Z4 G4 Workstation\01.86 created	Get-asHPBIOSUpdates	28.10.2019 10:50:30	0 (0x0000)
				SP99558.exe downloaded	Get-asHPBIOSUpdates	28.10.2019 10:50:50	0 (0x0000)
				SP99558.cva downloaded	Get-asHPBIOSUpdates	28.10.2019 10:50:50	0 (0x0000)
				DriverPackInfo.xml created in C:\DriverFactory\Extracted\HP Z4 G4 Workstation\01.86	Get-asHPBIOSUpdates	28.10.2019 10:50:50	0 (0x0000)
				Driver package files copied to C:\DriverFactory\Extracted\HP Z4 G4 Workstation\01.86	Get-asHPBIOSUpdates	28.10.2019 10:50:50	0 (0x0000)
				C:\Util\DriverFactory\Extrafiles\HPBios copied to C:\DriverFactory\Extracted\HP Z4 G4 Workstation\01.86	Get-asHPBIOSUpdates	28.10.2019 10:50:50	0 (0x0000)
				Package files copied to x:\OSD\HP BIOS Update Packages\HP Z4 G4 Workstation\01.86	Get-asHPBIOSUpdates	28.10.2019 10:50:56	0 (0x0000)
				Will create ConfigMgr package now...	Get-asHPBIOSUpdates	28.10.2019 10:50:56	0 (0x0000)
				ConfigMgr package BIOS - HP Z4 G4 Workstation with ID <ID> created	Get-asHPBIOSUpdates	28.10.2019 10:50:58	0 (0x0000)
				ConfigMgr package BIOS - HP Z4 G4 Workstation distributed to <DP GROUP> - 2 Distribution Points	Get-asHPBIOSUpdates	28.10.2019 10:50:59	0 (0x0000)
			
			Sends summary via E-Mail
			Sends summary to Microsoft Teams
			
	Thanks:
		Adam Bertram
			@adbertram
			https://adamtheautomator.com/send-mailmessage/
			https://adamtheautomator.com/building-logs-for-cmtrace-powershell/
		
		Terence Beggs
			@terencebeggs
			https://www.scconfigmgr.com/2017/10/06/configmgr-osd-notification-service-teams/
		
		Jordan Benzing
			@JordanTheITguy
			https://www.scconfigmgr.com/2018/07/12/send-your-patching-manifest-to-teams/
			
		Gary Blok
			@gwblok
			https://garytown.com/hp-driver-packs-download-cm-import-via-powershell/
			
		Nathan Kofahl
			@nkofahl
			https://twitter.com/nkofahl
		
		... and so many more!
#>

Function Start-asLog {
    [CmdletBinding()]
    Param (
        [ValidateScript({ Split-Path $_ -Parent | Test-Path })]
        [string]
        $FilePath
    )
     
    Try {
        If (!(Test-Path $FilePath)) {
            New-Item $FilePath -Type File | Out-Null
        }
        $Global:ScriptLogFilePath = $FilePath
    }
    Catch {
        Write-Error $_.Exception.Message
    }
}

Function Write-asLog {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]
        $Message,
         
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [int]
        $LogLevel = 1
    )
 
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), $Global:Component, $LogLevel
    $Line = $Line -f $LineFormat
    Add-Content -Value $Line -Path $Global:ScriptLogFilePath
}

Function Write-asMail {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]
        $Message,
         
        [Parameter()]
        [ValidateSet('Black', 'Red', 'Green')]
        [string]
        $Color = 'Black',

        [Parameter()]
        [switch]
        $Bold
    )
    
    If ($Bold) {
        $Global:EmailArray += "<font color=$Color><b>$Message</b></font><br>" 
    } else {
        $Global:EmailArray += "<font color=$Color>$Message</font><br>"    
    }
}

Function Send-asMail {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]
        $To,

        [Parameter(Mandatory = $true)]
        [string]
        $Subject,

        [Parameter(Mandatory = $false)]
        [string]
        $Attachement
    )

#modify
    $Username = "<YOUR USER NAME>"
    $Password = ConvertTo-SecureString "<PASSWORD>" -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential ("$Username", $Password)

    $sendMailParameters = @{
        From = "<SENDER EMAIL ADDRESS>"
        To = $To
        Subject = $Subject
        Body = "$Global:EmailArray"
        BodyAsHtml = $true
        Encoding = "UTF8"
        SmtpServer = "<SMTP SERVER>"
        Port = 587
        Credential = $Credentials
        UseSsl = $true
    }
    
    If ($Attachement) {
        Send-MailMessage @sendMailParameters -Attachments $Attachement
    } Else {
        Send-MailMessage @sendMailParameters
    }
}

Function New-asTeamsMessage {
    $Global:FactsArray = @()
}

Function Write-asTeamsMessage {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]
        $MessageName,

        [Parameter(Mandatory = $true)]
        [string]
        $MessageValue
    )

    $FactsTable = @{
        Name = ''
        Value = ''
    }

    $FactsTable.Name = $MessageName
    $FactsTable.Value = $MessageValue
    $Global:FactsArray += $FactsTable    
}

Function Send-asTeamsMessage {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]
        $MessageTitle,

        [Parameter(Mandatory = $false)]
        [string]
        $MessageText,

        [Parameter(Mandatory = $true)]
        [string]
        $ActivityTitle,

        [Parameter(Mandatory = $true)]
        [string]
        $ActivitySubtitle,

        [Parameter(Mandatory = $true)]
        [string]
        $ActivityText,

        [Parameter(Mandatory = $false)]
        [string]
        $ActivityImagePath,

        [Parameter(Mandatory = $false)]
        [string]
        $ButtonName,

        [Parameter(Mandatory = $false)]
        [string]
        $ButtonUri
    )
    
#modify
    $Url = "<YOUR URI>"
    
    $Body = ConvertTo-Json -Depth 4 @{
        title = $MessageTitle
        text = $MessageText
        sections = @(
            @{
                activityTitle = "**$ActivityTitle**"
                activitySubtitle = $ActivitySubtitle
                activityText = $ActivityText
                activityImage = $ActivityImagePath 
            },
            @{
                facts = $Global:FactsArray
            }
        )
        potentialAction = @(
            @{
                "@type" = "OpenUri"
                name = $ButtonName
                targets = @(
                    @{
                        os = "default"
                        uri = $ButtonUri
                    }
                )
            }
        )
    }        

    Try {
        $null = Invoke-RestMethod -uri $Url -Method Post -body $Body -ContentType 'application/json' -ErrorAction Stop
        Write-Host "Successfully sent to Microsoft Teams" -ForegroundColor Green
    }

    Catch {
        Write-Host "Couldn't send to Microsoft Teams" -ForegroundColor Red
    }
}

Function Test-asIsAdmin {
    $Global:Component = $MyInvocation.MyCommand.Name
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Output "Uups, you do not have admin rights to run this script.`nPlease re-run this script as an Administrator!"
        Write-asLog -Message "Uups, you do not have admin rights to run this script. Please re-run this script as an Administrator!" -LogLevel 3
        Break
    } Else {
        Write-asLog -Message "Script runs with admin rights" -LogLevel 1
    }
}

Function Import-asCMModule {
#modify
    $Global:SiteCode = "<SITE CODE>"
    $ProviderMachineName = "<SITE SERVER>"
    $Global:Component = $MyInvocation.MyCommand.Name
 
    If ((Get-Module ConfigurationManager) -eq $null) {
        Try {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
            Write-asLog "ConfigMgr-Module successful imported" -LogLevel 1
        }
        Catch {
            Write-Output "Uups, could not import the ConfigMgr-Module."
            Write-asLog "Uups, could not import the ConfigMgr-Module" -LogLevel 3
            Break
        }
    } Else {
        Write-asLog "ConfigMgr-Module already imported" -LogLevel 1
    }
 
    If ((Get-PSDrive -Name $Global:SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
        New-PSDrive -Name $Global:SiteCode -PSProvider CMSite -Root $ProviderMachineName
    }
 
    $Global:CurrentLocation = Get-Location
}

function Get-asHPBIOSUpdates {
      [CmdletBinding()]
      param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $CSVPath,

        [Parameter()]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $ExtraFiles
    )

    BEGIN {
        $Global:Component = $MyInvocation.MyCommand.Name
        $StartTime = (Get-Date).ToString()
		
		$LocalRootFolder = 'C:\DriverFactory'
        
        #Ordner bereinigen und neu erstellen
        If (!(Test-Path -Path $LocalRootFolder)) {
			$null = New-Item -Path $LocalRootFolder -ItemType Directory -Force
		}

        # Start logging
        Start-asLog -FilePath ("$LocalRootFolder\" + "$Global:Component" + ".log")
        Write-asLog " "
        Write-asLog "-----------------------------------------------------------"
        Write-asLog -Message "Execute function $Global:Component" -LogLevel 1

        #Auf Admin prüfen
        Test-asIsAdmin

        #ConfigMgr-Modul importieren
        Import-asCMModule
        $Global:Component = $MyInvocation.MyCommand.Name

        #Set EmailArray
#modify
        $Global:EmailArray = @()
        $MailTo = "<RECIPIENT EMAIL ADDRESS>"
        $MailSubject = "$Global:Component"
        Write-asMail -Message "Summary about the execution of $Global:Component" -Color Black -Bold
        Write-asMail -Message " "
        
        #CSV imporieren
        $HPModels = Import-Csv -Delimiter ';' -Path $CSVPath
        Write-asLog "HP Models imported from $CSVPath" -LogLevel 1

        #File Server
#modify
        $FileServerName = '<FILE SERVER NAME>'
        $LocalRootFolder = 'C:\DriverFactory'
        
        #Ordner bereinigen und neu erstellen
        $DownloadFolder = Join-Path "$LocalRootFolder" "Download"
        If (Test-Path -Path $DownloadFolder) {
            Remove-Item -Path $DownloadFolder -Recurse -Force -ErrorAction SilentlyContinue            
        }
        $null = New-Item -Path $DownloadFolder -ItemType Directory -Force
        Write-asLog -Message "$DownloadFolder cleaned up" -LogLevel 1

        # Cleanup Extract folder
        $ExtractFolder = Join-Path "$LocalRootFolder" "Extracted"
        If (Test-Path -Path $ExtractFolder) {
            Remove-Item -Path $ExtractFolder -Recurse -Force -ErrorAction SilentlyContinue            
        }
        $null = New-Item -Path $ExtractFolder -ItemType Directory -Force
        Write-asLog -Message "$ExtractFolder cleaned up" -LogLevel 1

        Try {
            Test-Connection -ComputerName $FileServerName -Quiet -ErrorAction Stop | Out-Null
            Write-asLog "Fileserver $FileServerName is reachable. Packages will be copied." -LogLevel 1

#modify
            # Create file server target root path
            $FileServerTargetRoot = "\\" + "$FileServerName"
            $FileServerTargetRoot = Join-Path "$FileServerTargetRoot" "<SHARENAME>\<FOLDER>"

            $SMBShare = New-SmbMapping -LocalPath x: -RemotePath $FileServerTargetRoot -Persistent $false
            $DownloadToServer = $true
        }
        Catch {
            Write-asLog -Message "Fileserver $FileServerName not reachable. Packages will not be copied." -LogLevel 2   
            $DownloadToServer = $false
        }

        #Create fallbacks to next available os version
        $OS = 'Win10'
        $OSVersions = @(
            1909,
            1903,
            1809,
            1803,
            1709
        )
                
    } #BEGIN

    PROCESS {
        foreach ($HPModel in $HPModels) {
            $HPBIOSModelName = $HPModel.HPModel
            $HPBIOSProdCode = $HPModel.ProdCode
            $HPBIOSManufacturer = $HPModel.Manufacturer
            Write-asLog -Message "Checking $HPBIOSModelName product code $HPBIOSProdCode for BIOS update" -LogLevel 1
            
            #Get Softpaq infos for each Windows 10 version
            foreach ($OSVersion in $OSVersions) {
                Try {
                    $Softpaq = Get-SoftpaqList -platform $HPBIOSProdCode -os $OS -osver $OSVersion -ErrorAction Stop
                    $DriverPack = $Softpaq | Where-Object {$_.Category -like "*BIOS*"}
                    $DriverPack = $DriverPack | Where-Object { $_.Name -notmatch "Windows PE" } | Where-Object { $_.Name -notmatch "Win PE" } | Where-Object { $_.Name -notmatch "WinPE" }
                    $DriverPack = $DriverPack | Select-Object -Index 0
                    Write-asLog -Message $DriverPack -LogLevel 1
                    break
                }
                Catch {
                    Write-asLog -Message "Could not retrieve BIOS information for Model $HPBIOSModelName Win10 $OSVersion" -LogLevel 2
                    Write-asLog -Message "Will try older $OS version" -LogLevel 2                
                }            
            }

            If ($DriverPack) {
                $DriverPackVersion = $DriverPack.Version
                $DriverPackId = "$($DriverPack.Id)".ToUpper()
                $DriverPackReleaseDate = $DriverPack.ReleaseDate

                #Create Download folder
                $HPBIOSDownloadFolder = Join-Path "$DownloadFolder" "$HPBIOSModelName"
                $HPBIOSDownloadFolder = Join-Path "$HPBIOSDownloadFolder" "$DriverPackVersion"
                $SaveAs = Join-Path "$HPBIOSDownloadFolder" "$($DriverPackId).exe"
                $SaveAsCVA = Join-Path "$HPBIOSDownloadFolder" "$($DriverPackId).cva"

                # Check package version of downlad
                Set-Location -Path "$($Global:SiteCode):"
                $PackageFullInformation =""
                $PackageInfoVersion = ""                
                $PackageFullInformation = Get-CMPackage -Name "BIOS - $HPBIOSModelName" -Fast
                
                #Set ExecuteDownload to true, changes if version is current
                $ExecuteDownload = $true
                
                Set-Location -Path "$($Global:CurrentLocation)"
                
				# This is necessary because of multiple BIOS packages
                If (!($PackageFullInformation -eq '')) {
                    foreach ($PackageInfo in $PackageFullInformation) {
                        # Create package variables
                        $PackageInfoName = $PackageInfo.Name
                        $PackageInfoPackageID = $PackageInfo.PackageID                    
                        $PackageInfoVersion = $PackageInfo.Version

                        If ($PackageInfoVersion -eq $DriverPackVersion) {
                            Write-asLog -Message "ConfigMgr package $PackageInfoPackageID version for $HPBIOSModelName is $PackageInfoVersion, current" -LogLevel 1
                            $ExecuteDownload = $false
                        } Else {                        
                            Write-asLog -Message "ConfigMgr package $PackageInfoPackageID version for $HPBIOSModelName is $PackageInfoVersion, update available to $DriverPackVersion" -LogLevel 1
                        }                   
                    }
                } Else {
                    Write-asLog -Message "ConfigMgr package for $HPBIOSModelName not found. Create one." -LogLevel 2
                }
                
                If ($ExecuteDownload) {               
                    # Create download path
                    If (Test-Path -Path $HPBIOSDownloadFolder) {
                        Remove-Item -Path "$HPBIOSDownloadFolder" -Recurse -Force -ErrorAction SilentlyContinue
                    }                    
                    $null = New-Item -Path "$HPBIOSDownloadFolder" -ItemType Directory -Force
                    
                    # Create Temp path
                    $TempFolder = Join-Path "$LocalRootFolder" "Temp"
                    If (Test-Path -Path $TempFolder) {
                        Remove-Item -Path $TempFolder -Recurse -Force -ErrorAction SilentlyContinue                        
                    }
                    $null = New-Item -Path $TempFolder -ItemType Directory -Force
                    Write-asLog -Message "$TempFolder created" -LogLevel 1

                    # Create extract folder
                    $ExtractFolderfull = Join-Path "$ExtractFolder" "$HPBIOSModelName"
                    $ExtractFolderfull = Join-Path "$ExtractFolderfull" "$DriverPackVersion"
                    If (Test-Path -Path $ExtractFolderfull) {
                        Remove-Item -Path $ExtractFolderfull -Recurse -Force -ErrorAction SilentlyContinue                        
                    }
                    $null = New-Item -Path $ExtractFolderfull -ItemType Directory -Force
                    Write-asLog -Message "$ExtractFolderfull created" -LogLevel 1

                    #Download Package
                    Get-Softpaq -number $DriverPackId -saveAs $SaveAs -overwrite yes
                    Write-asLog -Message "$DriverPackId.exe downloaded" -LogLevel 1
                   
                    #Download cva-File
                    Get-SoftpaqMetadataFile -number $DriverPackId -saveAs $SaveAsCVA -overwrite yes
                    Write-asLog -Message "$DriverPackId.cva downloaded" -LogLevel 1

                    $null = Copy-Item -Path "$HPBIOSDownloadFolder\*" -Destination "$ExtractFolderfull" -Force
                    Export-Clixml -InputObject $DriverPack -Path "$($ExtractFolderfull)\DriverPackInfo.xml"
                    Write-asLog -Message "DriverPackInfo.xml created in $ExtractFolderfull" -LogLevel 1                    
                    Write-asLog -Message "Driver package files copied to $ExtractFolderfull" -LogLevel 1

                    # Copy extra files
                    If ($ExtraFiles) {                    
                        $null = Copy-Item -Path "$ExtraFiles\*" -Destination "$ExtractFolderfull" -Force
                        Write-asLog -Message "$ExtraFiles copied to $ExtractFolderfull" -LogLevel 1
                    }                    

                    #Copy files to server
                    If ($DownloadToServer) {
                        #Create server path
#modify
                        $PackageSourceFull = "$($SMBShare.LocalPath)" 
                        $PackageSourceFull = Join-Path "$PackageSourceFull" "OSD" 
                        $PackageSourceFull = Join-Path "$PackageSourceFull" "HP BIOS Update Packages"
                        $PackageSourceFull = Join-Path "$PackageSourceFull" "$HPBIOSModelName"
                        $PackageSourceFull = Join-Path "$PackageSourceFull" "$DriverPackVersion"

                        If (Test-Path -Path "$PackageSourceFull") {
                            Remove-Item -Path "$PackageSourceFull" -Recurse -Force -ErrorAction SilentlyContinue
                        }

                        Start-Sleep -Seconds 5
                        
                        $null = Copy-Item -Path "$ExtractFolderfull" -Destination "$PackageSourceFull" -Container -Force -Recurse
                        Write-asLog -Message "Package files copied to $PackageSourceFull" -LogLevel 1
                        Write-asLog -Message "Will create ConfigMgr package now..." -LogLevel 1

                        #ConfigMgr package
#modify
                        Set-Location -Path "$($Global:SiteCode):"
                        $DPGroup = Get-CMDistributionPointGroup -Name "<DISTRIBUTION POINT GROUP NAME>"

                        #Package definition
                        $NewPackageManufacturer = $HPBIOSManufacturer
                        $NewPackageName = "BIOS - $HPBIOSModelName"
                        $NewPackageDescription = "Model $HPBIOSProdCode, Version $DriverPackVersion, Release Date $DriverPackReleaseDate"
                        $NewPackageVersion = "$DriverPackVersion"
#modify 
						$NewPackageFolderPath = ".\Package\<PATH TO BIOS PACKAGES>\$NewPackageManufacturer"
                           
                        #Create new Package source Path 
                        $NewPackageSourcePath = Join-Path $FileServerTargetRoot "OSD"
                        $NewPackageSourcePath = Join-Path $NewPackageSourcePath "HP BIOS Update Packages"
                        $NewPackageSourcePath = Join-Path $NewPackageSourcePath "$HPBIOSModelName"
                        $NewPackageSourcePath = Join-Path $NewPackageSourcePath "$DriverPackVersion"
                        
                        #Package creation
                        $NewPackage = New-CMPackage -Name $NewPackageName -Description $NewPackageDescription -Manufacturer $NewPackageManufacturer -Version $NewPackageVersion -Path $($NewPackageSourcePath)
                        $NewPackage | Set-CMPackage -EnableBinaryDeltaReplication $true
                        $NewPackage | Move-CMObject -FolderPath $NewPackageFolderPath
                        Write-asLog -Message "$($NewPackage.PackageID) ConfigMgr package $NewPackageName created" -LogLevel 1
                        Write-asMail -Message "$($NewPackage.PackageID) ConfigMgr package $NewPackageName created" -Color Green
						Write-asTeamsMessage -MessageName $($NewPackage.PackageID) -MessageText "ConfigMgr package $NewPackageName created"
						
                        #Package distribution
                        Get-CMPackage -Id $($NewPackage.PackageID) -Fast | Start-CMContentDistribution -DistributionPointGroupName "$($DPGroup.Name)"
                        Write-asLog -Message "ConfigMgr package $NewPackageName distributed to $($DPGroup.Name) - $($DPGroup.MemberCount) Distribution Points" -LogLevel 1
                        Set-Location -Path "$($Global:CurrentLocation)"                        
                    }
                }
            }
        } #foreach

    } #PROCESS

    END {
        $SMBShare | Remove-SmbMapping -Force
        $EndTime = (Get-Date).ToString()
        $RunTime = [math]::Round($((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes), 2)
		#Send Email Message
        Write-asMail " "
        Write-asMail "Script finished" -Bold
        Write-asMail "Total script time $RunTime minutes"
        Send-asMail -To $MailTo -Subject $MailSubject -Attachement $Global:ScriptLogFilePath
	    #Send Teams Message
		Send-asTeamsMessage -MessageTitle "HP BIOS Updates" `
			-MessageText " " `
			-ActivityTitle "DriverFactory" `
			-ActivitySubtitle "$(Get-Date -UFormat "%d.%m.%Y, %R")" `
			-ActivityText "Erfolgreich beendet" `
			-ActivityImagePath "https://www8.hp.com/at/de/images/i/hpi/header-footer/caas-hf-v3.2/hpi-hp-logo-pr.gif" `
			-ButtonName "HP Support" `
			-ButtonUri "https://support.hp.com/at-de/drivers"
		#Finish log entries	
        Write-asLog -Message "Mail with subject $MailSubject sent to $MailTo" -LogLevel 1
        Write-asLog -Message "Script finished" -LogLevel 1
        Write-asLog -Message "Total script time $RunTime minutes" -LogLevel 1
    } #END
} #function

Get-asHPBIOSUpdates -CSVPath "C:\Util\DriverFactory\Models\HPModels.csv" -ExtraFiles "C:\Util\DriverFactory\Extrafiles\HPBios"
