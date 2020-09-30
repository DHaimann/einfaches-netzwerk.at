Function Install-asVendorModule {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName
    )

    BEGIN {
        $Proxy = "http://proxy.domain.local:8080"
        $Username = "user@domain.com"
        $Password = ConvertTo-SecureString 'P@ssw0rd1' -AsPlainText -Force
        $Credentials = New-Object System.Management.Automation.PSCredential ("$Username", $Password)

    }
    PROCESS {
        Try {
            $NuGetLocal = Get-PackageProvider -ListAvailable 'NuGet' -ErrorAction Stop
            [Version]$NuGetLocalVersion = $NuGetLocal.Version

            $NuGetOnline = Find-PackageProvider -Name 'NuGet' -Proxy $Proxy -ProxyCredential $Credentials
            [Version]$NuGetOnlineVersion = $NuGetOnline.Version

            If ($NuGetLocalVersion -ne $NuGetOnlineVersion) {
                Install-PackageProvider -Name 'NuGet' -MinimumVersion 2.8.5.201 -Scope AllUsers -Verbose -Proxy $Proxy -ProxyCredential $Credentials
                Update-Module -Name 'PowerShellGet' -Scope AllUsers -AcceptLicense -Verbose -Proxy $Proxy -ProxyCredential $Credentials
            }
        }

        Catch {
            Install-PackageProvider -Name 'NuGet' -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -Verbose -Proxy $Proxy -ProxyCredential $Credentials
            Install-Module -Name 'PowerShellGet' -Repository PSGallery -Force -Scope AllUsers -AllowClobber -SkipPublisherCheck -Verbose -Proxy $Proxy -ProxyCredential $Credentials
        }
        
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

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
            Install-Module -Name $ModuleName -Repository PSGallery -Force -Scope AllUsers -SkipPublisherCheck -AcceptLicense
        }
    }
    END {        
    }    
}

$Vendor = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer

If ($Vendor -like "H*P*") {
    $ModuleName = "HPCMSL"
} ElseIf ($Vendor -like "Dell*") {
    $ModuleName = "DellBIOSProvider"
}

Install-asVendorModule -ModuleName $ModuleName
