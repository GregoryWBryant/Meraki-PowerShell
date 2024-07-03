function Get-MerakiDHCPScopes {
    <#
    .SYNOPSIS
        Retrieves DHCP scopes (fixed IP assignments and reserved IP ranges) for Meraki organizations and networks.

    .DESCRIPTION
        This function retrieves DHCP scope information (fixed IP assignments and reserved IP ranges) from Meraki organizations and networks.
        It can fetch data for all organizations or for a specific organization chosen by the user.
        The output can be displayed in a grid view and saved as CSV files.

    .PARAMETER ShowOutPut
        If specified, the results will be displayed in a grid view.

    .PARAMETER NoSave
        If specified, the results will not be saved to CSV files, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches DHCP Scope information from all organizations and saves it to csv.

    .PARAMETER Company
        If specified, fetches DHCP Scope information from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiDHCPScopes -ShowOutPut

        This will fetch and display DHCP scope information for a specific organization chosen by the user.

    .EXAMPLE
        Get-MerakiDHCPScopes -All -NoSave

        This will fetch DHCP scope information for all organizations but won't display or save the results.

    .EXAMPLE
        Get-MerakiDHCPScopes

        This will fetch and save DHCP scope information for a specific organization chosen by the user, but won't display the results.

    .EXAMPLE
        Get-MerakiDHCPScopes -Company "Contoso"

        Fetches DHCP Scope information for any company with Contoso in the organization's name

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
    $AllFixedIPs = @()
    $AllReservedIPs = @()
    $InfoType = "DHCP Scopes"

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
            if ($Network.productTypes -eq "appliance") {
                $vLansURI = "https://api.meraki.com/api/v1/networks/" + $Network.id +"/appliance/vlans"

                try {
                    $vLans = Invoke-RestMethod -Method Get -Uri $vLansURI -Headers $Header -ErrorAction SilentlyContinue
                    foreach ($vLan in $vLans) {
                        foreach ($fixedIpAssignment in $vLan.fixedIpAssignments) {

                            $fixedIpAssignmentInformation = [PSCustomObject]@{
                                Organization = $Organization.name
                                Network = $Network.name
                                vLan = $vLan.name
                                name = $fixedIpAssignment.name
                                ip = $fixedIpAssignment.ip
                                mac = $fixedIpAssignment.mac                                   
                            }

                            $AllFixedIPs += $fixedIpAssignmentInformation

                            foreach($reservedIpRange in $vLan.reservedIpRanges){
                                $reservedIpRangeInformation = [PSCustomObject]@{
                                    Organization = $Organization.name
                                    Network = $Network.name
                                    vLan = $vLan.name
                                    comment = $reservedIpRange.comment
                                    start = $reservedIpRange.start
                                    end = $reservedIpRange.end
                                }

                                $AllReservedIPs += $reservedIpRangeInformation
                            
                            }
                        }
                    }
                } catch {
                    Write-Host ($Organization.Name + ": " + $Network.Name + ": Has no $InfoType" )
                }
            }
        }
    }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllFixedIPs | Out-GridView
        $AllReservedIPs | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving vLan informtion to: " + ($SaveLocation + "-FixedIPs.csv"))
        $AllFixedIPs | Export-Csv -Path ($SaveLocation + "-FixedIPs.csv") -NoTypeInformation
        Write-Host ("Saving vLan informtion to: " + ($SaveLocation + "-ReservedIPs.csv"))
        $AllReservedIPs | Export-Csv -Path ($SaveLocation + "-ReservedIPs.csv") -NoTypeInformation
    }
}