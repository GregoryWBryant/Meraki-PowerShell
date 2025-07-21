function Get-MerakiUplinks {
    <#
    .SYNOPSIS
        Retrieves Uplink information from Meraki orginizations.

    .DESCRIPTION
        This function fetches Uplink details for one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once.
        The results can be displayed in the console or saved as a CSV file.

    .PARAMETER ShowOutput
        If specified, displays the Uplink data in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the Uplink data to a CSV file, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches Uplink data from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches Uplink data from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakiUplinks

        Fetches Uplink data for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakiUplinks -All

        Fetches Uplink data for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakiUplinks -ShowOutput

        Fetches Uplink data for a single organization (prompts for selection) and displays it in the console.

    .EXAMPLE
        Get-MerakiUplinks -Company "Contoso"

        Fetches Uplink data for any company with Contoso in the organization's name

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
    $AllUplinks = @()
    $InfoType = "Uplinks"

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
        
        $NetworksURI = ($OrganizationURI + $Organizations.id + "/networks")

        try {
            $Networks = Invoke-RestMethod -Method Get -Uri $NetworksURI -Headers $Header -ErrorAction SilentlyContinue
        } catch {
            $Networks = $null
        }

        $UplinkURI = ($OrganizationURI + $Organization.id + "/uplinks/statuses")

        try {
            $Uplinks = Invoke-RestMethod -Method Get -Uri $UplinkURI -Headers $header -ErrorAction SilentlyContinue
        } catch {
            $Uplinks = $null
        }

        foreach ($Uplink in $Uplinks) {

            try {

                $Network = $Networks | Where-Object { $_.id -eq $Uplink.networkId }
                if ($Uplink.uplinks.interface.count -gt 1) {

                    Foreach ($UplinkInterface in $Uplink.uplinks) {

                        $NewUplink = [PSCustomObject]@{
                            Organization = $Organization.Name
                            NetworkName = $Network.name
                            Serial = $Uplink.serial
                            Model = $Uplink.model
                            HighAvilability = $Uplink.highAvailability.enabled
                            HighAvilabiltyRole = $Uplink.highAvailability.role
                            LastReportTime = $Uplink.lastReportedAt
                            Inerface = $UplinkInterface.interface
                            Status = $UplinkInterface.status
                            IP = $UplinkInterface.ip
                            Gateway = $UplinkInterface.gateway
                            PublicIP = $UplinkInterface.publicIp
                            PrimaryDNS = $UplinkInterface.primaryDNS
                            SecondaryDNS = $UplinkInterface.secondaryDNS
                            IPAssisgnedby = $UplinkInterface.IPAssignedby
                            }
                     }
                } else {

                    $NewUplink = [PSCustomObject]@{
                        Organization = $Organization.Name
                        NetworkName = $Network.name
                        Serial = $Uplink.serial
                        Model = $Uplink.model
                        HighAvilability = $Uplink.highAvailability.enabled
                        HighAvilabiltyRole = $Uplink.highAvailability.role
                        LastReportTime = $Uplink.lastReportedAt
                        Inerface = $Uplink.uplinks.interface
                        Status = $Uplink.uplinks.status
                        IP = $Uplink.uplinks.ip
                        Gateway = $Uplink.uplinks.gateway
                        PublicIP = $Uplink.uplinks.publicIp
                        PrimaryDNS = $Uplink.uplinks.primaryDNS
                        SecondaryDNS = $Uplink.uplinks.secondaryDNS
                        IPAssisgnedby = $Uplink.uplinks.IPAssignedby
                        }
                    }
                 
                    $AllUplinks += $NewUplink
                
                } catch {
                    Write-Host ($Organization.Name + " " + ": Has no $InfoType" )
                }
         }
     }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllUplinks | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType informtion to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllUplinks | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}