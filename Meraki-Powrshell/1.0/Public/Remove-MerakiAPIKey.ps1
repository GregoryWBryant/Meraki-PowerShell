function Remove-MerakiAPIKey {
    <#
    .SYNOPSIS
       Removes the global variables created by Initialize-MerakiAPI.

    .DESCRIPTION
        This function removes the "$global:Header" and "$global:SaveFolderPath"
        variables from the global scope.  It should be called when you are finished
        making Meraki API calls to clean up the global environment.

    .EXAMPLE
        Initialize-MerakiAPI -APIKey "1234567890abcdef"
        # ... make Meraki API calls ...
        Remove-MerakiAPI 
    #>
    
    # Remove the global variables
    Remove-Variable Header -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable SaveFolderPath -Scope Global -ErrorAction SilentlyContinue
}