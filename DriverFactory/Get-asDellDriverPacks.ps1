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

Function Get-asDellDriverPacks {
      [CmdletBinding()]
      param (
      	[switch]
	$Compress,
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
        
        # Import ModelsDellCSV
        $DellModels = Import-Csv -Delimiter ';' -Path $($Global:Settings.ModelsDellCSV)
        Write-asLog "Dell Models imported from $($Global:Settings.ModelsDellCSV)" -LogLevel 1

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
        # Get Dell drivers catalog
        # Create WebClient for downloads
        $WebClient = New-Object System.Net.WebClient

        # Set Dell variables 
        $DellDownloadsUrl = "http://downloads.dell.com/"
        $DellCatalogPcUrl = "http://downloads.dell.com/catalog/DriverPackCatalog.cab"
        $DellCatalogPcCab = Join-Path "$DownloadFolder" "$($DellCatalogPcUrl | Split-Path -Leaf)"
        $DellCatalogPcXml = Join-Path "$ExtractFolder" "DriverPackCatalog.xml"

        # Download CatalogPC.cab
        Try {
            Write-asLog -Message "Download $($DellCatalogPcUrl | Split-Path -Leaf) from $DellCatalogPcUrl to $DellCatalogPcCab" -LogLevel 1
            $WebClient.DownloadFile($DellCatalogPcUrl, $DellCatalogPcCab)
        }
        Catch {
            Write-asLog -Message "Download failed > exit script" -LogLevel 3
            exit
        }

        # Extract CatalogPC.cab to get xml
        Write-asLog -Message "Extract $DellCatalogPcCab to $ExtractFolder" -LogLevel 1
        Expand $DellCatalogPcCab -F:* $ExtractFolder -R | Out-Null
    
        # Get content of XML file
        Try {
            Write-asLog -Message "Reading $DellCatalogPcXml file" -LogLevel 1
            [xml]$XMLDellUpdateCatalog = Get-Content "$DellCatalogPcXml" -ErrorAction Stop
        }
        Catch {
            Write-asLog -Message "Could not read $DellCatalogPcXml file > exit script" -LogLevel 3
            exit
        }

        # Get content of catalog file
        Write-asLog -Message "Loading Dell update Catalog XML nodes" -LogLevel 1
        $DellUpdateList = $XMLDellUpdateCatalog.DriverPackManifest.DriverPackage

        # Filtering Dell Update Catalog XML for BIOS Downloads
        Write-asLog -Message "Filter Windows 10 x64 from Catalog XML" -LogLevel 1
        $DellUpdateList = $DellUpdateList | Where-Object {$_.SupportedOperatingSystems.OperatingSystem.Display.'#cdata-section'.Trim() -eq 'Windows 10 x64'}
        
    } #BEGIN

    PROCESS {
        foreach ($DellModel in $DellModels) {
            If ($DellUpdateList) {
                # Create Dell variables
                $DellModelBrand = $DellUpdateList | Where-Object { $_.SupportedSystems.Brand.Display.'#cdata-section'.Trim() -like "$($DellModel.Brand)" }
                $DellModelFullModelName = "$($DellModel.Manufacturer) $($DellModel.Brand) $($DellModel.Model)"
                $DellModelFullInformation = $DellModelBrand | Where-Object { $_.SupportedSystems.Brand.Model.Display.'#cdata-section'.Trim() -eq "$($DellModel.Model)" }
                $DellModelDownloadPath = $DellModelFullInformation.path
                $DellModelDownloadUrl = "$DellDownloadsUrl" + "$DellModelDownloadPath"
                $DellModelFileName = $DellModelDownloadPath | Split-Path -Leaf
                $DellModelVersion = $DellModelFullInformation.dellVersion
                #$DellModelReleaseDate = $DellModelFullInformation.releaseDate
                
                # Check package version of downlad
                Set-Location -Path "$($Global:SiteCode):"
                $PackageFullInformation =""
                $PackageInfoVersion = ""                
                $PackageFullInformation = Get-CMPackage -Name "Drivers - $DellModelFullModelName" -Fast
                
                # Set ExecuteDownload to true, changes if version is current
                $ExecuteDownload = $true
                
                Set-Location -Path "$($Global:CurrentLocation)"
				
				# This is necessary because of multiple BIOS packages
                If (!($PackageFullInformation -eq '')) {
                    foreach ($PackageInfo in $PackageFullInformation) {
                        # Create package variables
                        $PackageInfoName = $PackageInfo.Name
                        $PackageInfoPackageID = $PackageInfo.PackageID                    
                        $PackageInfoVersion = $PackageInfo.Version

                        If ($PackageInfoVersion -eq $DellModelVersion) {
                            Write-asLog -Message "ConfigMgr package $PackageInfoPackageID version for $DellModelFullModelName is $PackageInfoVersion, up-to-date" -LogLevel 1
                            $ExecuteDownload = $false
                        } Else {                        
                            Write-asLog -Message "ConfigMgr package $PackageInfoPackageID version for $DellModelFullModelName is $PackageInfoVersion, update $DellModelVersion available" -LogLevel 1
                        }                   
                    }
                } Else {
                    Write-asLog -Message "ConfigMgr package for $DellModelFullModelName not found. Will create one." -LogLevel 2
                }

                If ($ExecuteDownload) {
                    # Create download folder per model
                    $DellModelDownloadFolder = Join-Path "$DownloadFolder" "$DellModelFullModelName\$DellModelVersion"
                    If (Test-Path -Path (Split-Path $DellModelDownloadFolder)) {
                        Remove-Item -Path "$DellModelDownloadFolder" -Recurse -Force -ErrorAction SilentlyContinue
                    }                    
                    $null = New-Item -Path "$DellModelDownloadFolder" -ItemType Directory -Force
                    Write-asLog -Message "$DellModelDownloadFolder created" -LogLevel 1

                    # Create Temp folder per model
                    $TempFolder = Join-Path "$LocalRootFolder" "Temp"
                    If (Test-Path -Path $TempFolder) {
                        Remove-Item -Path $TempFolder -Recurse -Force -ErrorAction SilentlyContinue                        
                    }
                    $null = New-Item -Path $TempFolder -ItemType Directory -Force
                    Write-asLog -Message "$TempFolder created" -LogLevel 1

                    # Create extract folder per model
                    $ExtractFolderfull = Join-Path "$ExtractFolder" "$DellModelFullModelName\$DellModelVersion"
                    If (Test-Path -Path $ExtractFolderfull) {
                        Remove-Item -Path $ExtractFolderfull -Recurse -Force -ErrorAction SilentlyContinue                        
                    }
                    $null = New-Item -Path $ExtractFolderfull -ItemType Directory -Force
                    Write-asLog -Message "$ExtractFolderfull created" -LogLevel 1
        
                    # Download driver packs
                    Try {
                        Write-asLog -Message "Download $DellModelFileName from $DellModelDownloadUrl to $DellModelDownloadFolder" -LogLevel 1
                        $WebClient.DownloadFile($DellModelDownloadUrl, "$DellModelDownloadFolder\$DellModelFileName")
                        $DownloadToServer = $true
                    }
                    Catch {
                        Write-asLog -Message "Could not download $DellModelFileName from $DellModelDownloadUrl to $DellModelDownloadFolder > skip" -LogLevel 3
                        $DownloadToServer = $false
                    }
                    
                    # Extract Package
                    Expand "$DellModelDownloadFolder\$DellModelFileName" -F:* "$TempFolder" -R | Out-Null
                    Write-asLog -Message "$DellModelFileName extracted to $TempFolder" -LogLevel 1

                    # Copy Package local
                    $CopyFromDir = $TempFolder
                    While( ((Get-ChildItem -Path $CopyFromDir -Directory).FullName).count -eq 1 ) {
                        $CopyFromDir = ((Get-ChildItem -Path $CopyFromDir -Directory).FullName)
                    }
                    $null = Copy-Item -Path "$CopyFromDir\*" -Destination "$ExtractFolderfull" -Container -Force -Recurse
                    Write-asLog -Message "Driver package files copied to $ExtractFolderfull" -LogLevel 1
                        
                    # Compress drivers
                    If ($Compress) {
                        Compress-Archive -Path "$ExtractFolderFull\*" -DestinationPath "$ExtractFolder\$DellModelFullModelName\Drivers.zip" -CompressionLevel Optimal -Force
			Write-asLog -Message "Drivers compressed to zip-file" -LogLevel 1
                    }
                    
                    # Die Dateien auf den Fileserver kopieren
                    If ($DownloadToServer) {
                        $PackageSourceFull = "$($SMBShare.LocalPath)" 
                        $PackageSourceFull = Join-Path "$PackageSourceFull" "$($Global:Settings.FileServerDellDriversSubfolder)\$DellModelFullModelName\$DellModelVersion"

                        If (Test-Path -Path "$PackageSourceFull") {
                            Remove-Item -Path "$PackageSourceFull" -Recurse -Force -ErrorAction SilentlyContinue
                        }

                        Start-Sleep -Seconds 5
                        $null = New-Item -Path $PackageSourceFull -ItemType Directory -Force
                        
                        If ($Compress) {
                            $null = Copy-Item -Path "$ExtractFolder\$DellModelFullModelName\Drivers.zip" -Destination "$PackageSourceFull\Drivers.zip" -Force
                        } Else {
                            $null = Copy-Item -Path "$ExtractFolderfull" -Destination "$PackageSourceFull" -Container -Force -Recurse
                        }
                        
                        Write-asLog -Message "Package files copied to $PackageSourceFull" -LogLevel 1
                        Write-asLog -Message "Will create ConfigMgr package now..." -LogLevel 1

                        # ConfigMgr package
                        Set-Location -Path "$($Global:SiteCode):"
                        $DPGroup = Get-CMDistributionPointGroup -Name $($Global:Settings.CMDistributionPointGroup)

                        # Package definition
                        $NewPackageManufacturer = $($DellModel.Manufacturer)
                        $NewPackageName = "Drivers - $DellModelFullModelName"
                        $NewPackageDescription = "Model $($DellModel.ProdCode), Version $DellModelVersion"
                        $NewPackageVersion = "$DellModelVersion"
                        $NewPackageFolderPath = "$($Global:Settings.CMDriversPackageFolderPath)\$NewPackageManufacturer"
                           
                        # Create new Package source Path
                        $NewPackageSourcePath = Join-Path $FileServerTargetRoot "$($Global:Settings.FileServerDellDriversSubfolder)\$DellModelFullModelName\$DellModelVersion"

                        # Package creation
                        $NewPackage = New-CMPackage -Name $NewPackageName -Description $NewPackageDescription -Manufacturer $NewPackageManufacturer -Version $NewPackageVersion -Path $($NewPackageSourcePath)
                        $NewPackage | Set-CMPackage -EnableBinaryDeltaReplication $true
                        $NewPackage | Move-CMObject -FolderPath $NewPackageFolderPath
                        Write-asLog -Message "$($NewPackage.PackageID) - ConfigMgr package $NewPackageName version $NewPackageVersion created" -LogLevel 1
                        Write-asMail -Message "$($NewPackage.PackageID) - ConfigMgr package $NewPackageName version $NewPackageVersion created" -Color Green
                        Write-asTeamsMessage -MessageName "$($NewPackage.PackageID)" -MessageValue "ConfigMgr package $NewPackageName version $NewPackageVersion created"
                        
                        #Package distribution
                        Get-CMPackage -Id $($NewPackage.PackageID) -Fast | Start-CMContentDistribution -DistributionPointGroupName "$($DPGroup.Name)"
                        Write-asLog -Message "ConfigMgr package $NewPackageName distributed to $DPGroup" -LogLevel 1
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
	    Send-asTeamsMessage -MessageTitle "Dell Driver Package" `
                -MessageText "Summary about the execution of $Global:Component" `
                -ActivityTitle "DriverFactory" `
                -ActivitySubtitle "$(Get-Date -UFormat "%d.%m.%Y, %R")" `
                -ActivityText "Script finished" `
                -ActivityImagePath "https://upload.wikimedia.org/wikipedia/commons/thumb/4/48/Dell_Logo.svg/768px-Dell_Logo.svg.png" `
                -ButtonName "Dell Support" `
                -ButtonUri "https://www.dellemc.com/de-at/services/support-services/index.htm"
	}

        # Finish log file
        Write-asLog -Message "Script finished" -LogLevel 1
        Write-asLog -Message "Total $RunTime minutes" -LogLevel 1
    }
}
 
Get-asDellDriverPacks -Compress -SendMail -SendTeams
