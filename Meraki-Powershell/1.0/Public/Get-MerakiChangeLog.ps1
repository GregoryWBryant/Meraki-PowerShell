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
        If specified, does not save the change log information to a CSV file, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches change logs from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches change logs from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiChangeLog -All

        Fetches change log data for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakiChangeLog 

        Fetches change log data for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakiChangeLog -ShowOutput

    .EXAMPLE
        Get-MerakiChangeLog -Company "Contoso"

        Fetches change log data for any company with Contoso in the organization's name

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
    $AllChanges = @()
    $InfoType = "Change Logs"

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

    if (($ShowOutPut) -or ($NoSave)) {
        $AllChanges | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType information to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllChanges | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}