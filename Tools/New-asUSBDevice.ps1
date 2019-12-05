<#
  Author:
    Dietmar Haimann
  
  Purpose:
    Mounts Windows-ISO file
    Asks for USB device within window
    Formats USB device with Fat32 and makes it bootable
    If the install.wim file is greater than 4GB it splits it into 1GB install.swm files
    Copies all files to USB device
    Unmonts ISO file
    Writes log file to C:\Temp
  
  Thanks:
  		Adam Bertram
			@adbertram
			https://adamtheautomator.com/send-mailmessage/
			https://adamtheautomator.com/building-logs-for-cmtrace-powershell/
      
      David Segura
      @SeguraOSD
      https://www.osdeploy.com/
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

Function Test-asIsAdmin {
    $Global:Component = $MyInvocation.MyCommand.Name
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Uups, you do not have admin rights to run this script.`nPlease re-run this script as an Administrator!" -ForegroundColor Red
        Write-asLog -Message "Uups, you do not have admin rights to run this script.Please re-run this script as an Administrator!" -LogLevel 3
        Break
    } Else {
        Write-asLog -Message "Script runs with admin rights" -LogLevel 1
    }
}

Function New-asUSBDevice {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -Include *.iso})]
        [string]
        $ISOPath,

        [ValidateLength(1,15)]
        [string]
        $USBLabel = "WindowsImage"
    )

    BEGIN {
        # Logging
        $Global:Component = $MyInvocation.MyCommand.Name
        $StartTime = (Get-Date).ToString()
        Start-asLog -FilePath ("C:\Temp\New-asUSBDevice.log")
    }

    PROCESS {
        Write-Warning "USB will be formatted FAT32"
        Write-asLog -Message "USB will be formatted FAT32" -LogLevel 2
        Write-Warning "Install.wim larger than 4GB will be splitted into install.swm"
        Write-asLog -Message "Install.wim larger than 4GB will be splitted into install.swm" -LogLevel 2

        $MountISO = Get-DiskImage -ImagePath $ISOPath
    
        If (!($MountISO.Attached -eq $true)) {
            Try {
                $MountISO = Mount-DiskImage -ImagePath $ISOPath -Verbose
                Write-asLog -Message "Successfully mounted Windows image" -LogLevel 1
            }
            Catch {
                Write-Host "ISO could not be mounted" -ForegroundColor Red
                Write-asLog -Message "Windows image could not be mounted" -LogLevel 3
                Break
            }
        }

        $USBDrive = Get-Disk | Where-Object {$_.BusType -eq 'USB' -and $_.Size -cge $MountISO.Size} | `
            Out-GridView -Title 'Select a USB Drive to FORMAT' -OutputMode Single | `
            Clear-Disk -RemoveData -RemoveOEM -Confirm:$false -PassThru | `
            New-Partition -UseMaximumSize -IsActive -AssignDriveLetter | `
            Format-Volume -FileSystem FAT32 -NewFileSystemLabel $USBLabel

        If ($null -eq $USBDrive) {
            Write-Host "No USB Drive was found or selected" -ForegroundColor Red
            Write-asLog -Message "No USB Drive was found or selected" -LogLevel 3
            Break            
        } else {
            bootsect.exe /nt60 "$($USBDrive.DriveLetter):"
        }

        $MountDrive = ($MountISO | Get-Volume).DriveLetter
        $MountDrive = $MountDrive + ":\"

        $WIMFile = Get-Item -Path $MountDrive\sources\install.wim
        $InstallLenght = 0

        If ($($WIMFile.Length)/1GB -gt 4) {
            Write-Host "WIM file is greater than 4GB. Try to split windows image." -ForegroundColor Yellow
            
            $ExportPath = "C:\Temp\Export"
            $SplitPath = Join-Path -Path $ExportPath "Split"
            
            If (Test-Path $ExportPath) { Remove-Item -Path $ExportPath -Recurse -Force }
            
            New-Item -Path $SplitPath -ItemType Directory -Force
            $CopyWIM = Copy-Item -Path $WIMFile -Destination $ExportPath -PassThru
            $CopyWIM.IsReadOnly = $false            

			#Split Windows Image
			Split-WindowsImage -ImagePath "$ExportPath\install.wim" -SplitImagePath "$SplitPath\install.swm" -FileSize 1024 -CheckIntegrity
			$InstallLenght = 1
		}
		
        #Copy Files from ISO to USB
        Try {
            If ($InstallLenght -eq 0) {
                Copy-Item -Path $MountDrive\* -Destination "$($USBDrive.DriveLetter):" -Container -Force -Recurse -Verbose
                Write-asLog -Message "Successfully copied files to $USBDrive.FriendlyName" -LogLevel 1            
            } ElseIf ($InstallLenght -eq 1) {
                Copy-Item -Path $MountDrive\* -Destination "$($USBDrive.DriveLetter):" -Container -Exclude install.wim -Force -Recurse -Verbose
                Copy-Item -Path $SplitPath\* -Destination "$($USBDrive.DriveLetter):\sources\" -Force -Verbose
                Write-asLog -Message "Successfully copied files to $USBDrive.FriendlyName" -LogLevel 1            
            }       
        }
        Catch {
            Write-asLog -Message "Files could not be copied to $($USBDrive.FriendlyName)" -LogLevel 3
            Break
        }

        # Unmount ISO
        $MountISO = Get-DiskImage -ImagePath $ISOPath -Verbose
        If ($MountISO.Attached -eq $true) {
            Try {
                Dismount-DiskImage -ImagePath $ISOPath -Verbose
                Write-Host "Successfully unmounted ISO" -ForegroundColor Green
                Write-asLog -Message "Successfully unmounted ISO" -LogLevel 1
            }
            Catch {
                Write-Host "ISO could not be unmounted successfully" -ForegroundColor Yellow
                Write-asLog -Message "ISO could not be unmounted successfully" -LogLevel 2
            }
        }
    }

    END {
        $Global:Component = $MyInvocation.MyCommand.Name
        $EndTime = (Get-Date).ToString()
        $RunTime = [math]::Round($((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes), 2)
        Write-asLog -Message "Script finished" -LogLevel 1
        Write-asLog -Message "Total script time $RunTime minutes" -LogLevel 1
    }
}
