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
        If specified, does not save the DHCP information to a CSV file.

    .PARAMETER All
        If specified, fetches DHCP information from all organizations. Otherwise, prompts for selection.

    .EXAMPLE
        Get-MerakiDhcpInfo -All

        Fetches DHCP information for all organizations and saves it to "C:\Temp\AllOrgs-DHCPInfo.csv".

    .EXAMPLE
        Get-MerakiDhcpInfo

        Fetches DHCP information for a single organization (prompts for selection) and saves it to "C:\Temp\<Organization Name>-DHCPInfo.csv".

    .EXAMPLE
        Get-MerakiDhcpInfo -ShowOutput

        Fetches DHCP information for a single organization (prompts for selection) and displays it in the console.

    .NOTES
        This function requires the `Invoke-RestMethod` cmdlet.
        Ensure the `$Header` variable is set with your Meraki API key before using this function.
        Typically, you would use the `Initialize-MerakiAPI` function to set the header.
    #>

    param (
        [switch]$ShowOutput,
        [switch]$NoSave,
        [switch]$All
    )

    # Setup Variables
    $AllDhcpInfo = @()  

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
        Write-Host ("Gathering DHCP Information from: " + $Organization.Name)
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

    if ($ShowOutPut) {
        $AllDhcpInfo | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving DHCP information to: " + ($SaveLocation + "-DHCPInfo.csv"))
        $AllDhcpInfo | Export-Csv -Path ($SaveLocation + "-DHCPInfo.csv") -NoTypeInformation
    }
}