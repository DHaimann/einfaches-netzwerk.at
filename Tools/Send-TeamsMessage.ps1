<#  
    Author: Dietmar Haimann
    
    Copy the first two functions to the top of your script.
    Copy and paste your URI from Microsoft Teams Connector over <YOUR URI>.
    Add an additional line to facts section with
        Write-asTeamsMessage -MessageName "<LEFT BOLD SIDE>" -MessageValue "<RIGHT SIDE>"
    as often as needed also within a foreach-loop.
    
    See here https://docs.microsoft.com/en-us/outlook/actionable-messages/message-card-reference
#>   
    
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
    
    $Url = "<YOUR URI>"
    
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
        Write-Host "Successfully sent to Microsoft Teams" -ForegroundColor Green
    }

    Catch {
        Write-Host "Couldn't send to Microsoft Teams" -ForegroundColor Red
    }
}

Function Test-TeamsMessage {    
    
    #Create new Microsoft Teams Message Facts Array
    New-asTeamsMessage

    #Write Microsoft Teams Message Facts
    #Repeat as often as needed
    Write-asTeamsMessage -MessageName "Operating System" -MessageValue "Windows 10 Enterprise 1909"
    
    #Send Microsoft Teams Message
    Send-asTeamsMessage -MessageTitle "HP BIOS Updates" `
        -MessageText " " `
        -ActivityTitle "DriverFactory" `
        -ActivitySubtitle "$(Get-Date -UFormat "%d.%m.%Y, %R")" `
        -ActivityText "Erfolgreich beendet" `
        -ActivityImagePath "https://www8.hp.com/at/de/images/i/hpi/header-footer/caas-hf-v3.2/hpi-hp-logo-pr.gif" `
        -ButtonName "HP Support" `
        -ButtonUri "https://support.hp.com/at-de/drivers"
}
