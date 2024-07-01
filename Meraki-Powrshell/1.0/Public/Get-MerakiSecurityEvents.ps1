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
        If specified, does not save the security event information to a CSV file.

    .PARAMETER All
        If specified, fetches security events from all organizations. Otherwise, prompts for selection.

    .EXAMPLE
        Get-MerakiSecurityEvents -All

        Fetches security event data for all organizations and saves it to "C:\Temp\AllOrgs-SecurityEvents.csv".

    .EXAMPLE
        Get-MerakiSecurityEvents

        Fetches security event data for a single organization (prompts for selection) and saves it to "C:\Temp\<Organization Name>-SecurityEvents.csv".

    .EXAMPLE
        Get-MerakiSecurityEvents -ShowOutput

        Fetches security event data for a single organization (prompts for selection) and displays it in the console.

    .NOTES
        This function requires that you have ran Initialize-MerakiAPI and provided an API Key
        Ensure your API key has the necessary permissions to access organization and network data.
    #>

    param (
        [switch]$ShowOutPut,
        [switch]$NoSave,
        [switch]$All
    )


    # Setup Variables
    $AllSecurirtEvents = @()

    # Get all Organizations
    $OrganizationURI = "https://api.meraki.com/api/v1/organizations/"
    try {
        $Organizations = Invoke-RestMethod -Method Get -Uri $OrganizationURI -Headers $Header
    } catch [System.Net.WebException] {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized) {
            Write-Host "ERROR: UNAUTHORIZED ACCESS. Please make sure you are using a valid API Key or have ran Initialize-MerakiAPIKey command"
        } else {
            Write-Host "ERROR: An error occurred while fetching organizations: $($_.Exception.Message)"
        }
        return
    }

    if ($All) {
        # Display warning and prompt for confirmation
        $confirm = Read-Host -Prompt "WARNING: Fetching data for all organizations may take a while. Do you want to proceed? (y/n)"
        if ($confirm -ne "y") {
            Write-Host "Operation cancelled."
            Return
        }
        $SaveLocation = ($SaveFolderPath + "\AllOrgs")
    } else {
        # Display clients in a numbered list
        Write-Host "Choose an option:"
        for ($i = 0; $i -lt $Organizations.Count; $i++) {
            Write-Host "$($i + 1). $($Organizations[$i].Name)"
        }

        # Get user's choice
        do {
            $choice = Read-Host "Enter the number of your choice (1-$($Organizations.Count))"
            $isValidChoice = $choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $Organizations.Count
            if (-not $isValidChoice) {
                Write-Host "Invalid input. Please enter a number between 1 and $($Organizations.Count)."
            }
        } while (-not $isValidChoice)

        # Retrieve and display the selected option
        $Organizations = $Organizations[[int]$choice - 1]
        $SaveLocation = ($SaveFolderPath + "\" + $Organizations.Name)
    } 

    foreach ($Organization in $Organizations) {
        Write-Host ("Gathering Security Events from: " + $Organization.Name)
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

    if ($ShowOutPut) {
        $AllSecurirtEvents | Out-GridView
    }

    if ((!$NoSave)){
        Write-Host ("Saving Network informtion to: " + ($SaveLocation + "-SecurityEvents.csv"))
        $AllSecurirtEvents | Export-Csv -Path ($SaveLocation + "-SecurityEvents.csv") -NoTypeInformation
    }
}