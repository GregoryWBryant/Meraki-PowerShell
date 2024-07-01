function Get-MerakiAdmins {
    <#
    .SYNOPSIS
        Retrieves Meraki organization administrator information.

    .DESCRIPTION
        This function fetches details about administrators for one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once. 
        The results can be displayed in the console or saved as a CSV file.

    .PARAMETER ShowOutput
        If specified, displays the administrator information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the administrator information to a CSV file.

    .PARAMETER All
        If specified, fetches administrators from all organizations. Otherwise, prompts for selection.

    .EXAMPLE
        Get-MerakiOrganizationAdmins -All

        Fetches administrator data for all organizations and saves it to "C:\Temp\AllOrgClients-Admins.csv".

    .EXAMPLE
        Get-MerakiOrganizationAdmins

        Fetches administrator data for a single organization (prompts for selection) and saves it to "C:\Temp\<Organization Name>-Admins.csv".

    .EXAMPLE
        Get-MerakiOrganizationAdmins -ShowOutput

        Fetches administrator data for a single organization (prompts for selection) and displays it in the console using Out-GridView.

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
    $AllAdmins = @()

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
        Write-Host ("Collecting Admins from: " + $Organization.Name)
        $AdminsURI = ($OrganizationURI + $Organization.id + "/admins")
        $Admins = Invoke-RestMethod -Method Get -Uri $AdminsURI -Headers $Header
        foreach ($Admin in $Admins){
        
            $AdminInformation = [PSCustomObject]@{
                Organization = $Organization.name
                id = $Admin.id
                name = $Admin.name
                email = $Admin.email
                authenticationMethod = $Admin.authenticationMethod
                orgAccess = $Admin.orgAccess
                accountStatus = $Admin.accountStatus
                twoFactorAuthEnabled = $Admin.twoFactorAuthEnabled
                hasApiKey = $Admin.hasApiKey
                lastActive = $Admin.lastActive
                networks = ($Admin.networks -split " ") -join ","
                tags = ($Admin.tags -split " ") -join ","
            }
            $AllAdmins += $AdminInformation 
        }
    }

    if ($ShowOutPut) {
        $AllAdmins | Out-GridView
    }

    if ((!$NoSave)){
        Write-Host ("Saving vLan informtion to: " + ($SaveLocation + "-Admins.csv"))
        $AllAdmins | Export-Csv -Path ($SaveLocation + "-Admins.csv") -NoTypeInformation
    }
}