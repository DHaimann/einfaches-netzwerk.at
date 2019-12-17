$HPModels = Import-Csv -Path "C:\Util\DriverFactory\Models\HPModels.csv" -Delimiter ';'
$SSM = "C:\Util\DriverFactory\Extrafiles\HPBios"

foreach ($HPModel in $HPModels) {
    $HPModelProdCode = $HPModel.ProdCode
    $HPModelName = $HPModel.HPModel

    $aSoftpaq = @()
    # Get SSM Drivers
    Try {
        $Softpaq = Get-SoftpaqList -bitness 64 -category driver -characteristic SSM -os win10 -platform $HPModelProdCode -ErrorAction Stop
        $aSoftpaq += $Softpaq | Where-Object { $_.DPB -eq "false" }

        # Get SSM Firmware
        $Softpaq = Get-SoftpaqList -bitness 64 -category firmware -characteristic SSM -os win10 -platform $HPModelProdCode -ErrorAction Stop
        $aSoftpaq += $Softpaq | Where-Object { $_.DPB -eq "false" }

        # Get SSM Software
        $Softpaq = Get-SoftpaqList -bitness 64 -category software -characteristic SSM -os win10 -platform $HPModelProdCode -ErrorAction Stop
        $aSoftpaq += $Softpaq | Where-Object { $_.DPB -eq "false" } | Where-Object { ($_.Name -like "*Hotkey*") -or ($_.Name -like "*Default Settings*") }

        foreach ($Item in $aSoftpaq) {
            $SoftpaqId = $Item.Id
            $DownloadFolder = New-Item -Path "C:\DriverFactory\SSM\$HPModelName" -ItemType Directory -Force -ErrorAction SilentlyContinue
            $SaveAs = "$DownloadFolder\$SoftpaqId.exe"
            $SaveAsCVA = "$DownloadFolder\$SoftpaqId.cva"

            #Download Package
            Get-Softpaq -number $SoftpaqId -saveAs $SaveAs -overwrite yes
                  
            #Download cva-File
            Get-SoftpaqMetadataFile -number $SoftpaqId -saveAs $SaveAsCVA -overwrite yes

            #Copy ssm.exe and ssm.cab to downloadfolder
            Copy-Item -Path "$SSM\*" -Destination $DownloadFolder -Force -Exclude "password.bin" -ErrorAction SilentlyContinue
        }
    }
    Catch {
        Write-Host "Softpaq-List for $HPModelName not found" -ForegroundColor Red
    }
}
