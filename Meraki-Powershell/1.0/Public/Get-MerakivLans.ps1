function Get-MerakiVLans {
    <#
    .SYNOPSIS
        Retrieves vLan information from Meraki networks.

    .DESCRIPTION
        This function fetches vLan details for one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once.
        The results can be displayed in the console or saved as a CSV file.

    .PARAMETER ShowOutput
        If specified, displays the vLan information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the vLan information to a CSV file, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches vLans from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches vLan from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiVLans 

        Fetches vLan data for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakiVLans -All

        Fetches vLan data for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakiVLans -ShowOutput

        Fetches vLan data for a single organization (prompts for selection) and displays it in the console.

    .EXAMPLE
        Get-MerakiVLans -Company "Contoso"

        Fetches vLan data for any company with Contoso in the organization's name

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
    $AllvLans = @()
    $InfoType = "vLans"

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
            $Devcie = ""
            $DeviceUrl = "https://api.meraki.com/api/v1/networks/" + $Network.id +"/devices"
            $Devices = Invoke-RestMethod -Method Get -Uri $DeviceUrl -Headers $Header -ErrorAction SilentlyContinue
            $Device = $Devices | Where-Object {$_.model -like "MX*"}
            if ($Network.productTypes -eq "appliance") {
                $vLansURI = "https://api.meraki.com/api/v1/networks/" + $Network.id +"/appliance/vlans"

                try {
                    $vLans = Invoke-RestMethod -Method Get -Uri $vLansURI -Headers $Header -ErrorAction SilentlyContinue
                    foreach ($vLan in $vLans) {
                        $vLanInformation = [PSCustomObject]@{
                            Organization = $Organization.Name
                            Network = $Network.Name
                            Device = ($Device.Name -split " ") -join ","
                            Model = ($Device.model -split " ") -join ","
                            WanIP1 = ($Device.wan1Ip -split " ") -join ","
                            WanIP2 = ($Device.wan2Ip -split " ") -join ","
                            vLanID = $vLan.id
                            vLanName = $vLan.Name
                            Subnet = $vLan.subnet
                        }
                        $AllvLans += $vLanInformation
                    }
                } catch {
                    Write-Host ($Organization.Name + ": " + $Network.Name + ": Has no $InfoType" )
                }
            }
        }
    }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllvLans | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType informtion to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllvLans | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}