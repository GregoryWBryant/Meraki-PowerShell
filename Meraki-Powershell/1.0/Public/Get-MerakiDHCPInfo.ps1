function Get-MerakiDHCPInfo {
    <#
    .SYNOPSIS
        Retrieves DHCP configuration information from Meraki devices.

    .DESCRIPTION
        This function fetches DHCP configuration details for one or all organizations within your Meraki dashboard.
        It identifies devices capable of DHCP services (MX or MS) and retrieves their configuration.
        The results can be displayed in the console or saved as a CSV file.

    .PARAMETER ShowOutput
        If specified, displays the DHCP information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the DHCP information to a CSV file, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches DHCP information from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches DHCP Information from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiDhcpInfo -All

        Fetches DHCP information for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakiDhcpInfo

        Fetches DHCP information for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakiDhcpInfo -ShowOutput

        Fetches DHCP information for a single organization (prompts for selection) and displays it in the console.

    .EXAMPLE
        Get-MerakiDHCPInfo -Company "Contoso"

        Fetches DHCP Information data for any company with Contoso in the organization's name

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
    $AllDhcpInfo = @()
    $InfoType = "DHCP Info"

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
        $NetworksURI = ($OrganizationURI + $Organization.id + '/networks')

        try {
            $Networks = Invoke-RestMethod -Method Get -Uri $NetworksURI -Headers $Header -ErrorAction Stop
        } catch {
            $Networks = $null
        }

        foreach ($Network in $Networks) {
            $devicesUri = "$NetworksURI/$($Network.id)/devices"
            try {
                $devices = Invoke-RestMethod -Method Get -Uri $devicesUri -Headers $Header
            } catch {
                $devices = $null
            }
            
            foreach ($device in $devices) {
                if ($device.model -match 'MX' -or $device.model -match 'MS') {
                    $dhcpSubnetsUri = "https://api.meraki.com/api/v1/devices/$($device.serial)/appliance/dhcp/subnets"
                    try {
                        $dhcpSubnets = Invoke-RestMethod -Method Get -Uri $dhcpSubnetsUri -Headers $Header
                        
                        foreach ($subnet in $dhcpSubnets) {
                            $dhcpInfo = [PSCustomObject]@{
                                Organization = $Organization.name
                                Network      = $Network.name
                                DeviceModel  = $device.model
                                Subnet       = $subnet.subnet
                                DHCPMode     = $subnet.dhcpMode
                            }
                            $AllDhcpInfo += $dhcpInfo
                        }
                    } catch {
                        Write-Host "$($Organization.Name): $($Network.Name): $($device.model): No DHCP subnets found or an error occurred."
                    }
                }
            }
        }
    }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllDhcpInfo | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType information to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllDhcpInfo | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}