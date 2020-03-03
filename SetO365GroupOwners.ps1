$supportOwners = @(
    "joe.smith@constoso.com",
    "joe.smith@constoso.com",
    "curley.smith@constoso.com"
)

$connGraph = Connect-PnPOnline -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All" -Url https://[TODO]-admin.sharepoint.com -ReturnConnection -UseWebLogin
$o365groupnameArray = @()

Import-Csv $PSScriptRoot"\o365GroupNames.csv" | ForEach-Object {
    $o365groupnameArray += $_.o365groupname
}


foreach ($o365groupname in $o365groupnameArray)
{
    $grpFound = Get-PnPUnifiedGroup -Identity $o365groupname 

    if ( $grpFound -ne $null )
    {
        Write-Output $("{0} group is found" -f $o365groupname)

        $ownerUserList = Get-PnPUnifiedGroupOwners -Identity $o365groupname 


        $owners2Add  = New-Object System.Collections.Generic.List[System.String]
        Write-Output "Current owners list"
        Write-Output $ownerUserList


        $owners2Add += $supportOwners;
        $existingOwners = New-Object System.Collections.Generic.List[System.String]
        foreach ( $upn in $ownerUserList)
        {
            if ( $upn.UserPrincipalName.Contains("[TODO YOUR TENANT].onmicrosoft.com") -eq $false )
            {
                $owners2Add += $upn.UserPrincipalName
                $existingOwners.Add($upn.UserPrincipalName)
            }
        }
        $owners2Add = $owners2Add | sort -Unique 
        # check owners2add has the support users
        $alreadySupportOwenrsPresent = $true
        foreach ( $itemEmail in $supportOwners)
        {
            if ( $existingOwners.Contains($itemEmail) -eq $false )
            {
                $alreadySupportOwenrsPresent = $false
                break;
            }
        }
    
        if ( $alreadySupportOwenrsPresent -eq $false)
        {
            if ( $owners2Add.Count -gt 0 )
            {
                Write-Output "Owners list to add including existing and new"
                Write-Output $owners2Add
                Set-PnPUnifiedGroup -Identity $o365groupname -Owners $owners2Add
            }
        }
        else
        {
            Write-Output $("Support owners are already present in {0}" -f $o365groupname)
        }
    }
    else
    {
        Write-Output $("{0} group is not found" -f $o365groupname)
    }

}
