
$tenantName = "TODO YOUR TENANT"
$spoAdminCenterURL = $("https://{0}-admin.sharepoint.com" -f $tenantName)
$connAdmin  = Connect-PnPOnline -Url $spoAdminCenterURL -ReturnConnection -UseWebLogin
$connGraph = Connect-PnPOnline -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All" -Url https://[TODO YOUR TENANT]-admin.sharepoint.com -ReturnConnection -UseWebLogin
$o365groupnameArray = @()

Import-Csv $PSScriptRoot"\o365GroupNames.csv" | ForEach-Object {
    $o365groupnameArray += $_.o365groupname
}


foreach ($o365groupname in $o365groupnameArray)
{
    try
    {

        $grpFound = Get-PnPUnifiedGroup -Identity $o365groupname 

        if ( $grpFound -ne $null )
        {
            Write-Output $("{0} group is found" -f $o365groupname)

            $ownersUserList = Get-PnPUnifiedGroupOwners -Identity $o365groupname 
            $membersUsersList = Get-PnPUnifiedGroupMembers -Identity $o365groupname



            $siteURL = $("https://{0}.sharepoint.com/sites/{1}" -f $tenantName, $o365groupname)
            $parentConn = Connect-PnPOnline -ReturnConnection -Url $siteURL  -UseWebLogin
            $parentWebUrl = "/sites/"+$o365groupname

            $currentWeb = Get-PnPWeb $parentWebUrl -Connection $parentConn 
            $ownersgroupname = $currentWeb.Title +' Owners'
            $membersgroupname = $currentWeb.Title +' Members'
            $Ownersgroup = Get-PnPGroup -Identity $ownersgroupname -Connection $parentConn -Web $currentWeb 
            $membersgroup = Get-PnPGroup -Identity $membersgroupname -Connection $parentConn -Web $currentWeb 

            $spoOwnersUserList = Get-PnPGroupMembers -Identity $ownersgroup
            $spoMembersUserList = Get-PnPGroupMembers -Identity $membersgroup





            #get email array for existing owners in office 365 group
            $existingOwners = New-Object System.Collections.Generic.List[System.String]
            foreach ( $upn in $ownersUserList)
            {
                if ( $upn.UserPrincipalName.Contains("@contoso.com") -eq $true )
                {
                    $existingOwners.Add($upn.UserPrincipalName)
                }
            }
            #get email array for existing members in office 365 group
            $existingMembers = New-Object System.Collections.Generic.List[System.String]
            foreach ( $upn in $membersUsersList)
            {
                if ( $upn.UserPrincipalName.Contains("@contoso.com") -eq $true )
                {
                    $existingMembers.Add($upn.UserPrincipalName)
                }
            }

            $owners2Add  = New-Object System.Collections.Generic.List[System.String]
            foreach ( $spoOwnerItem in $spoOwnersUserList)
            {
                # check is the user in SPO owner has contoso.com and it is alredy not a o365 owner
                if( ( $spoOwnerItem.Email.Contains("@contoso.com") -eq $true) -and 
                    ( $existingOwners.Contains($spoOwnerItem.Email) -eq $false ) )
                {
                    $owners2Add += $spoOwnerItem.Email
                }
            }

            $members2Add  = New-Object System.Collections.Generic.List[System.String]

            foreach ( $spoMemberItem in $spoMembersUserList)
            {
                # check is the user in SPO owner has contoso.com and it is alredy not a o365 owner
                if( ( $spoMemberItem.Email.Contains("@contoso.com") -eq $true) -and 
                    ( $existingMembers.Contains($spoMemberItem.Email) -eq $false ) )
                {
                    $members2Add += $spoMemberItem.Email
                }
            }

            Write-Output $("O365 Group's owners   = {0}" -f $existingOwners.Count)
            Write-Output $("O365 Group's members  = {0}" -f $existingMembers.Count)
            Write-Output $("SPO  Group's owners   = {0}" -f $spoOwnersUserList.Count)
            Write-Output $("SPO  Group's members  = {0}" -f $spoMembersUserList.Count)


            if ( $owners2Add.Count -gt 0 )
            {
                Write-Output $("Total new owners2Add.Count = {0}" -f $owners2Add.Count)
                $owners2Add += $existingOwners
                Write-Output $("Total including existing and new owners2Add.Count = {0}" -f $owners2Add.Count)
                try
                {  
                    Set-PnPUnifiedGroup -Identity $o365groupname -Owners $owners2Add
                }
                catch 
                {
                    Write-Output $_.Exception
                }

            }
            else
            {
                Write-Output "Owners are up to date."
            }



            if ( $members2Add.Count -gt 0 )
            {
                Write-Output $("Total new members2Add.Count = {0}" -f $members2Add.Count)
                $members2Add += $existingMembers
                Write-Output $("Total including existing and new members2Add.Count = {0}" -f $members2Add.Count)
                try
                {  
                    Set-PnPUnifiedGroup -Identity $o365groupname -Members $members2Add
                }
                catch 
                {
                    Write-Output $_.Exception
                }
            }
            else
            {
                Write-Output "Members are up to date."
            }
        }
        else
        {
            Write-Output $("{0} group is not found" -f $o365groupname)
        }
    }
    catch 
    {
        Write-Output $("{0} group exception" -f $o365groupname)
        Write-Output $_.Exception
    }
}


