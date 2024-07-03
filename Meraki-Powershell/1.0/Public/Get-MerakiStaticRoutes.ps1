function Get-MerakiStaticRoutes {
    <#
    .SYNOPSIS
        Retrieves static route information from Meraki networks.

    .DESCRIPTION
        This function fetches static route details for one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once.
        The results can be displayed in the console or saved as a CSV file.

    .PARAMETER ShowOutput
        If specified, displays the static route information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the static route information to a CSV file, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches static routes from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches static routes from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiStaticRoutes

        Fetches static route data for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakiStaticRoutes -All

        Fetches static route data for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakiStaticRoutes -ShowOutput

        Fetches static route data for a single organization (prompts for selection) and displays it in the console.

    .EXAMPLE
        Get-MerakiStaticRoutes -Company "Contoso"

        Fetches static route data for any company with Contoso in the organization's name

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
    $AllStaticRoutes = @()
    $InfoType = "Static Routes"

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

    foreach ($Organization in $Organizations) {
        Write-Host ("Collecting $InfoType from: " + $Organization.Name)
        $NetworksURI = ($OrganizationURI + $Organization.id + "/networks")

        try {
            $Networks = Invoke-RestMethod -Method Get -Uri $NetworksURI -Headers $Header -ErrorAction SilentlyContinue
        } catch {
            $Networks = $null
        }

    if ($global:OrgErrorStatus -ne "Good") {
        Write-Host $global:OrgErrorStatus
        return
        }

        foreach ($Network in $Networks) {
            if ($Network.productTypes -eq "appliance") {
                $Devcie = ""
                $DeviceUrl = "https://api.meraki.com/api/v1/networks/" + $Network.id +"/devices"
                $Devices = Invoke-RestMethod -Method Get -Uri $DeviceUrl -Headers $Header -ErrorAction SilentlyContinue
                $Device = $Devices | Where-Object {$_.model -like "MX*"}
                $StaticRoutesURI = "https://api.meraki.com/api/v1/networks/" + $Network.id +"/appliance/staticRoutes"

                try {
                    $StaticRoutes = Invoke-RestMethod -Method Get -Uri $StaticRoutesURI -Headers $Header -ErrorAction SilentlyContinue
                    foreach ($StaticRoute in $StaticRoutes) {
                        $StaticRouteInformation = [PSCustomObject]@{
                            Organization = $Organization.Name
                            Network = $Network.Name
                            Device = ($Device.Name -split " ") -join ","
                            Model = ($Device.model -split " ") -join ","
                            WanIP1 = ($Device.wan1Ip -split " ") -join ","
                            WanIP2 = ($Device.wan2Ip -split " ") -join ","
                            StaticRouteID = $StaticRoute.id  # Corrected property name
                            Name = $StaticRoute.name  # Corrected property name
                            Subnet = $StaticRoute.subnet
                            GatewayIp = $StaticRoute.gatewayIp
                            Enabled = $StaticRoute.enabled
                        }
                        $AllStaticRoutes += $StaticRouteInformation
                    }
                } catch {
                    Write-Host ($Organization.Name + ": " + $Network.Name + ": Has no $InfoType" )
                }
            }
        }
    }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllStaticRoutes | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType information to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllStaticRoutes | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}