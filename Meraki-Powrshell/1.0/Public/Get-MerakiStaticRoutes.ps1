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
        If specified, does not save the static route information to a CSV file.

    .PARAMETER All
        If specified, fetches static routes from all organizations. Otherwise, prompts for selection.

    .EXAMPLE
        Get-MerakiStaticRoutes

        Fetches static route data for a single organization (prompts for selection)

    .EXAMPLE
        Get-MerakiStaticRoutes -All

        Fetches static route data for all organizations

    .EXAMPLE
        Get-MerakiStaticRoutes -ShowOutput

        Fetches static route data for a single organization (prompts for selection) and displays it in the console.

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
    $AllStaticRoutes = @()  # Only collect static routes

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
        Write-Host ("Gathering Static Routes from: " + $Organization.Name)
        $NetworksURI = ($OrganizationURI + $Organization.id + "/networks")

        try {
            $Networks = Invoke-RestMethod -Method Get -Uri $NetworksURI -Headers $Header -ErrorAction SilentlyContinue
        } catch {
            $Networks = $null
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
                    Write-Host ($Organization.Name + ": " + $Network.Name + ": Has no Static Routes" )
                }
            }
        }
    }

    if ($ShowOutPut) {
        $AllStaticRoutes | Out-GridView
    }

    if ((!$NoSave)){
        Write-Host ("Saving Static Route information to: " + ($SaveLocation + "-StaticRoutes.csv"))
        $AllStaticRoutes | Export-Csv -Path ($SaveLocation + "-StaticRoutes.csv") -NoTypeInformation
    }
}