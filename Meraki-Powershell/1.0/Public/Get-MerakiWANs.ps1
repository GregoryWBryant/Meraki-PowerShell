function Get-MerakiWANs {
    <#
    .SYNOPSIS
        Retrieves WAN information from Meraki networks.

    .DESCRIPTION
        This function gets Device details for one or all organizations within your Meraki dashboard.
        You can choose to retrieve data for a specific organization or all organizations at once.
        The results can be displayed in the console or saved as CSV files.

    .PARAMETER ShowOutput
        If specified, displays the information in the console using Out-GridView.

    .PARAMETER NoSave
        If specified, does not save the information to CSV files, instead shows in the console using Out-GridView.

    .PARAMETER All
        If specified, fetches WAN data from all organizations. Otherwise, prompts for selection.

    .PARAMETER Company
        If specified, fetches WAN from all organizations that match the pattern of the name provided.

    .EXAMPLE
        Get-MerakivWAns

        Fetches WAN data for a single organization (prompts for selection) and saves it to csv.

    .EXAMPLE
        Get-MerakivWANs -All

        Fetches WAN data for all organizations and saves it to csv.

    .EXAMPLE
        Get-MerakivWANs -ShowOutput

        Fetches WAN data for a single organization (prompts for selection) and displays it in the console.

    .EXAMPLE
        Get-MerakiWANs -Company "Contoso"

        Fetches WAN data for any company with Contoso in the organization's name

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
    $AllWANs = @()
    $InfoType = "WANs"

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

            $MXs = $Devices | Where-Object {$_.model -like "*MX*"}
            
            foreach ($MX in $MXs) {

                $WANURI = "https://api.meraki.com/api/v1/devices/" + $MX.serial + "/appliance/uplinks/settings"
                try {

                    $WANs = Invoke-RestMethod -Method Get -Uri $WANURI -Headers $Header
                    foreach ($interfaceName in $WANs.interfaces.PSObject.Properties.Name){

                        $WanInterface = $WANs.interfaces.$interfaceName
                        $AssignmentType = $wanInterface.svis.ipv4.assignmentMode
                        $Address = $wanInterface.svis.ipv4.address
                        $Gateway = $wanInterface.svis.ipv4.gateway
                        $NameServers = $wanInterface.svis.ipv4.nameservers.addresses -join ", "

                        $NewWAN = [PSCustomObject]@{
                            Organization    = $Organization.Name
                            NetworkName     = $Network.name
                            Serial          = $MX.serial
                            Interface       = $interfaceName
                            AssignmentType  = $AssignmentType
                            Address         = $Address
                            Gateway         = $Gateway
                            NameServers     = $NameServers
                            }

                        $AllWans += $NewWAN

                        }
                            
                    } catch {}
                }
            }
        }

    if (($ShowOutPut) -or ($NoSave)) {
        $AllWANs | Out-GridView
    }

    if ((!$NoSave)) {
        Write-Host ("Saving $InfoType informtion to: " + ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv"))
        $AllWANs | Export-Csv -Path ($SaveLocation + "-" + ($InfoType -replace " ","-") + ".csv") -NoTypeInformation
    }
}