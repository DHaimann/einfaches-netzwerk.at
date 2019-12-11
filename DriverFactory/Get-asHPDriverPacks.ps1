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

    $Username = $($Global:Settings.MailUserName)
    $Password = ConvertTo-SecureString $($Global:Settings.MailPassword) -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential ("$Username", $Password)

    $sendMailParameters = @{
        From = $($Global:Settings.MailFrom)
        To = $To
        Subject = $Subject
        Body = "$Global:EmailArray"
        BodyAsHtml = $true
        Encoding = "UTF8"
        SmtpServer = $($Global:Settings.MailSMTPServer)
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
    
    $Url = $($Global:Settings.TeamsURI)
    
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
        Write-asLog -Message "Successfully sent to Teams" -LogLevel 1
    }

    Catch {
        Write-asLog -Message "Couldn't send to Teams" -LogLevel 3
    }
}

Function Test-asIsAdmin {
    $Global:Component = $MyInvocation.MyCommand.Name
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Output "Uups, you do not have admin rights to run this script.`nPlease re-run this script as an Administrator!"
        Write-asLog -Message "Uups, you do not have admin rights to run this script.Please re-run this script as an Administrator!" -LogLevel 3
        Break
    } Else {
        Write-asLog -Message "Script runs with admin rights" -LogLevel 1
    }
}

