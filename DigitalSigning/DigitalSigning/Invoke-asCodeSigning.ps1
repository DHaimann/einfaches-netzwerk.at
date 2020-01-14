[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $Path
)

$Path.ToString()

$CodeSigningCert = "\\fileserver\share$\CodeSigning\Certificate.pfx"
$pass = "password"

If (!(Test-Path -Path $CodeSigningCert)) {
    Write-Host "Couldn't successfully reach the code signing certificate in $CodeSigningCert" -ForegroundColor Red
    Break
} Else {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CodeSigningCert,$pass)
    $Expire = (New-TimeSpan -Start (Get-Date) -End $($cert.NotAfter)).Days
    Write-Warning "Code signing certificate expires in $Expire days"
}

#Comodo Time
$TimeStampServer = 'http://timestamp.comodoca.com/RFC3161'

Try {
    Set-AuthenticodeSignature -FilePath $Path -Certificate $cert -IncludeChain all -TimestampServer $TimeStampServer -Force
    Start-Sleep -Seconds 5
    Stop-Process -Id $PID
}

Catch {
    Write-Warning "Something went wrong"
}
