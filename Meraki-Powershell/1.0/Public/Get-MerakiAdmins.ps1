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
        If specified, does not save the administrator information to a CSV file, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches administrators from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches administrators from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiAdmins -All

        Fetches administrator data for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakiAdmins

        Fetches administrator data for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakiAdmins -ShowOutput

        Fetches administrator data for a single organization (prompts for selection) and displays it in the console using Out-GridView.

    .EXAMPLE
        Get-MerakiAdmins -Company "Contoso"

        Fetches Admin data for any company with Contoso in the organization's name

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
    $AllAdmins = @()
    $InfoType = "Admins"

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

    if (($ShowOutPut) -or ($NoSave)) {
        $AllAdmins | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType informtion to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllAdmins | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}