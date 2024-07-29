function Get-MerakiDevices {
    <#
    .SYNOPSIS
        Retrieves Device information from Meraki networks.

    .DESCRIPTION
        This function gets Device details for one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once.
        The results can be displayed in the console or saved as CSV files.

    .PARAMETER ShowOutput
        If specified, displays the information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the information to CSV files, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches Device data from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches Devices from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakivDevices

        Fetches Device data for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakivDevices -All

        Fetches Device data for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakivDevices -ShowOutput

        Fetches Device data for a single organization (prompts for selection) and displays it in the console.

    .EXAMPLE
        Get-MerakiDevices -Company "Contoso"

        Fetches Device data for any company with Contoso in the organization's name

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
    $AllDevices = @()
    $InfoType = "Devices"

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

            $DevicesURI = ($NetworksURI + "/" + $Network.id + "/devices")
            try {
                $Devices = Invoke-RestMethod -Method Get -Uri $DevicesURI -Headers $Header -ErrorAction SilentlyContinue
            } catch {$Devices = $null} 
            foreach ($Device in $Devices){
                $NewDevice = [PSCustomObject]@{
                    OrganizationName = $Organization.name
                    lat = $Device.lat
                    lng = $Device.lng
                    address = $Device.address
                    serial = $Device.serial
                    mac = $Device.mac
                    lanIp = $Device.lanIp
                    url = $Device.url
                    networkId = $Device.networkId
                    networkName = $Network.name
                    tags = ($Device.tags -split " ") -join ","
                    name = $Device.name
                    details = ($Device.details -split " ") -join ","
                    model = $Device.model
                    switchProfileId  = $Device.switchProfileId
                    firmware = $Device.firmware
                    floorPlanId = $Device.floorPlanId
                }

                $AllDevices += $NewDevice
            }
        }
    }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllDevices | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType informtion to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllDevices | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}
