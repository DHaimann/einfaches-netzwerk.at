$Target = "$env:ProgramFiles\DigitalSigning"

If (Test-Path -Path $Target) {
    Remove-Item -Path $Target -Recurse -Force
}
New-Item -Path $Target -ItemType Directory -Force

Copy-Item -Path "$PSScriptRoot\DigitalSigning\*" -Destination $Target -Force
$null = Start-Process -FilePath "$env:windir\regedit.exe" -ArgumentList "/S `"$Target\DigitalSigning.reg`"" -NoNewWindow -PassThru
