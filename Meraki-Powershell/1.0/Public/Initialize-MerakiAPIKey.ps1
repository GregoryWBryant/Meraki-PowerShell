function Initialize-MerakiAPIKey {
    <#
    .SYNOPSIS
        Initializes a global header for Meraki API calls.

    .DESCRIPTION
        Make sure to call this function before making any Meraki API requests.
        This function sets up a global hashtable variable named `$global:Header`
        containing the necessary headers (API key and content type) for interacting
        with the Meraki Dashboard API. This header can be used in subsequent API calls
        without needing to specify the API key each time.

    .PARAMETER APIKey
        Your Meraki Dashboard API key. (Mandatory)

    .PARAMETER SaveFolderPath
        The folder where any output files will be saved (if applicable). (Default: "C:\Temp")

    .EXAMPLE
        Initialize-MerakiAPI -APIKey "1234567890abcdef"

        Sets the global header with the provided API key and uses "C:\Temp" as the default save folder.

.EXAMPLE
        Initialize-MerakiAPI -APIKey "1234567890abcdef" -SaveLocation "C:\Users\YourUser\Desktop"

        Sets the global header with the provided API key and uses "C:\Users\YourUser\Desktop as the default save folder.

    .NOTES
        This function creates a global variable named `$global:Header`.
        Make sure to call this function before making any Meraki API requests.
        Store your API key securely, ideally in an environment variable.
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [string]$SaveLocation = "C:\Temp" #Default value if none is provided.
    )

    $global:Header = @{
        "X-Cisco-Meraki-API-KEY" = $APIKey
        "Content-Type" = "application/json"
    }

    $global:SaveFolderPath = $SaveLocation
    $global:OrganizationURI = "https://api.meraki.com/api/v1/organizations/"
    $global:OrgErrorStatus = "Good"
}
