function Get-MerakiChangeLog {
    <#
    .SYNOPSIS
        Retrieves Meraki organization configuration change logs.

    .DESCRIPTION
        This function fetches configuration change log details for one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once.
        The results can be displayed in the console or saved as a CSV file.

    .PARAMETER ShowOutput
        If specified, displays the change log information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the change log information to a CSV file.

    .PARAMETER All
        If specified, fetches change logs from all organizations. Otherwise, prompts for selection.

    .EXAMPLE
        Get-MerakiOrganizationChangeLog -All

        Fetches change log data for all organizations and saves it to "C:\Temp\AllOrgs-ChangeLog.csv".

    .EXAMPLE
        Get-MerakiOrganizationChangeLog 

        Fetches change log data for a single organization (prompts for selection) and saves it to "C:\Temp\<Organization Name>-ChangeLog.csv".

    .EXAMPLE
        Get-MerakiOrganizationChangeLog -ShowOutput

        Fetches change log data for a single organization (prompts for selection) and displays it in the console using Out-GridView.

    .NOTES
        This function requires the `Invoke-RestMethod` cmdlet.
        Ensure the `$Header` variable is set with your Meraki API key before using this function.
        Typically, you would use the `Initialize-MerakiAPI` function to set the header.
    #>

    param (
        [switch]$ShowOutPut,
        [switch]$NoSave,
        [switch]$All
    )

    # Setup Variables
    $AllChanges = @()

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
        Write-Host ("Collecting ChangeLogs from: " + $Organization.Name)
        $ChangeURI = ($OrganizationURI + $Organization.id + "/configurationChanges")
        $Changes = Invoke-RestMethod -Method Get -Uri $ChangeURI -Headers $Header
        foreach ($Change in $Changes){
            $ChangeInformation = [PSCustomObject]@{
                Organization = $Organization.name
                ts = $Change.ts
                adminName = $Change.adminName
                adminEmail = $Change.adminEmail
                adminId = $Change.adminID
                networkName = $Change.networkName
                networkId = $Change.networkID
                networkUrl = $Change.networkURL
                ssidName = $Change.ssidName
                ssidNumber = $Change.ssidNumber
                page = $Change.page
                label = $Change.label
                oldValue = $Change.oldValue
                newValue = $Change.newValue
            }

            $AllChanges += $ChangeInformation 
        }
    }

    if ($ShowOutPut) {
        $AllChanges | Out-GridView
    }

    if ((!$NoSave)){
        Write-Host ("Saving ChangeLog information to: " + ($SaveLocation + "-ChangeLog.csv"))
        $AllChanges | Export-Csv -Path ($SaveLocation + "-ChangeLog.csv") -NoTypeInformation
    }
}