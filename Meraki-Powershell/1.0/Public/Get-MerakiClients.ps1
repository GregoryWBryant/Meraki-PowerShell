function Get-MerakiClients {
    <#
    .SYNOPSIS
        Retrieves client information from Meraki networks.

    .DESCRIPTION
        This function fetches client details from one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once.
        The results can be displayed in the console or saved as a CSV file.

    .PARAMETER ShowOutput
        If specified, displays the client information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the client information to a CSV file, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches clients from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches Clients from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiClients

        Fetches client data for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakiClients -All

        Fetches client data for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakiClients -ShowOutput

        Fetches client data for a single organization (prompts for selection) and displays it in the console using Out-GridView.

    .EXAMPLE
        Get-MerakiClients -Company "Contoso"

        Fetches Clients data for any company with Contoso in the organization's name

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
    $AllClients = @()
    $InfoType = "Clients"

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
            $ClientsURI = ($NetworksURI + "/" + $Network.id + "/clients?perPage=5000")
            try {
                $Clients = Invoke-RestMethod -Method Get -Uri $ClientsURI -Headers $Header -ErrorAction SilentlyContinue
            } catch {
                $Clients = $null
            }

            foreach ($Client in $Clients){
                $NewDevice = [PSCustomObject]@{
                    OrganizationName = $Organization.name
                    networkName = $Network.name
                    mac = $Client.mac
                    firstSeen = $Client.firstSeen
                    lastSeen = $Client.lastSeen
                    deviceTypePrediction = $Client.deviceTypePrediction
                    recentDeviceName = $Client.recentDeviceName
                    recentDeviceConnection = $Client.recentDeviceConnection
                    ssid = $Client.ssid
                    status = $Client.status
                    description = $Client.description
                }
                $AllClients += $NewDevice
            }
        } 
    }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllClients | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllClients | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}