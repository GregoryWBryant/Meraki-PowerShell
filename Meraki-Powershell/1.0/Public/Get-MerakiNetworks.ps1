function Get-MerakiNetworks {
    <#
    .SYNOPSIS
        Retrieves VLAN and Static Route information from Meraki networks.

    .DESCRIPTION
        This function fetches VLAN and static route details for one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once.
        The results can be displayed in the console or saved as CSV files.

    .PARAMETER ShowOutput
        If specified, displays the information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the information to CSV files, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches Networks from all organizations and saves it to csv.

    .PARAMETER Company
        If specified, fetches Networks from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiNetworks

        Fetches Network information for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakiNetworks -All

        Fetches Network information for all organizations

    .EXAMPLE
        Get-MerakivNetworks -ShowOutput

        Fetches Network information for a single organization (prompts for selection) and displays it in the console.

    .EXAMPLE
        Get-MerakiNetworks -Company "Contoso"

        Fetches Network informatino for any company with Contoso in the organization's name

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
    $AllNetworks = @()
    $InfoType = "Networks"

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
        $NetworksURI = ($OrganizationURI + $Organization.id + "/networks")

        try {
            $Networks = Invoke-RestMethod -Method Get -Uri $NetworksURI -Headers $Header -ErrorAction SilentlyContinue
        } catch {
            $Networks = $null
        }
        
        foreach ($Network in $Networks) {
            $NetworkInformation = [PSCustomObject]@{
                Organization = $Organization.Name
                id = $Network.id
                organizationId = $Network.organizationId
                name = $Network.name
                productTypes = ($Network.productTypes -split " ") -join ","
                timeZone = $Network.timeZone
                tags = ($Network.tags -split " ") -join ","
                enrollmentString = $Network.enrollmentString
                url = $Network.url
                notes = $Network.notes
                isBoundToConfigTemplate = $Network.isBoundToConfigTemplate
            }
         $AllNetworks += $NetworkInformation
        }


        }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllNetworks | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType informtion to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllNetworks | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}