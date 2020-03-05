
$tenantName = "TODO YOUR TENANT"
$spoAdminCenterURL = $("https://{0}-admin.sharepoint.com" -f $tenantName)
$connAdmin  = Connect-PnPOnline -Url $spoAdminCenterURL -ReturnConnection -UseWebLogin
$connGraph = Connect-PnPOnline -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All" -Url https://dvagov-admin.sharepoint.com -ReturnConnection -UseWebLogin
$o365groupnameArray = @()

Import-Csv $PSScriptRoot"\o365GroupNames.csv" | ForEach-Object {
    $o365groupnameArray += $_.o365groupname
}
function Write-Log
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path='C:\Logs\PowerShellLog.log',
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",
        
        [Parameter(Mandatory=$false)]
        [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {
        
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
            }

        else {
            # Nothing to see here yet.
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
                }
            }
        
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
        ## also dump to console
        #$savedColor = $host.UI.RawUI.ForegroundColor 
        #$host.UI.RawUI.ForegroundColor = "DarkGreen"
        Write-Output  $message 
        #Write-Host  $message 
        #$host.UI.RawUI.ForegroundColor = $savedColor
    }
    End
    {
    }
}

$LogFolderPath = $("{0}\LogFiles\{1}" -f $psScriptRoot, (Get-Date -Format "MM-dd-yy"))
$LogFileName = $("{0}\Log-{1}-{2}.txt" -f $LogFolderPath, $sitePlaceid , (Get-Date -Format "HH_mm_ss"))
if( -not ( Test-Path -Path $LogFolderPath ) )
{
    # create directory
    New-Item -ItemType Directory -Force -Path $LogFolderPath
}


foreach ($o365groupname in $o365groupnameArray)
{
    try
    {

        $grpFound = Get-PnPUnifiedGroup -Identity $o365groupname 

        if ( $grpFound -ne $null )
        {
            Write-Log -Path $LogFileName $("{0} group is found" -f $o365groupname)

            $ownersUserList = Get-PnPUnifiedGroupOwners -Identity $o365groupname 
            $membersUsersList = Get-PnPUnifiedGroupMembers -Identity $o365groupname



            $siteURL = $("https://{0}.sharepoint.com/sites/{1}" -f $tenantName, $o365groupname)
            Write-Log -Path $LogFileName $("siteURL: {0} " -f $siteURL)
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

            Write-Log -Path $LogFileName $("O365 Group's owners   = {0}" -f $existingOwners.Count)
            Write-Log -Path $LogFileName $("O365 Group's members  = {0}" -f $existingMembers.Count)
            Write-Log -Path $LogFileName $("SPO  Group's owners   = {0}" -f $spoOwnersUserList.Count)
            Write-Log -Path $LogFileName $("SPO  Group's members  = {0}" -f $spoMembersUserList.Count)


            if ( $owners2Add.Count -gt 0 )
            {
                Write-Log -Path $LogFileName $("Total new owners2Add.Count = {0}" -f $owners2Add.Count)
                $owners2Add += $existingOwners
                Write-Log -Path $LogFileName $("Total including existing and new owners2Add.Count = {0}" -f $owners2Add.Count)
                try
                {  
                    Set-PnPUnifiedGroup -Identity $o365groupname -Owners $owners2Add
                }
                catch 
                {
                    Write-Log -Path $LogFileName $_.Exception
                }

            }
            else
            {
                Write-Log -Path $LogFileName "Owners are up to date."
            }



            if ( $members2Add.Count -gt 0 )
            {
                Write-Log -Path $LogFileName $("Total new members2Add.Count = {0}" -f $members2Add.Count)
                $members2Add += $existingMembers
                Write-Log -Path $LogFileName $("Total including existing and new members2Add.Count = {0}" -f $members2Add.Count)
                try
                {  
                    Set-PnPUnifiedGroup -Identity $o365groupname -Members $members2Add
                }
                catch 
                {
                    Write-Log -Path $LogFileName $_.Exception
                }
            }
            else
            {
                Write-Log -Path $LogFileName "Members are up to date."
            }
        }
        else
        {
            Write-Log -Path $LogFileName $("{0} group is not found" -f $o365groupname)
        }
    }
    catch 
    {
        Write-Log -Path $LogFileName $("{0} group exception" -f $o365groupname)
        Write-Log -Path $LogFileName $_.Exception
    }
}


