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
        If specified, does not save the client information to a CSV file.

    .PARAMETER All
        If specified, fetches clients from all organizations. Otherwise, prompts for selection.

    .EXAMPLE
        Get-MerakiClients

        Fetches client data for a single organization (prompts for selection)

    .EXAMPLE
        Get-MerakiClients -All

        Fetches client data for all organizations

    .EXAMPLE
        Get-MerakiClients -ShowOutput

        Fetches client data for a single organization (prompts for selection) and displays it in the console using Out-GridView.

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
    $AllClients = @()

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
            return  
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
        Write-Host ("Collecting Clients from: " + $Organization.Name)
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

    if($ShowOutPut) {
        $AllClients | Out-GridView
    }

    if((!$NoSave)){
        Write-Host ("Saving Network informtion to: " + ($SaveLocation + "-Clients.csv"))
        $AllClients | Export-Csv -Path ($SaveLocation + "-Clients.csv") -NoTypeInformation
    }
}