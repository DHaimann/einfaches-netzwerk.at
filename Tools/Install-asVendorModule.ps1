Function Install-asVendorModule {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName
    )

    BEGIN {
        $null = netsh winhttp set proxy proxy-server="proxy.domain.com:8080" bypass-list="<local>"
    }
    PROCESS {
    
        $NuGetLocal = Get-PackageProvider -ListAvailable | Where-Object -Property Name -EQ NuGet

        If ($null -eq $NuGetLocal) {
            Install-PackageProvider -Name 'NuGet' -MinimumVersion 2.8.5.201 -Force -Scope AllUsers
            Install-Module -Name 'PowerShellGet' -Force -Scope AllUsers -AllowClobber -SkipPublisherCheck
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        }

        $ModuleOnline = Find-Module -Name $ModuleName -Repository 'PSGallery'
        [Version]$ModuleOnlineVersion = $ModuleOnline.Version

        Try {
            $ModuleLocal = Get-InstalledModule -Name $ModuleName -ErrorAction Stop
            [Version]$ModuleLocalVersion = $ModuleLocal.Version

            If ($ModuleLocalVersion -ne $ModuleOnlineVersion) {
                Update-Module -Name $ModuleName -Force
            }
        }
        Catch {
            Install-Module -Name $ModuleName -Repository 'PSGallery' -Force -Scope AllUsers -SkipPublisherCheck -AcceptLicense
        }
    }
    END {
        $null = netsh winhttp reset proxy
    }    
}

$Vendor = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer

If ($Vendor -like "H*P*") {
    $ModuleName = "HPCMSL"
} ElseIf ($Vendor -like "Dell*") {
    $ModuleName = "DellBIOSProvider"
}

Install-asVendorModule -ModuleName $ModuleName