Function Import-asCMModule {
    $Global:SiteCode = $($Global:Settings.CMSiteCode)
    $ProviderMachineName = $($Global:Settings.CMProviderMachineName)
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

Function Get-asHPDriverPacks {
      [CmdletBinding()]
      param (
        [switch]
        $SendMail,

        [switch]
        $SendTeams
    )

    BEGIN {
        $Global:Component = $MyInvocation.MyCommand.Name
        $StartTime = (Get-Date).ToString()
        
        # Import global settings
        $Global:Settings = Get-Content -Raw -Path "$PSScriptRoot\DriverFactory.json" | ConvertFrom-Json

        # Prepare DriverFactory root folder to be able to create log file
		$LocalRootFolder = $($Global:Settings.LocalRootFolder)
        If (!(Test-Path -Path $LocalRootFolder)) {
			$null = New-Item -Path $LocalRootFolder -ItemType Directory -Force    
        }        

        # Start logging
        Start-asLog -FilePath ("$LocalRootFolder\" + "$Global:Component" + ".log")
        Write-asLog " "
        Write-asLog "-----------------------------------------------------------"
        Write-asLog -Message "Execute function $Global:Component" -LogLevel 1

        # Test admin rights
        Test-asIsAdmin

        # Import ConfigMgr-Module
        Import-asCMModule
        $Global:Component = $MyInvocation.MyCommand.Name

        # Set Email array
        $Global:EmailArray = @()
        $MailTo = $($Global:Settings.MailMailTo)
        $MailSubject = "$Global:Component"
        Write-asMail -Message "Summary about the execution of $Global:Component" -Color Black -Bold
        Write-asMail -Message " "

        # Create empty Teams message facts array
        New-asTeamsMessage
        
        # Import ModelsHPCSV
        $HPModels = Import-Csv -Delimiter ';' -Path $($Global:Settings.ModelsHPCSV)
        Write-asLog "HP Models imported from $($Global:Settings.ModelsHPCSV)" -LogLevel 1

        # Clear Download folder
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

        # File Server
        $FileServerName = $($Global:Settings.FileServerName)

        Try {
            Test-Connection -ComputerName $FileServerName -Quiet -ErrorAction Stop | Out-Null
            Write-asLog "Fileserver $FileServerName is reachable - Packages will be copied" -LogLevel 1

            # Create file server target root path
            $FileServerTargetRoot = "\\" + "$FileServerName"
            $FileServerTargetRoot = Join-Path "$FileServerTargetRoot" "$($Global:Settings.FileServerShareName)"

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
            $HPModelHPModel = $HPModel.HPModel
            $HPModelProdCode = $HPModel.ProdCode
            $HPModelManufacturer = $HPModel.Manufacturer
            $DriverList = @()
            Write-asLog -Message "Checking $HPModelHPModel product code $HPModelProdCode for driver package" -LogLevel 1
            
            # Get Softpaq infos for each Windows 10 version
            foreach ($OSVersion in $OSVersions) {
                Try {
                    $Softpaq = Get-SoftpaqList -platform $HPModelProdCode -os $OS -osver $OSVersion -ErrorAction Stop
                    $DriverPack = $Softpaq | Where-Object {$_.Category -like "*Driver Pack*"}
                    $DriverPack = $DriverPack | Where-Object { $_.Name -notmatch "Windows PE" } | Where-Object { $_.Name -notmatch "Win PE" } | Where-Object { $_.Name -notmatch "WinPE" }
                    $DriverPack = $DriverPack | Select-Object -Index 0
                    Write-asLog -Message $DriverPack -LogLevel 1
                    break
                }
                Catch {
                    Write-asLog -Message "Could not retrieve driver pack information for Model $HPModelHPModel Win10 $OSVersion" -LogLevel 2
                    Write-asLog -Message "Will try older $OS version" -LogLevel 2                
                }            
            }

            If ($DriverPack) {
                $DriverPackVersion = $DriverPack.Version
                $DriverPackId = "$($DriverPack.Id)".ToUpper()
                $DriverPackReleaseDate = $DriverPack.ReleaseDate

                # Check package version of downlad
                Set-Location -Path "$($Global:SiteCode):"
                $PackageFullInformation = ""
                $PackageInfoVersion = ""                
                $PackageFullInformation = Get-CMPackage -Name "Drivers - $HPModelHPModel" -Fast
                
                #Set ExecuteDownload to true, changes if version is current
                $ExecuteDownload = $true
                
                Set-Location -Path "$($Global:CurrentLocation)"
                
				# This is necessary because of multiple BIOS packages
                If (!($PackageFullInformation -eq '')) {
                    foreach ($PackageInfo in $PackageFullInformation) {
                        $PackageInfoName = $PackageInfo.Name
                        $PackageInfoPackageID = $PackageInfo.PackageID                    
                        $PackageInfoVersion = $PackageInfo.Version

                        If ($PackageInfoVersion -eq $DriverPackVersion) {
                            Write-asLog -Message "ConfigMgr package $PackageInfoPackageID version for $HPModelHPModel is $PackageInfoVersion, up-to-date" -LogLevel 1
                            $ExecuteDownload = $false
                        } Else {                        
                            Write-asLog -Message "ConfigMgr package $PackageInfoPackageID version for $HPModelHPModel is $PackageInfoVersion, update $DriverPackVersion available" -LogLevel 1
                        }                   
                    }
                } Else {
                    Write-asLog -Message "ConfigMgr package for $HPModelHPModel not found. Will create one." -LogLevel 2
                }                
                
                If ($ExecuteDownload) {               
                    # Create Download folder per model
                    $HPModelDownloadFolder = Join-Path "$DownloadFolder" "$HPModelHPModel\$DriverPackVersion"
                    If (Test-Path -Path $HPModelDownloadFolder) {
                        Remove-Item -Path "$HPModelDownloadFolder" -Recurse -Force -ErrorAction SilentlyContinue
                    }                    
                    $null = New-Item -Path "$HPModelDownloadFolder" -ItemType Directory -Force
                    Write-asLog -Message "$HPModelDownloadFolder created" -LogLevel 1

                    # Create Temp folder per model
                    $TempFolder = Join-Path "$LocalRootFolder" "Temp"
                    If (Test-Path -Path $TempFolder) {
                        Remove-Item -Path $TempFolder -Recurse -Force -ErrorAction SilentlyContinue                        
                    }
                    $null = New-Item -Path $TempFolder -ItemType Directory -Force
                    Write-asLog -Message "$TempFolder created" -LogLevel 1

                    # Create extract folder per model
                    $ExtractFolderfull = Join-Path "$ExtractFolder" "$HPModelHPModel\$DriverPackVersion"
                    If (Test-Path -Path $ExtractFolderfull) {
                        Remove-Item -Path $ExtractFolderfull -Recurse -Force -ErrorAction SilentlyContinue                        
                    }
                    $null = New-Item -Path $ExtractFolderfull -ItemType Directory -Force
                    Write-asLog -Message "$ExtractFolderfull created" -LogLevel 1

                    # Create filenames
                    $SaveAs = Join-Path "$HPModelDownloadFolder" "$($DriverPackId).exe"
                    $SaveAsCVA = Join-Path "$HPModelDownloadFolder" "$($DriverPackId).cva"
                    
                    # Download Package
                    Get-Softpaq -number $DriverPackId -saveAs $SaveAs -overwrite yes
                    Write-asLog -Message "$DriverPackId.exe downloaded" -LogLevel 1
                   
                    # Download cva-File
                    Get-SoftpaqMetadataFile -number $DriverPackId -saveAs $SaveAsCVA -overwrite yes
                    Write-asLog -Message "$DriverPackId.cva downloaded" -LogLevel 1
                    
                    # Extract Package
                    Start-Process -FilePath $SaveAs -ArgumentList "-pdf -e -s -f$($TempFolder)" -Wait
                    Write-asLog -Message "$($DriverPack.Id).exe extracted to $($TempFolder)" -LogLevel 1                    
                    
                    # Copy Package local
                    $CopyFromDir = $TempFolder
                    While(((Get-ChildItem -Path $CopyFromDir -Directory).FullName).count -eq 1) {
                        $CopyFromDir = ((Get-ChildItem -Path $CopyFromDir -Directory).FullName)
                    }
                    $null = Copy-Item -Path "$CopyFromDir\*" -Destination "$ExtractFolderfull" -Container -Force -Recurse
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
                        $PackageSourceFull = "$($SMBShare.LocalPath)" 
                        $PackageSourceFull = Join-Path "$PackageSourceFull" "$($Global:Settings.FileServerHPDriversSubfolder)\$HPModelHPModel\$DriverPackVersion"

                        If (Test-Path -Path "$PackageSourceFull") {
                            Remove-Item -Path "$PackageSourceFull" -Recurse -Force -ErrorAction SilentlyContinue
                            Write-asLog -Message "Cleanup existing $PackageSourceFull" -LogLevel 2 
                        }

                        Start-Sleep -Seconds 5
                        
                        $null = Copy-Item -Path "$ExtractFolderfull" -Destination "$PackageSourceFull" -Container -Force -Recurse
                        Write-asLog -Message "Package files copied to $PackageSourceFull" -LogLevel 1
                        Write-asLog -Message "Will create ConfigMgr package now..." -LogLevel 1

                        #ConfigMgr package
                        Set-Location -Path "$($Global:SiteCode):"
                        $DPGroup = Get-CMDistributionPointGroup -Name $($Global:Settings.CMDistributionPointGroup)

                        #Package definition
                        $NewPackageManufacturer = $HPModelManufacturer
                        $NewPackageName = "Drivers - $HPModelHPModel"
                        $NewPackageDescription = "Model $HPModelProdCode, Version $DriverPackVersion, Release Date $DriverPackReleaseDate"
                        $NewPackageVersion = "$DriverPackVersion"
                        $NewPackageFolderPath = "$($Global:Settings.CMDriversPackageFolderPath)\$NewPackageManufacturer"
                           
                        #Create new Package source Path 
                        $NewPackageSourcePath = Join-Path $FileServerTargetRoot "$($Global:Settings.FileServerHPDriversSubfolder)\$HPModelHPModel\$DriverPackVersion"
                        
                        #Package creation
                        $NewPackage = New-CMPackage -Name $NewPackageName -Description $NewPackageDescription -Manufacturer $NewPackageManufacturer -Version $NewPackageVersion -Path $($NewPackageSourcePath)
                        $NewPackage | Set-CMPackage -EnableBinaryDeltaReplication $true
                        $NewPackage | Move-CMObject -FolderPath $NewPackageFolderPath
                        Write-asLog -Message "$($NewPackage.PackageID) - ConfigMgr package $NewPackageName version $NewPackageVersion created" -LogLevel 1
                        Write-asMail -Message "$($NewPackage.PackageID) - ConfigMgr package $NewPackageName version $NewPackageVersion created" -Color Green
                        Write-asTeamsMessage -MessageName "$($NewPackage.PackageID)" -MessageValue "ConfigMgr package $NewPackageName version $NewPackageVersion created"
                        
                        #Package distribution
                        Get-CMPackage -Id $($NewPackage.PackageID) -Fast | Start-CMContentDistribution -DistributionPointGroupName "$($DPGroup.Name)"
                        Write-asLog -Message "ConfigMgr package $NewPackageName distributed to $($DPGroup.Name) - $($DPGroup.MemberCount) Distribution Points" -LogLevel 1
                        Set-Location -Path "$($Global:CurrentLocation)"                        
                    }
                }
            }
        }
    }

    END {
        $SMBShare | Remove-SmbMapping -Force
        $EndTime = (Get-Date).ToString()
        $RunTime = [math]::Round($((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes), 1)
        
        # Finish mail message
        Write-asMail " "
        Write-asMail "Script finished" -Bold
        Write-asMail "Total $RunTime minutes"
        If ($SendMail) {
            Send-asMail -To $MailTo -Subject $MailSubject -Attachement $Global:ScriptLogFilePath
            Write-asLog -Message "Mail with subject $MailSubject sent to $MailTo" -LogLevel 1
        }

        # Finish Teams message
        Write-asTeamsMessage -MessageName "RunTime" -MessageValue "Total $RunTime minutes"
        If ($SendTeams) {
		Send-asTeamsMessage -MessageTitle "HP BIOS Updates" `
                -MessageText "Summary about the execution of $Global:Component" `
                -ActivityTitle "DriverFactory" `
                -ActivitySubtitle "$(Get-Date -UFormat "%d.%m.%Y, %R")" `
                -ActivityText "Script finished" `
                -ActivityImagePath "https://www8.hp.com/at/de/images/i/hpi/header-footer/caas-hf-v3.2/hpi-hp-logo-pr.gif" `
                -ButtonName "HP Support" `
                -ButtonUri "https://support.hp.com/at-de/drivers"
	}

        #Finish log file
        Write-asLog -Message "Script finished" -LogLevel 1
        Write-asLog -Message "Total $RunTime minutes" -LogLevel 1
    }
} 

#Execute Script
Get-asHPDriverPacks -SendMail -SendTeams
