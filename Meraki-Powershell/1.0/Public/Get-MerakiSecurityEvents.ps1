function Get-MerakiSecurityEvents {
    <#
    .SYNOPSIS
        Retrieves Meraki security event information.

    .DESCRIPTION
        This function fetches security event details for one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once.
        The results can be displayed in the console or saved as a CSV file.

    .PARAMETER ShowOutput
        If specified, displays the security event information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the security event information to a CSV file, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches security events from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches Security Events from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiSecurityEvents -All

        Fetches security event data for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakiSecurityEvents

        Fetches security event data for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakiSecurityEvents -ShowOutput

        Fetches security event data for a single organization (prompts for selection) and displays it in the console.

    .EXAMPLE
        Get-MerakiSecurityEvents -Company "Contoso"

        Fetches Security Events for any company with Contoso in the organization's name

    .NOTES
        This function requires that you have ran Initialize-MerakiAPI and provided an API Key
        Ensure your API key has the necessary permissions to access organization and network data.
    #>

    param (
        [switch]$ShowOutPut,
        [switch]$NoSave,
        [switch]$All,
        [String]$Company = $null
    )


    # Setup Variables
    $AllSecurirtEvents = @()
    $InfoType = "Security Events"

    if ($All) {
        $Organizations = Get-MerakiOrganizations -All
        $SaveLocation = ($SaveFolderPath + "\AllOrgs")
    } elseif ($Company) {
        # If -Company "Company Name" Get companies that match
        $Organizations = Get-MerakiOrganizations -Company $Company
        if ($Organizations -eq $null) {
            # Exit if no companies found
            Write-Host "No Companies found matching: $Company"
            Write-Host "Exiting"
            return
        }
        $SaveLocation = ($SaveFolderPath + "\" + $Company)
        } else {
            $Organizations = Get-MerakiOrganizations
            $SaveLocation = ($SaveFolderPath + "\" + $Organizations.Name)
        }

    if ($global:OrgErrorStatus -ne "Good") {
        Write-Host $global:OrgErrorStatus
        return
        }

    foreach ($Organization in $Organizations) {
        Write-Host ("Collecting $InfoType from: " + $Organization.Name)
        $SecurityEventsURI = ($OrganizationURI + $Organization.id + "/appliance/security/events?perPage=1000")
        $SecurityEvents = Invoke-RestMethod -Uri $SecurityEventsURI -Headers $Header

        foreach ($SecurityEvent in $SecurityEvents){
            $SecurityEventInformation = [PSCustomObject]@{
                Organization = $Organization.name
                ts = $SecurityEvent.ts
                eventType = $SecurityEvent.eventType
                deviceMac = $SecurityEvent.deviceMac
                clientMac = $SecurityEvent.clientMac
                srcIp = $SecurityEvent.srcIp
                destIp = $SecurityEvent.destIp
                protocol = $SecurityEvent.protocol
                priority = $SecurityEvent.priority
                classification = $SecurityEvent.classification
                blocked = $SecurityEvent.blocked
                message = $SecurityEvent.message
                signature = $SecurityEvent.signature
                sigSource = $SecurityEvent.sigSource
                ruleId = $SecurityEvent.ruleId
            }
            $AllSecurirtEvents += $SecurityEventInformation
        }
    }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllSecurirtEvents | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType informtion to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllSecurirtEvents | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}