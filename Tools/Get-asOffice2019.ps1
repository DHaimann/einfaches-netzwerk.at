<#
.SYNOPSIS
    Script zum Aktualisieren der Office 2019-Instrallationsdateien
.DESCRIPTION
    - Lädt die aktuellste Version vom Office Deployment Tool nach C:\Temp herunter
    - Entpackt das ODT nach C:\Util\Office Deployment Toolkit
    - Lädt mittels configuration_Office2019-x64-Download.xml die aktuellsten Office-Dateien herunter
    - Kopiert die Dateien auf die Server-Freigabe
    - Aktualisiert die ConfigMgr-Application inkl. Installationserkennung
    - Aktualisiert die Distribution Points
    - Schreibt ein Transkipt nach C:\Temp\Get-asOffice2019.log    
.EXAMPLE
.NOTES
    DateiName:  Get-asOffice2019.ps1
    Autor:      Dietmar Haimann
#>

Start-Transcript -Path "C:\Temp\Get-asOffice2019.log" -Force

# Variablen definieren
$ODTPath = "C:\Util\Office Deployment Toolkit"
$ODTSetup = "setup.exe"
$ODTSetupConfigXML = "configuration_Office2019-x64-Download.xml"
$ODTSetupArgs = @(
    "/download $ODTSetupConfigXML"
)
$SourceFolder = "Microsoft Office Professional Plus 2019 64-bit"

# Schreibe Variablen in Log-Datei
Write-Output "Office Deployment Toolkit: $ODTPath"
Write-Output "Office Setup Executeable: $ODTSetup"
Write-Output "Configuration file: $ODTSetupConfigXML"
Write-Output "Setup Arguments: $ODTSetupArgs"
Write-Output "Source files folder: $SourceFolder"

# Aktuelles ODT herunterladen
$ODTWebSource = 'https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117'
$ODTWebDestination = 'C:\Temp\officedeploymenttool.exe'

Try {
    $Response = Invoke-WebRequest -UseBasicParsing -Uri $ODTWebSource -ErrorAction Stop
    $ODTUri = $Response.links | Where-Object {$_.outerHTML -like "*click here to download manually*"}
    $ODTURL = $ODTUri.href
    Write-Output $ODTURL
    Invoke-WebRequest -UseBasicParsing -Uri $ODTURL -OutFile $ODTWebDestination -Verbose
    Start-Process -FilePath $ODTWebDestination -ArgumentList "/quiet /extract:""$ODTPath""" -Wait
    Remove-Item -Path $ODTWebDestination -Force -Verbose
}

Catch {
    Write-Output "Die aktuellste Version von ODT konnte nicht heruntergeladen werden"
    Wrire-Output "Die bestehende Version wird verwendet"
}

# Alte Dateien löschen
If (Test-Path -Path "$ODTPath\Office") {
    Write-Output "Cleanup old Office Files"
    Remove-Item -Path "$ODTPath\Office" -Recurse -Force -Verbose
}

# Download von Office 2019 starten
Write-Output "Start Office download: $ODTSetup $ODTSetupArgs"
Set-Location -Path $ODTPath -Verbose

Try {
    $Download = Start-Process -FilePath $ODTSetup -ArgumentList $ODTSetupArgs -PassThru -Wait -ErrorAction Stop -Verbose
    $Download.WaitForExit()
}
Catch {
    Write-Output "Cannot download Office... Exit"
    Stop-Transcript
    Exit 1
}

# Neue Version ermitteln
$NewVersion = (Get-ChildItem -Path "$ODTPath\Office\Data" -Exclude "*.cab").Name
Write-Output "New Office Version: $NewVersion"

$FullServerPath = "filesystem::\\SERVER\Share$\$SourceFolder"
Write-Output $FullServerPath

# Quelldateien und Setup.exe kopieren
If (Test-Path -Path "$FullServerPath\Office") {
    Remove-Item -Path "$FullServerPath\Office" -Recurse -Force -Verbose
}

Copy-Item -Path "$ODTPath\Office" -Destination $FullServerPath -Container -Recurse -Force -Verbose
Copy-Item -Path "$ODTPath\setup.exe" -Destination $FullServerPath -Force -Verbose

# ConfigMgr Application aktualisieren
Set-Location -Path "SITECODE:" -Verbose
$OfficeApp = Get-CMApplication -Name "Office Professional Plus 2019 64-bit" -Verbose

# DeploymentType-XML in Variable speichern
[XML]$SDMPackageXML = $OfficeApp.SDMPackageXML

# Namen des DeploymentTypes in Variable speichern
$DeploymentTypeName = $SDMPackageXML.AppMgmtDigest.DeploymentType.Title.'#text'

# DeploymentType Arguments-Array in Variable speichern
$Arguments = $SDMPackageXML.AppMgmtDigest.DeploymentType.Installer.DetectAction.Args.Arg

# Logical Name der Detection-Method-Clause im Array-Element MethodBody ermitteln
foreach ($Argument in $Arguments) {
    If ($Argument.Name -eq 'MethodBody') {
         [XML]$DetectAction = $Argument.'#text'
         $DetectionRuleLogicalName = $DetectAction.EnhancedDetectionMethod.Settings.SimpleSetting.LogicalName
         Write-Output $DetectionRuleLogicalName
    }
}

# Neue Detection Rule erstellen
# Clause für Detection Rule erstellen
$Clause = @{
    Hive = "LocalMachine"
    KeyName = "SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
    Is64Bit = $true
    PropertyType = "Version"
    ValueName = "ClientVersionToReport"
    Value = $true
    ExpectedValue = $NewVersion
    ExpressionOperator = "GreaterEquals"
}

Write-Output $Clause 
$NewClause = New-CMDetectionClauseRegistryKeyValue @Clause -Verbose

# Neue DeploymentType Parameter erstellen
$DeploymentType = @{
    Application = $OfficeApp
    DeploymentTypeName = "Office 365 Default Deployment Type"
    AddDetectionClause = $NewClause
    RemoveDetectionClause = $DetectionRuleLogicalName
}

Write-Output $DeploymentType

# Application aktualisieren
Set-CMApplication -InputObject $OfficeApp -SoftwareVersion $NewVersion -ReleaseDate $(Get-Date)
Set-CMScriptDeploymentType @DeploymentType -Verbose

# Distribution Point aktualisieren
Update-CMDistributionPoint -ApplicationName "Office Professional Plus 2019 64-bit" -DeploymentTypeName $DeploymentTypeName -Confirm:$false

Stop-Transcript
