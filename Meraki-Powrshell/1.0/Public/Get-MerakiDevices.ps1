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
        If specified, does not save the information to CSV files.

    .PARAMETER All
        If specified, fetches data from all organizations. Otherwise, prompts for selection.

    .EXAMPLE
        Get-MerakivDevices

        Fetches Device data for a single organization (prompts for selection)

    .EXAMPLE
        Get-MerakivDevices -All

        Fetches Device data for all organizations

    .EXAMPLE
        Get-MerakivDevices -ShowOutput

        Fetches Device data for a single organization (prompts for selection) and displays it in the console.

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
    $AllDevices = @()

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

        Write-Host ("Gathering Devices from: " + $Organization.Name)
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

    if ($ShowOutPut) {
        $AllDevices | Out-GridView
    }

    if ((!$NoSave)){
        Write-Host ("Saving Device informtion to: " + ($SaveLocation + "-Devices.csv"))
        $AllDevices | Export-Csv -Path ($SaveLocation + "-Devices.csv") -NoTypeInformation
    }
}