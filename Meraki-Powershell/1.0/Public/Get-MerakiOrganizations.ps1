function Get-MerakiOrganizations {
    <#
    .SYNOPSIS
        Retrieves all Organizations in your Dashboard

    .DESCRIPTION
        This function fetches Organization details for one or all organizations within your Meraki dashboard.

    .PARAMETER All
        If specified, fetches All Organizations details. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches Organization details from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiOrganizations

        Fetches Organization details for a single organization (prompts for selection).

    .EXAMPLE
        Get-MerakiOrganizations -All

        Fetches Organization details for all organizations.

    .EXAMPLE
        Get-MerakiOrganizations -Company "Contoso"

        Fetches Organization details for any company with Contoso in the organization's name

    .NOTES
        This function requires that you have ran Initialize-MerakiAPI and provided an API Key
        Ensure your API key has the necessary permissions to access organization and network data.
    #>

    param (
        [switch]$All,
        [String]$Company = $null
    )

    # Get all Organizations
    $OrganizationURI = "https://api.meraki.com/api/v1/organizations/"
    try {
        $Organizations = Invoke-RestMethod -Method Get -Uri $OrganizationURI -Headers $Header
        $Organizations = $Organizations | Sort-Object -Property Name
    } catch [System.Net.WebException] {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized) {
            $global:OrgErrorStatus = "ERROR: UNAUTHORIZED ACCESS. Please make sure you are using a valid API Key or have ran Initialize-MerakiAPIKey command"
        } else {
            $global:OrgErrorStatus = "ERROR: An error occurred while fetching organizations: $($_.Exception.Message)" 
        }
        return
    }

    if ($All) {
        # If -All, Display warning and prompt for confirmation
        $confirm = Read-Host -Prompt "WARNING: Fetching data for all organizations may take a while. Do you want to proceed? (y/n)"
        if ($confirm -ne "y") {
            $global:OrgErrorStatus = "Operation cancelled."
            return
        }
    } elseif ($Company) {
        # If -Company "Company Name" Get companies that match
        $Organizations = $Organizations | Where-Object {$_.Name -like ("" + $Company + "*")}
        if ($Organizations -eq $null) {
            # Exit if no companies found
            $global:OrgErrorStatus = "ERROR: No Companies found matching: $Company"
            return
            }
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
        
            # Retrieve the selected option
            $Organizations = $Organizations[[int]$choice - 1]
        }
        return $Organizations
}