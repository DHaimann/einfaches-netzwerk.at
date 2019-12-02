<#
  Author:
    Dietmar Haimann
  
  Description:
    This script installs the AlwaysOn VPN profile
    
  Thanks:
    Richard Hicks
    @richardhicks
    https://directaccess.richardhicks.com/always-on-vpn/
    
  More information:
    https://www.einfaches-netzwerk.at/always-on-vpn-ueberblick/
#>

$ProfileName = 'AlwaysOn VPN User'
$ProfileNameEscaped = $ProfileName -replace ' ', '%20'

$ProfileXML = '<VPNProfile>
    <AlwaysOn>true</AlwaysOn>
    <RememberCredentials>false</RememberCredentials>
    <DnsSuffix>YOUR DNS SUFFIX</DnsSuffix>
    <TrustedNetworkDetection>Intranet</TrustedNetworkDetection>
    <RegisterDNS>true</RegisterDNS>

    <DomainNameInformation>
        <DomainName>.YOUR-DOMAIN.TLD</DomainName>
        <DnsServers>YOUR,DNS,SERVERS</DnsServers>
    </DomainNameInformation>

    <Proxy>
        <AutoConfigUrl>http://PATH-TO-WPAD.TLD/wpad.dat</AutoConfigUrl>
    </Proxy>

    <NativeProfile>
        <Servers>PATH-TO-YOUR-VPN-SERVERS.TLD</Servers>
        <NativeProtocolType>Automatic</NativeProtocolType>
        <Authentication>
            <UserMethod>Eap</UserMethod>
            <Eap>
                <Configuration>
                    <EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig">YOUR EAP HOST CONFIG</EapHostConfig>
                </Configuration>
            </Eap>
        </Authentication>
        <RoutingPolicyType>ForceTunnel</RoutingPolicyType>

        <CryptographySuite>
            <AuthenticationTransformConstants>SHA256128</AuthenticationTransformConstants>
            <CipherTransformConstants>AES128</CipherTransformConstants>
            <EncryptionMethod>AES128</EncryptionMethod>
            <IntegrityCheckMethod>SHA256</IntegrityCheckMethod>
            <DHGroup>Group14</DHGroup>
            <PfsGroup>PFS2048</PfsGroup>
        </CryptographySuite>
    </NativeProfile>

    <Route>
        <Address>10.0.0.0</Address>
        <PrefixSize>8</PrefixSize>
    </Route>
    <Route>
        <Address>172.16.0.0</Address>
        <PrefixSize>12</PrefixSize>
    </Route>
    <Route>
        <Address>192.168.0.0</Address>
        <PrefixSize>16</PrefixSize>
    </Route>
</VPNProfile>'

$ProfileXML = $ProfileXML -replace '<', '&lt;'
$ProfileXML = $ProfileXML -replace '>', '&gt;'
$ProfileXML = $ProfileXML -replace '"', '&quot;'

$nodeCSPURI = './Vendor/MSFT/VPNv2'
$namespaceName = 'root\cimv2\mdm\dmmap'
$className = 'MDM_VPNv2_01'

try
{
$username = Get-WmiObject -Class Win32_ComputerSystem | Select-Object username
$objuser = New-Object System.Security.Principal.NTAccount($username.username)
$sid = $objuser.Translate([System.Security.Principal.SecurityIdentifier])
$SidValue = $sid.Value
$Message = "User SID is $SidValue."
Write-Host "$Message"
}
catch [Exception]
{
$Message = "Unable to get user SID. User may be logged on over Remote Desktop: $_"
Write-Host "$Message"
exit
}

$session = New-CimSession
$options = New-Object Microsoft.Management.Infrastructure.Options.CimOperationOptions
$options.SetCustomOption('PolicyPlatformContext_PrincipalContext_Type', 'PolicyPlatform_UserContext', $false)
$options.SetCustomOption('PolicyPlatformContext_PrincipalContext_Id', "$SidValue", $false)

    try
{
    $deleteInstances = $session.EnumerateInstances($namespaceName, $className, $options)
    foreach ($deleteInstance in $deleteInstances)
    {
        $InstanceId = $deleteInstance.InstanceID
        if ("$InstanceId" -eq "$ProfileNameEscaped")
        {
            $session.DeleteInstance($namespaceName, $deleteInstance, $options)
            $Message = "Removed $ProfileName profile $InstanceId"
            Write-Host "$Message"
        } else {
            $Message = "Ignoring existing VPN profile $InstanceId"
            Write-Host "$Message"
        }
    }
}
catch [Exception]
{
    $Message = "Unable to remove existing outdated instance(s) of $ProfileName profile: $_"
    Write-Host "$Message"
    exit
}

try
{
    $newInstance = New-Object Microsoft.Management.Infrastructure.CimInstance $className, $namespaceName
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ParentID", "$nodeCSPURI", 'String', 'Key')
    $newInstance.CimInstanceProperties.Add($property)
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("InstanceID", "$ProfileNameEscaped", 'String', 'Key')
    $newInstance.CimInstanceProperties.Add($property)
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ProfileXML", "$ProfileXML", 'String', 'Property')
    $newInstance.CimInstanceProperties.Add($property)
    $session.CreateInstance($namespaceName, $newInstance, $options)
    $Message = "Created $ProfileName profile."
    Write-Host "$Message"
}
catch [Exception]
{
    $Message = "Unable to create $ProfileName profile: $_"
    Write-Host "$Message"
    exit
}

#######################################
# Workaround for missing VPN settings
#######################################

$Benutzer = ($objuser.value).ToString()
$Benutzer = ($Benutzer.Split("\"))[1]

(Get-Content -Path "C:\Users\$Benutzer\AppData\Roaming\Microsoft\Network\Connections\Pbk\rasphone.pbk") | `
ForEach-Object {$_ -replace 'VPNStrategy=.*', 'VPNStrategy=14'} | `
ForEach-Object {$_ -replace 'NumCustomPolicy=.*', "NumCustomPolicy=1 `r`nCustomIPSecPolicies=020000000200000003000000030000000200000003000000"} | `
Set-Content -Path "C:\Users\$Benutzer\AppData\Roaming\Microsoft\Network\Connections\Pbk\rasphone.pbk" -Force

Restart-Service RasMan -Force

#######################################
# Workaround for missing VPN settings
#######################################

exit 0
