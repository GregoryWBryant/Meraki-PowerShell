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
        If specified, the results will not be saved to CSV files.

    .PARAMETER All
        If specified, the script will fetch data for all organizations.
        If not, the user will be prompted to choose a specific organization.

    .EXAMPLE
        Get-MerakiDHCPScopes -ShowOutPut

        This will fetch and display DHCP scope information for a specific organization chosen by the user.

    .EXAMPLE
        Get-MerakiDHCPScopes -All -NoSave

        This will fetch DHCP scope information for all organizations but won't display or save the results.

    .EXAMPLE
        Get-MerakiDHCPScopes

        This will fetch and save DHCP scope information for a specific organization chosen by the user, but won't display the results.

    .NOTES
        This function requires that you have ran Initialize-MerakiAPI and provided an API Key
        Ensure your API key has the necessary permissions to access organization and network data.
    #>

    param (
        [switch]$ShowOutPut,
        [switch]$NoSave,
        [switch]$All 
    )

    # Setup Variables
    $AllFixedIPs = @()
    $AllReservedIPs = @()

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
        Write-Host ("Gathering DHCP SCopes from: " + $Organization.Name)
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
                    Write-Host ($Organization.Name + ": " + $Network.Name + ": Has no vLans" )
                }
            }
        }
    }

    if ($ShowOutPut) {
        $AllFixedIPs | Out-GridView
        $AllReservedIPs | Out-GridView
    }

    if ((!$NoSave)){
        Write-Host ("Saving vLan informtion to: " + ($SaveLocation + "-FixedIPs.csv"))
        $AllFixedIPs | Export-Csv -Path ($SaveLocation + "-FixedIPs.csv") -NoTypeInformation
        Write-Host ("Saving vLan informtion to: " + ($SaveLocation + "-ReservedIPs.csv"))
        $AllReservedIPs | Export-Csv -Path ($SaveLocation + "-ReservedIPs.csv") -NoTypeInformation
    }
}