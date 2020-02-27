<#
#>

Clear-Host 
$ErrorActionPreference = "Stop"
$LogFileName = "" #make as global 
$hosturi = "" #make as global 
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" #make as global

# This flag will move the files
$g_MoveContentFlag         = $true
# This flag will assign users to SPO groups
$g_AddUser2SPOGroupsFlag   = $true
# This flag will assign users to O365 groups 
$g_AddUser2O365GroupsFlag  = $true
# This flag will create sub places (meaning 
$g_ProcessSubPlacesFlag    = $true
# This flag will move blogs, to move blogs you must also have the sub space flag turned on
$g_MoveBlogsFlag           = $true


$scaOwners = @(
    "user@contso.com",
)

$connAdmin = Connect-PnPOnline -Url https://{{TODO-YOURTENANTNAME}}-admin.sharepoint.com -ReturnConnection -UseWebLogin

$objSpaceUsersTemplate = @{
    'placeID' = $null
    'userEmail'=$null
}
$g_spaceUsersArray = New-Object System.Collections.Generic.List[System.Object]

Import-Csv $PSScriptRoot"\SpaceAdminInfoByPlaceID.csv" | ForEach-Object {
    $obj = New-Object -TypeName PSObject -Property $objSpaceUsersTemplate
    $obj.'placeID'          = $_.placeid
    $obj.'userEmail'        = $_.user
    $g_spaceUsersArray.Add($obj)
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

function Write-Exception2LogFile($exception, $func2Report)
{
    Write-Log -Path $LogFileName $("Caught an exception at : {0}" -f $func2Report)
    Write-Log -Path $LogFileName $("Exception Type: {0}" -f $exception.GetType().FullName)
    Write-Log -Path $LogFileName $("Exception Message: {0}"-f $exception.Message)
}

function Get-PlaceById([string]$placeId, [string] $fields) 
{
    $localUri = $("{0}/places/{1}" -f $hosturi, $placeId) 
    if ($fields.Trim().Length -gt 0 )
    {
        $localUri = $("{0}/places/{1}?fields={2}" -f $hosturi, $placeId, $fields) 
    }
    Write-Log -Path $LogFileName  $localUri
    $response = Invoke-RestMethod -Uri $localUri -Headers $headers -Method Get 
    return $response
}

function Set-Avatar([string]$url, $grpIdentity) 
{
    try
    {
        Write-Log -Path $LogFileName  $("URL : {0}" -f $url) 
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get 

        $aFileName = $("{0}\{1}.png" -f $PSScriptRoot, $grpIdentity)
        [io.file]::WriteAllBytes($aFileName,$response.ToCharArray())

        Set-PnPUnifiedGroup -Identity $grpIdentity -GroupLogoPath $aFileName

        [io.file]::Delete($aFileName)
    }
    catch 
    {
        Write-Exception2LogFile -exception $_.Exception -func2Report "Assign-Permisions2O365Groups"
    }

}


function Assign-Permisions2O365Groups ($uri,[string]$placeId, $parentConn, $WebRelativePath    )
{
    try 
    {
       
        if ( $uri.Contains('appliedEntitlements') ) 
        {
            # if it falls here, means it is a space.
        }
        else
        {
            #$connGraph = Connect-PnPOnline -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All" -Url https://{{TODO-YOURTENANTNAME}}-admin.sharepoint.com -ReturnConnection -UseWebLogin

            $rsPlaceInfo = Get-PlaceById -placeId $placeId
            # if it falls here, means it is a group.
            Write-Log -Path $LogFileName  $("URL : {0}" -f $uri)        
            $responsedocs = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

            # notice the VHA is added to everything
            $sitecollectionURL =  $org + $rs1.displayName
            $ownerUserList = Get-PnPUnifiedGroupOwners -Identity $sitecollectionURL 
            $memberUsersList = Get-PnPUnifiedGroupMembers -Identity $sitecollectionURL

            $owners2Add  = New-Object System.Collections.Generic.List[System.String]
            $members2Add = New-Object System.Collections.Generic.List[System.String]


            do 
            {

                foreach($listItem in ($responsedocs.list))
                {
                    try
                    {  
                        $personEmail = $listItem.person.emails.value 
                        if ( $listItem.state -eq 'owner' ) 
                        {
                            $alreadyAdded = $ownerUserList | Where-Object { $_.UserPrincipalName -ieq $personEmail }
                            if ( $alreadyAdded -eq $null )
                            {
                                Write-Log -Path $LogFileName $("Type : {0} Add {1} to {2}" -f $listItem.state, $personEmail, $sitecollectionURL);
                                $owners2Add.Add($personEmail)
                            }  
                        }
                        elseif  ( $listItem.state -eq 'member' )   
                        {
                            $alreadyAdded =  $memberUsersList | Where-Object { $_.UserPrincipalName -ieq $personEmail }
                            if ( $alreadyAdded -eq $null )
                            {
                                Write-Log -Path $LogFileName $("Type: {0} Add {1} to {2}" -f $listItem.state, $personEmail, $sitecollectionURL);
                                $members2Add.Add($personEmail);
                            }
                        }
                    }
                    catch 
                    {
                        Write-Exception2LogFile -exception $_.Exception -func2Report "Assign-Permisions2O365Groups in for loop"
                    }
                }
                $nextitems = $responsedocs.links.next 
                if ( $nextitems) 
                {
                    Write-Log -Path $LogFileName  $("URL : {0}" -f $nextitems)        
                    $responsedocs =Invoke-RestMethod -Uri $nextitems -Headers $headers -Method Get
                }
            }while ($nextitems) 
            <#         
            # just add user to owner's list.
            $personEmail = 'adminuser@{{TODO-YOURTENANTNAME}}.onmicrosoft.com'
            $alreadyAdded = $ownerUserList | Where-Object { $_.UserPrincipalName -ieq $personEmail }
            if ( $alreadyAdded -eq $null )
            {
                Write-Log -Path $LogFileName $("Type : {0} Add {1} to {2}" -f $listItem.state, $personEmail, $sitecollectionURL);
                $owners2Add.Add($personEmail)
            } 
            #> 
            if ( $owners2Add.Count -gt 0 )
            {
                Set-PnPUnifiedGroup -Identity $sitecollectionURL -Owners $owners2Add
            }
            if ( $members2Add.Count -gt 0 )
            {
                Set-PnPUnifiedGroup -Identity $sitecollectionURL -Members $members2Add
            }
            # setting logo does not work, needs more investigation
            #Set-Avatar -url $rsPlaceInfo.resources.avatar.ref -grpIdentity $sitecollectionURL

        }
    }
    catch 
    {
        Write-Exception2LogFile -exception $_.Exception -func2Report "Assign-Permisions2O365Groups"
    }

}


function Assign-Permisions ($uri,[string]$placeId, $parentConn, $WebRelativePath    )
{
    try 
    {
        $currentWeb = Get-PnPWeb $WebRelativePath -Connection $parentConn 
        $ownersgroupname = $currentWeb.Title +' Owners'
        $membersgroupname = $currentWeb.Title +' Members'
        $Ownersgroup = Get-PnPGroup -Identity $ownersgroupname -Connection $parentConn -Web $currentWeb 
        $membersgroup = Get-PnPGroup -Identity $membersgroupname -Connection $parentConn -Web $currentWeb 
        
        if ( $uri.Contains('appliedEntitlements') ) 
        {
            # if it falls here, means it is a space.

            <#
            # to find the parent 
            $rs2 = Get-PlaceById -placeId $placeId
            $parentPlaceID = ""
            $notFound1001 = $true
            do
            {
                if ( $rs2.parent.contains( '1001') )
                {
                    $notFound1001 = $false
                    $parentPlaceID = $rs2.placeID
                }
                else
                {
                    Write-Log -Path $LogFileName  $("URL : {0}" -f $rs2.parent) 
                    $rs2 = Invoke-RestMethod -Uri $rs2.parent -Headers $headers -Method Get 
                }

            } while ($notFound1001)
            #>

            $adminUsers = $g_spaceUsersArray | Where-Object { $_.placeID -eq $placeId } | Select-Object userEmail

            if ( ( $adminUsers -ne $null) -and 
                ( $adminUsers.Count -gt 0 ) )
            {
                foreach($adminUser in $adminUsers)
                {
                    try
                    {         
                        $alreadyAdded = Get-PnPGroupMembers -Identity $ownersgroupname | Where-Object { $_.Email -ieq $adminUser.userEmail }
                        if ( $alreadyAdded -eq $null )
                        {
                            Write-Log -Path $LogFileName $("Add Person : {0} to {1}" -f $adminUser.userEmail, $ownersgroupname)        
                            $fix = Add-PnPUserToGroup -LoginName $adminUser.userEmail -Identity $Ownersgroup -WarningAction Stop -ErrorAction Stop
                        }
                    }
                    catch 
                    {
                        Write-Exception2LogFile -exception $_.Exception -func2Report "Assign-Permisions in for loop for Add-PnPUserToGroup"
                    }
                }                
            }
            
            <#
            # This code may not be required
            $entitlementsURI = $("{0}/places/{1}/appliedEntitlements" -f $hosturi, $parentPlaceID)
            Write-Log -Path $LogFileName  $("URL : {0}" -f $entitlementsURI)        
            $responsedocs = Invoke-RestMethod -Uri $entitlementsURI -Headers $headers -Method Get
            do 
            {
                foreach($listItem in ($responsedocs.list))
                {
                    if ( $listItem.person )
                    {
                        try
                        {         
                            $alreadyAdded = Get-PnPGroupMembers -Identity $membersgroupname | Where-Object { $_.Email -ieq $response.emails[0].value }
                            if ( $alreadyAdded -eq $null )
                            {
                                $response = Invoke-RestMethod -Uri $listItem.person -Headers $headers -Method Get
                                Write-Log -Path $LogFileName $("Add Person : {0} to {1}" -f $response.emails[0].value, $membersgroupname)        
                                $fix = Add-PnPUserToGroup -LoginName $response.emails[0].value -Identity $membersgroup -WarningAction Stop -ErrorAction Stop
                            }
                        }
                        catch 
                        {
                            Write-Exception2LogFile -exception $_.Exception -func2Report "Assign-Permisions in for loop for Add-PnPUserToGroup"
                        }
                    }
                }
                $nextitems = $responsedocs.links.next 
                if ( $nextitems) 
                {
                    Write-Log -Path $LogFileName  $("URL : {0}" -f $nextitems)        
                    $responsedocs =Invoke-RestMethod -Uri $nextitems -Headers $headers -Method Get
                }
            }while ($nextitems) 
            #>    

     
        }
        else
        {
            # if it falls here, means it is a group.
            Write-Log -Path $LogFileName  $("URL : {0}" -f $uri)        
            $responsedocs = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            $memberUsersList = Get-PnPGroupMembers -Identity $membersgroupname
            $ownerUserList = Get-PnPGroupMembers -Identity $ownersgroupname
            do 
            {
                foreach($listItem in ($responsedocs.list))
                {
                    try
                    {  
                        $personEmail = $listItem.person.emails.value 
                        if ( $listItem.state -eq 'owner' ) 
                        {
                            $alreadyAdded = $ownerUserList | Where-Object { $_.Email -ieq $personEmail }
                            if ( $alreadyAdded -eq $null )
                            {
                                Write-Log -Path $LogFileName $("Type : {0} Add {1} to {2}" -f $listItem.state,$personEmail, $ownersgroupname);
                                $fix = Add-PnPUserToGroup -LoginName $listItem.person.emails.value -Identity $Ownersgroup
                            }  
                        }
                        elseif  ( $listItem.state -eq 'member' )   
                        {
                            $alreadyAdded =  $memberUsersList | Where-Object { $_.Email -ieq $personEmail }
                            if ( $alreadyAdded -eq $null )
                            {
                                Write-Log -Path $LogFileName $("Type: {0} Add {1} to {2}" -f $listItem.state,$personEmail, $membersgroupname);
                                $fix = Add-PnPUserToGroup -LoginName $listItem.person.emails.value -Identity $membersgroup
                            }
                        }
                    }
                    catch 
                    {
                        Write-Exception2LogFile -exception $_.Exception -func2Report "Assign-Permisions in for loop"
                    }
                }
                $nextitems = $responsedocs.links.next 
                if ( $nextitems) 
                {
                    Write-Log -Path $LogFileName  $("URL : {0}" -f $nextitems)        
                    $responsedocs =Invoke-RestMethod -Uri $nextitems -Headers $headers -Method Get
                }
            }while ($nextitems)          
        }
    }
    catch 
    {
        Write-Exception2LogFile -exception $_.Exception -func2Report "Assign-Permisions"
    }
} #end of Assign-Permisions    

function Prepare-site ($placeid, $currentWeb1, $parentConn, $WebRelativePath    )
{
    try 
    {
        Write-Log -Path $LogFileName $("*Prepare site in * {0}." -f $WebRelativePath);
        $currentWeb = Get-PnPWeb $WebRelativePath -Connection $parentConn 

        $l =  New-PnPList -Title "Html Documents" -Template WebPageLibrary -Web $currentWeb -Connection $parentConn -OnQuickLaunch -ErrorAction Ignore
        $l =  New-PnPList -Title "Categories" -Template GenericList -Web $currentWeb  -Connection $parentConn -OnQuickLaunch -ErrorAction Ignore
        $l =  New-PnPList -Title "Events" -Template Events -Web $currentWeb -Connection $parentConn -OnQuickLaunch -ErrorAction Ignore
        $doclist = Get-PnPList -Identity 'Documents' -Web $currentWeb -Connection $parentConn
        if ($doclist -eq $null)
        {
            $l =  New-PnPList -Title "Documents" -Template DocumentLibrary -Web $currentWeb  -Connection $parentConn -OnQuickLaunch -Url "Shared Documents" 
            
        }     
        $categorieslist = Get-PnPList -Identity 'Categories' -Web $currentWeb -Connection $parentConn     
        $listfields = (Get-PnPField -List $doclist -Web $currentWeb -Connection $parentConn).Title
        if(!($listfields-contains("Categories")))
        {
            Write-Log -Path $LogFileName $("{0} {1}" -f $listfield.Title , $doclist.Title );
    
            $lookupColumnId = [guid]::NewGuid().Guid
            $s = '<Field Type="LookupMulti" DisplayName="Categories" Name="Categories" ShowField="Title" Mult="TRUE" EnforceUniqueValues="FALSE" Required="FALSE" ID="' + $lookupColumnId + '" RelationshipDeleteBehavior="None" List="' + $categorieslist.Id + '" />'
            $field = Add-PnPFieldFromXml -FieldXml $s  -List $doclist -Web $currentWeb -Connection $parentConn
        }
        $fields = (Get-PnpView -List $doclist -Identity "All Documents" -Web $currentWeb -Connection $parentConn).ViewFields
        if(!($fields-Contains("Categories")))
        {   
            $fields += "Categories"
            Set-PnPView -List $doclist -Identity "All Documents" -Fields $fields -Web $currentWeb -Connection $parentConn 
            Write-Log -Path $LogFileName $("{0}{1}" -f $WebRelativePath, $doclist.Title );
        }
        if ( $categorieslist.ItemCount -eq 0) 
        {
            $uri = "https://www.{{TODOYourURL}}.com/api/core/v3/places/"+$placeid+"/categories"       
            Write-Log -Path $LogFileName  $("URL : {0}" -f $uri)        
            $responsecategory = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            foreach ( $category in $responsecategory.list)
            {
                $i = Add-PnPListItem -List "Categories" -Values @{"Title" = $category.name } -Connection $parentConn -Web $currentWeb
            }
        }
    }
    catch 
    {
        Write-Exception2LogFile -exception $_.Exception -func2Report "Prepare-site"
    }
} #end of Prepare-site

function Check-InvalidChar ($file )
{
    $illegalChars = '[*&{}~#%:"\\/]'
    filter Matches($illegalChars)
    {
        $file | Select-String -AllMatches $illegalChars |
        Select-Object -ExpandProperty Matches
        Select-Object -ExpandProperty Values
    }
            
    #Replace illegal characters with legal characters where found
    $newFileName = $file
    Matches $illegalChars | ForEach-Object {
        #Write-Host  $listItem.name has the illegal character $_.Value -BackgroundColor Red 
        #Write-Log -Path $LogFileName $("{0} has the illegal character {1}" -f $listItem.name, $_.Value );
        #These characters may be used on the file system but not SharePoint
        if ($_.Value -match "&") { $newFileName = ($newFileName -replace "&", "and") }
        if ($_.Value -match "{") { $newFileName = ($newFileName -replace "{", "(") }
        if ($_.Value -match "}") { $newFileName = ($newFileName -replace "}", ")") }
        if ($_.Value -match "~") { $newFileName = ($newFileName -replace "~", "-") }
        if ($_.Value -match "#") { $newFileName = ($newFileName -replace "#", "") }
        if ($_.Value -match "%") { $newFileName = ($newFileName -replace "%", "") }
        if ($_.Value -match ":") { $newFileName = ($newFileName -replace ":", "-") }
        if ($_.Value -match "\\") { $newFileName = ($newFileName -replace "\\", "") }
        if ($_.Value -match """") { $newFileName = ($newFileName -replace """", "-") }
        if ($_.Value -match "/") { $newFileName = ($newFileName -replace "/", "") }
        #Write-Host $listItem.binaryUrl  "   "  $newFileName -ForegroundColor Green
        #Write-Log -Path $LogFileName $("{0}  {1}" -f $listItem.binaryUrl, $newFileName );
    }
    return $newFileName 
}#end of Check-InvalidChar


function Move-Contents($uri, $currentWeb2, $parentConn, $WebRelativePath    )
{
    try
    {    
        Write-Log -Path $LogFileName $("*Move Contents in * {0}." -f $WebRelativePath);
        $currentWeb = Get-PnPWeb $WebRelativePath -Connection $parentConn 
        # get contents
        #$uri = $rs1.resources.contents.ref
    
        Write-Log -Path $LogFileName  $("URL : {0}" -f $uri)        
        $responsedocs = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        $doclist = Get-PnPList -Identity 'Documents' -Web $currentWeb -Connection $parentConn
        do 
        {
            ForEach($listItem in ($responsedocs.list))
            {   
                try
                {
                                                                                                                                                                                                                                                                             
                    if ( ( $doclist -ne $null ) -and
                        ($listItem.type -eq "file") )
                    {
                        $folderPath = "Shared Documents"
                        #check Illegal Chars
                        $filename = Check-InvalidChar ($listItem.name )
                        #Check if file Exist 
                        $FileSiteRelativeURL = $("/{0}/{1}" -f $folderPath, $filename)
                        $FileExists = Get-PnPFile -Url $FileSiteRelativeURL -Web $currentWeb -ErrorAction SilentlyContinue 
                        Write-Log -Path $LogFileName $("*Check if '{0}' file exists in SPO*. If not, add it." -f $FileSiteRelativeURL);
                        if($FileExists)
                        {
                            Write-Log -Path $LogFileName $("*File Exists in SPO* {0}." -f $FileSiteRelativeURL);
                        }
                        else
                        {
                            #assume all categories
                            $catStr = Get-CategoryId -category "All Categories" -subWeb $currentWeb
                            foreach ( $category in $listItem.categories)
                            {
                                $tempCatStr = Get-CategoryId -category $category -subWeb $currentWeb
                                if ( $catStr.Length -gt 0 )
                                {
                                    $catStr = "{0},{1}" -f $catStr, $tempCatStr
                                }
                                else
                                {
                                    $catStr = "{0}" -f $tempCatStr
                                }
                            }
                            #get the file to the local disk
                            if ( $listItem.size -le  260004000)
                            {
                                Write-Log -Path $LogFileName  $("URL : {0}" -f $listItem.binaryUrl)        
                                $response = Invoke-RestMethod -Uri $listItem.binaryUrl -Headers $headers -Method Get
                     
                                $stream = New-Object -TypeName System.IO.MemoryStream($response.ToCharArray().Length)
                                $stream.Write($response.ToCharArray(),0,$response.ToCharArray().Length)
                                $stream.Seek(0, [System.IO.SeekOrigin]::Begin)
                                #Use Platting
                                $params = @{
                                    "Stream"     = $stream;
                                    "FileName"   = $filename;
                                    "Folder"     = $folderPath;
                                    "Connection" = $parentConn;
                                    "Web"        = $currentWeb;
                                }
                                $valuesParams = @{
                                    "Categories"      = $catStr; 
                                    "Title"           = $listItem.name; 
                                    "Author"          = $listItem.author.emails[0].value;
                                    "Editor"          = $listItem.author.emails[0].value;  
                                    'Created'         = [datetime]$listItem.published;
                                }
                                try
                                {
                                    $f = Add-PnPFile @params -Values $valuesParams
                                    Write-Log -Path $LogFileName $("**File added in SPO** {0}." -f $FileSiteRelativeURL);
                                }
                                catch 
                                {
                                    Write-Exception2LogFile -exception $_.Exception -func2Report "Move-Contents Add-PnPFile failed"
                                }

                            }
                            else 
                            {
                                Write-Log -Path $LogFileName $("**~File TooLarge in size~** {0} size{1}." -f $FileSiteRelativeURL, $listItem.size );
                            }
                        }
                    }
                    #TODO
                    if($listItem.type -eq "event")
                    {
                        $bodyContent = Fix-BodyContent -bodyContent $listItem.content.text
                        $params = @{
                            "Title" = $listItem.subject; 
                            "Category"=$listItem.eventType; 
                            "EventDate" = $listItem.startDate; 
                            "EndDate" = $listItem.endDate ; 
                            "Description"= $bodyContent
                        } 
                        $e =  Add-PnPListItem -List "Event" -Values $params -Connection $parentConn -Web $currentWeb 
                    }
                    #TODO
                    if($listItem.type -eq "document")
                    {
                        $filename = Check-InvalidChar ($listItem.subject )
                        $PageRelativeURL= $WebRelativePath + "/"+ "Html Documents" + "/"+ $filename +".aspx"
                        # fix anchors hrefs
                        $bodyContent = Fix-BodyContent -bodyContent $listItem.content.text
                        $wikiFileExists = Get-PnPFile -Url $PageRelativeURL -ErrorAction SilentlyContinue
                        if($wikiFileExists)
                        {
                            Write-Log -Path $LogFileName $("*Wiki File Exists in SPO* {0}." -f $PageRelativeURL);
                        }
                        else
                        {
                            $w = Add-PnPWikiPage -ServerRelativePageUrl $PageRelativeURL -Content $bodyContent -Connection $parentConn -Web $WebRelativePath 
                            Write-Log -Path $LogFileName $("**Wiki File added in SPO** {0}." -f $PageRelativeURL);
                        }
                    }
                }
                catch 
                {
                    Write-Exception2LogFile -exception $_.Exception -func2Report "Move-Contents inner For loop"
                }
            } # end of for

            #get next 26 items 
            $nextitems = $responsedocs.links.next 
            if ( $nextitems) 
            {
                Write-Log -Path $LogFileName  $("URL : {0}" -f $nextitems)        
                $responsedocs =Invoke-RestMethod -Uri $nextitems -Headers $headers -Method Get
            }


        } while ( $nextitems) 
    } # end of try
    catch 
    {
        Write-Exception2LogFile -exception $_.Exception -func2Report "Move-Contents"
    }
} #end of Move-Contents

function Fix-BodyContent([string]$bodyContent)
{
    $localbodyContent = $bodyContent

    $localbodyContent = $localbodyContent.Replace("https://www.{{TODOYourURL}}.com/external-link.jspa?url=", "")
    $localbodyContent = $localbodyContent.Replace("%3A%2F%2F", "://")
    $localbodyContent = $localbodyContent.Replace("%2F", "/")

    return $localbodyContent

}
function Get-CategoryId([string]$category, $subWeb)
{
    $query = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>{0}</Value></Eq></Where></Query></View>" -f $category
    $foundCategory = Get-PnPListItem -List 'Categories'  -Query $query -Connection $parentConn -Web $subWeb 
    if ( $foundCategory -eq $null )
    {
        $foundCategory = Add-PnPListItem -List "Categories" -Values @{"Title" = $category } -Web $subWeb
    }
    return $foundCategory.Id
}

function Create-BlogPosts([string]$urlForPosts, $blogSubWeb) 
{
    try
    {
        $keepLooping = $true
        while ( $keepLooping -eq $true )
        {
            Write-Log -Path $LogFileName  $("URL : {0}" -f $urlForPosts)        
            # the contents are found now get the post contents - content.ref tells number of blogs
            $blogpostres = Invoke-RestMethod  -Uri  $urlForPosts -Headers $headers -Method Get -Verbose 
            ForEach($blogListItem in ($blogpostres.list))
            {
                if ( $blogListItem.type -eq 'post')
                {
                    #check if the post is already there
                    $query = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>{0}</Value></Eq></Where></Query></View>" -f $blogListItem.subject
                    $foundPost = Get-PnPListItem -List 'Posts' -Query $query -Connection $parentConn -Web $blogSubWeb
                    if ( $foundPost -eq $null )
                    {
                        #assume all category
                        $catStr = Get-CategoryId -category "All Categories" -subWeb $blogSubWeb
                        foreach ( $category in $blogListItem.categories)
                        {
                            $tempCatStr = Get-CategoryId -category $category -subWeb $blogSubWeb
                            if ( $catStr.Length -gt 0 )
                            {
                                $catStr = "{0},{1}" -f $catStr, $tempCatStr
                            }
                            else
                            {
                                $catStr = "{0}" -f $tempCatStr
                            }

                        }
                        # fix anchors hrefs
                        $bodyContent = Fix-BodyContent -bodyContent $blogListItem.content.text

                        if ( $catStr.Length -gt 0 )
                        {
                            $params = @{
                                "Title"           = $blogListItem.subject;
                                "Body"            = $bodyContent;
                                'PublishedDate'   = [datetime]$blogListItem.published;
                                'Author'          = $blogListItem.author.emails[0].value;
                                'Editor'          = $blogListItem.author.emails[0].value;
                                'PostCategory'    = $catStr ;
                            }
                        }
                        else
                        {
                            # no category
                            $params = @{
                                "Title"           = $blogListItem.subject;
                                "Body"            = $bodyContent;
                                'PublishedDate'   = [datetime]$blogListItem.published;
                                'Author'          = $blogListItem.author.emails[0].value;
                                'Editor'          = $blogListItem.author.emails[0].value;
                            }
                        }
                        # now use the subject and body to add the post
                        Write-Log -Path $LogFileName  $("Post subject: {0}" -f $blogListItem.subject)
                        try
                        {
                            $fix1 = Add-PnPListItem -List "Posts" -Values $params -Web $blogSubWeb
                        }
                        catch 
                        {
                            # assume the excetion is 'The specified user xx.yy@va.gov could not be found.'
                            # now try without Author and Editor
                            Write-Exception2LogFile -exception $_.Exception -func2Report "Create-BlogPosts"

                            $params.Remove('Author')
                            $params.Remove('Editor')


                            $fix1 = Add-PnPListItem -List "Posts" -Values $params -Web $blogSubWeb

                        }
                    }
                    else
                    {
                        Write-Log -Path $LogFileName $("Found Post with subject: {0}" -f $blogListItem.subject)
                    }
                }
            }

            if ( $blogpostres.links.next -ne $null)
            {
                $urlForPosts = $blogpostres.links.next
            }
            else
            {
                $keepLooping = $false
            }
        }
    }
    catch 
    {
        Write-Exception2LogFile -exception $_.Exception -func2Report "Create-BlogPosts"
    }
} #end of Create-BlogPosts

function Get-PlacesById([string]$placeId, [string]$parentPlaceId, $parentWebUrlParam , $org )
{
    try
    {    
        # first get information about the place using place ID
        $rs1 = Get-PlaceById -placeId $placeId

        # check if site collection exist 
        # check id the place Id has the parent place id as blank
        # if yes create this place as a site collection.

        if ( ( $parentPlaceId.Trim().Length -eq 0 ) -and
            (( $rs1.type  -eq "group" ) -or ( $rs1.type  -eq "space" )) 
           )
        {
            # create a site collection and 
            $sitecollectionURL =  $org + $rs1.displayName
            $parentWebUrl = "/sites/"+$sitecollectionURL
            $parentWeb = "https://{{TODO-YOURTENANTNAME}}.sharepoint.com" + $parentWebUrl
            Write-Log -Path $LogFileName $("Source: {0} Target: {1}" -f $rs1.resources.html.ref, $parentWeb);
            try
            {
                $createSiteFlag = $true

                #Use splatting
                $params = @{
                    'Description'     = $rs1.description;
                    'Title'           = $rs1.name;
                    'Connection'      = $connAdmin;
                }
                if ( $rs1.type  -eq "group" )
                {
                    $params.Add('Type','TeamSite')
                    $params.Add('Alias',$sitecollectionURL)

                    $groupId = Get-PnPUnifiedGroup -Identity $sitecollectionURL
                    if ( $groupId -ne $null )
                    {
                        $createSiteFlag = $false
                    }
                }
                if ( $rs1.type  -eq "space" )
                {
                    $params.Add('Type','CommunicationSite')
                    $params.Add('Url', $parentWeb)
                }
                if ( $createSiteFlag -eq $true )
                {
                    $parentUrlStr = New-PnPSite @params -Verbose -ErrorAction Stop -WarningAction Stop
                    Write-Log -Path $LogFileName $("Created {0} site collection" -f $parentWeb);
                }
            }
            catch
            {
                Write-Exception2LogFile -exception $_.Exception -func2Report "Get-PlacesById"
                # assume the site is created
                Write-Log -Path $LogFileName  $("Connecting to an exiting site {0}" -f $parentWeb);
            }
            finally
            {
                # get the connection for the new site
                $parentConn = Connect-PnPOnline -ReturnConnection -Url $parentWeb  -UseWebLogin
            }
            
            $localscaOwners = New-Object System.Collections.Generic.List[System.String]
            $existingSCAs = Get-PnPSiteCollectionAdmin -Connection $parentConn | Select-Object Email 
            foreach ($scaUser in $scaOwners)
            {
                $scaExistFlag = $existingSCAs | Where-Object { $_.Email -ieq $scaUser }
                if ( $scaExistFlag -eq $flase )
                {
                    $localscaOwners.Add($scaUser)
                }
            }
            if ( $localscaOwners.Count -gt 0 )
            {
                $fix = Add-PnPSiteCollectionAdmin -Owners $localscaOwners -Connection $parentConn
            }

            #Get-AvatarByPlaceId -placeId $placeId -logoName $rs1.displayName
            
            if ( $rs1.type  -eq "group" )
            {
                $membersURI = $("{0}/members/places/{1}" -f $hosturi, $placeId)
            }
            if ( $rs1.type  -eq "space" )
            {
                $membersURI = $("{0}/places/{1}/appliedEntitlements" -f $hosturi, $placeId)
            }

            # check for the global flag before calling o365 groups
            if ( $g_AddUser2O365GroupsFlag -eq $true )
            {
                Assign-Permisions2O365Groups -uri $membersURI -placeId $placeId -parentConn $parentConn -WebRelativePath $parentWebUrl 
            }

            # check for the global flag before calling add users to SPO groups
            if ( $g_AddUser2SPOGroupsFlag -eq $true )
            {
                Assign-Permisions -uri $membersURI -placeId $placeId -parentConn $parentConn -WebRelativePath $parentWebUrl 
            }

            # check for the global flag before calling move content
            if ( $g_MoveContentFlag -eq $true )
            {
                Prepare-site -placeid $rs1.placeid -parentConn $parentConn -WebRelativePath $parentWebUrl 
                Move-Contents -uri $rs1.resources.contents.ref  -parentConn $parentConn -WebRelativePath $parentWebUrl  
            }
        }
        else
        {
            # create a sub site
            $parentWebUrl = $parentWebUrlParam
        }
        if ( $g_ProcessSubPlacesFlag -eq $true )
        {
            Write-Log -Path $LogFileName  $("URL : {0}/places/{1}/places" -f $hosturi, $placeId)        
            $response = Invoke-RestMethod -Uri $hosturi"/places/"$placeId"/places" -Headers $headers -Method Get
            foreach ($item in $response.list)
            {
                #Get-AvatarByPlaceId -placeId $item.placeId -logoName $item.displayName
                #Write-Host $item.type + " " + $item.childCount
                if ($item.type -contains "project")
                {
                    $rs1 = Get-PlaceById -placeId $item.placeID

                    if ($item.childCount -gt 0)
                    {
                        $tempParentWebUrl = $parentWebUrl + "/" + $item.displayName
                        # first assum the sub site is present, if not then create it
                        try
                        {
                            Write-Log -Path $LogFileName  $("Connecting to an exiting site {0} " -f $item.displayName);
                            $s = Get-PnPWeb -Identity $item.displayName
                        }
                        catch
                        {
                            Write-Log -Path $LogFileName $("Create subsite '{0}' under {1}" -f $item.name, $parentWebUrl)
                            #Use splatting
                            $params = @{
                                'Title'         = $item.name;
                                'Url'           = $item.displayName;
                                'Template'      = 'STS#0';
                                'Description'   = $item.description;
                                'Connection'    = $parentConn;
                            }
                    
                            $s = New-PnPWeb @params -Verbose 
                        }                                                 
                        # check for the global flag before calling move content
                        if ( $g_MoveContentFlag -eq $true )
                        {
                            Prepare-site -placeid $rs1.placeid  -parentConn $parentConn -WebRelativePath $tempParentWebUrl
                            Move-Contents -uri $rs1.resources.contents.ref  -parentConn $parentConn -WebRelativePath $tempParentWebUrl      
                        }                    
                        # Get-PlacesById -placeId $item.placeID -parentWebUrlParam $tempParentWebUrl
                    }
                    else
                    {
                        $tempParentWebUrl = $parentWebUrl + "/" + $item.displayName

                        # first assum the sub site is present, if not then create it
                        try
                        {
                            Write-Log -Path $LogFileName  $("Try connecting to an exiting site {0} " -f $item.displayName);
                            $s = Get-PnPWeb -Identity $item.displayName
                        }
                        catch
                        {
                            try
                            {
                                Write-Log -Path $LogFileName $("Create subsite '{0}' under {1}" -f $item.name, $parentWebUr)
                                #Use splatting
                                $params = @{
                                    'Title'         = $item.name;
                                    'Url'           = $item.displayName;
                                    'Template'      = 'STS#0';
                                    'Description'   = $item.description;
                                    'Web'           = $parentWebUrl;
                                    'Connection'    = $parentConn;
                                }

                                $s = New-PnPWeb @params -Verbose
                            }
                            catch
                            {
                                Write-Exception2LogFile -exception $_.Exception -func2Report "Get-PlacesById"
                            }
                            finally
                            {
                                Write-Log -Path $LogFileName  $("Connecting to an exiting site {0} under {1}" -f $nameUrl, $tempParentWebUrl);
                                $s = Get-PnPWeb -Identity $tempParentWebUrl
                            }
                        }
                        # check for the global flag before calling move content
                        if ( $g_MoveContentFlag -eq $true )
                        {
                            Prepare-site -placeid $rs1.placeid -currentWeb $parentConn -WebRelativePath $tempParentWebUrl
                            Move-Contents -uri $rs1.resources.contents.ref  -parentConn $parentConn -WebRelativePath $tempParentWebUrl
                        }
                    }
                }

                if ( ( $g_MoveBlogsFlag -eq $true ) -and 
                    ($item.type -contains "blog") )
                {
                    $tempParentWebUrl = $parentWebUrl + "/" + $item.displayName

                    # the ref is in the following format
                    # need to extract xxxxxx
                    # https://www.{{TODOYourURL}}.com/community/xxxxxx/blog
                    $tempUrl = $item.resources.html.ref
                    $tempArr = $tempUrl.Split('/')
                    $nameUrl = $item.name
                    if ( $tempArr.Length -gt 0 )
                    {
                        $nameUrl = $tempArr[$tempArr.Length-2]
                        $nameUrl = $nameUrl + "Blog"
                    }

                    $tempParentWebUrl = $parentWebUrl + "/" + $nameUrl

                    # first assume the sub site is present, if not then create it
                    try
                    {
                        Write-Log -Path $LogFileName  $("Try connecting to an exiting site {0} under {1}" -f $nameUrl, $parentWebUrl);
                        $s = Get-PnPWeb -Identity $tempParentWebUrl
                    }
                    catch
                    {
                        Write-Log -Path $LogFileName $("Create subsite '{0}' under {1}" -f $nameUrl, $tempParentWebUrl)
                        try
                        {
                            #Use splatting
                            $params = @{
                                'Title'         = $item.name;
                                'Url'           = $nameUrl;
                                'Description'   = $item.description;
                                'Template'      = 'BLOG#0';
                                'Local'         = 1033;
                                'Web'           = $parentWebUrl;
                                'Connection'    = $parentConn;
                            }
                            $s = New-PnPWeb @params -ErrorAction Stop
                        }
                        catch
                        {
                            Write-Exception2LogFile -exception $_.Exception -func2Report "Get-PlacesById"
                        }
                        finally
                        {
                            Write-Log -Path $LogFileName  $("Connecting to an exiting site {0} under {1}" -f $nameUrl, $tempParentWebUrl);
                            $s = Get-PnPWeb -Identity $tempParentWebUrl
                        }
                    }
                    Create-BlogPosts -urlForPosts $item.resources.contents.ref -blogSubWeb $s
                }
                if ($item.type -contains "space")
                {
                    $rs1 = Get-PlaceById -placeId $item.placeID

                    if ($item.childCount -gt 0)
                    {
                        $tempParentWebUrl = $parentWebUrl + "/" + $item.displayName
                        # first assum the sub site is present, if not then create it
                        try
                        {
                            Write-Log -Path $LogFileName  $("Try connecting to an exiting site {0} under {1}" -f $nameUrl, $tempParentWebUrl);
                            $s = Get-PnPWeb  -Identity $tempParentWebUrl
                        }
                        catch
                        {
                            Write-Log -Path $LogFileName $("Create subsite {0} under {1}" -f $nameUrl, $tempParentWebUrl)
                            try
                            {
                                #Use splatting
                                $params = @{
                                    'Title'         = $item.name;
                                    'Url'           = $item.displayname;
                                    'Web'           = $parentWebUrl;
                                    'Template'      = 'STS#0';
                                    'Description'   = $item.description;
                                    'Local'         = 1033;
                                    'Connection'    = $parentConn;
                                }
                                $s = New-PnPWeb @params -ErrorAction Stop
                            }
                            catch
                            {
                                Write-Exception2LogFile -exception $_.Exception -func2Report "Get-PlacesById"
                            }
                            finally
                            {
                                Write-Log -Path $LogFileName  $("Connecting to an exiting site {0} under {1}" -f $item.displayname, $tempParentWebUrl);
                                $s = Get-PnPWeb  -Identity $tempParentWebUrl
                            }
                        }
                        # check for the global flag before calling move content
                        if ( $g_MoveContentFlag -eq $true )
                        {
                            Prepare-site -placeid $rs1.placeid  -parentConn $parentConn -WebRelativePath $tempParentWebUrl
                            Move-Contents -uri $rs1.resources.contents.ref  -parentConn $parentConn -WebRelativePath $tempParentWebUrl      
                        }
                        Get-PlacesById -placeId $item.placeID -parentPlaceId $item.parent -parentWebUrlParam $tempParentWebUrl
                    }
                    else
                    {
                        $tempParentWebUrl = $parentWebUrl + "/" + $item.displayName

                        # first assum the sub site is present, if not then create it
                        try
                        {
                            Write-Log -Path $LogFileName  $("Try connecting to an exiting site {0} under {1}" -f $item.name, $tempParentWebUrl);
                            $s = Get-PnPWeb  -Identity $tempParentWebUrl
                        }
                        catch
                        {
                            Write-Log -Path $LogFileName $("Create subsite {0} under {1}" -f $item.name, $tempParentWebUrl)
                            try
                            {
                                #Use splatting
                                $params = @{
                                    'Title'         = $item.name;
                                    'Url'           = $item.displayname;
                                    'Web'           = $parentWebUrl;
                                    'Template'      = 'STS#0';
                                    'Description'   = $item.description;
                                    'Local'         = 1033;
                                    'Connection'    = $parentConn;
                                }
                                $s = New-PnPWeb @params -ErrorAction Stop
                            }
                            catch
                            {
                                Write-Exception2LogFile -exception $_.Exception -func2Report "Get-PlacesById"
                            }
                            finally
                            {
                                Write-Log -Path $LogFileName  $("Connecting to an exiting site {0} under {1}" -f $item.name, $tempParentWebUrl);
                                $s = Get-PnPWeb  -Identity $tempParentWebUrl
                            }
                        }
                        # check for the global flag before calling move content
                        if ( $g_MoveContentFlag -eq $true )
                        {
                            Prepare-site -placeid $rs1.placeid -currentWeb $parentConn -WebRelativePath $tempParentWebUrl
                            Move-Contents -uri $rs1.resources.contents.ref  -parentConn $parentConn -WebRelativePath $tempParentWebUrl
                        }
                    }
                }
            }
        }
    }
    catch 
    {
        Write-Exception2LogFile -exception $_.Exception -func2Report "Get-PlacesById"
    }
} # end of Get-PlacesById

function Migrate-JivePlace([string]$placeId, $pulseHostUri, $headers , $psScriptRoot, $connAdmin)  
{
    $org = 'vha'   
    $sitePlaceid = $placeId  
    #$LogFileName = $("E:\LogFiles\Log-{0}-{1}.txt" -f $sitePlaceid , (Get-Date -Format "yyyy-MM-dd HHmm"))

    $LogFolderPath = $("{0}\LogFiles\{1}" -f $psScriptRoot, (Get-Date -Format "MM-dd-yy"))
    $LogFileName = $("{0}\Log-{1}-{2}.txt" -f $LogFolderPath, $sitePlaceid , (Get-Date -Format "HH_mm_ss"))
    if( -not ( Test-Path -Path $LogFolderPath ) )
    {
        # create directory
        New-Item -ItemType Directory -Force -Path $LogFolderPath
    }

    $startTime = Get-Date
    Write-Log -Path $LogFileName " *************************************** Start  *************************************** "
    Write-Log -Path $LogFileName $("Script Start Time: {0} " -f $startTime);

    try
    {
        #get only type 
        $rs1 = Get-PlaceById -placeId $sitePlaceid -fields "-resources,type"

        if ( ( $rs1.type  -eq "group" ) -or
            ( $rs1.type  -eq "space" ) )
        {
            # 
            Get-PlacesById -placeId $sitePlaceid -parentPlaceId "" -org $org
        }
        else
        {
            Write-Log -Path $LogFileName $("The place id {0} is of type = '{1}'." -f $sitePlaceid, $rs1.type);
            Write-Log -Path $LogFileName $("Only of type 'space' or 'group' must be present." -f $sitePlaceid, $rs1.type);
        }
    }
    catch 
    {
        Write-Exception2LogFile -exception $_.Exception -func2Report "Migrate-JivePlace"
    }


    $enddatetime = Get-Date
    $timeDiff = $enddatetime - $startTime

    Write-Log -Path $LogFileName $("Script ran for {0} seconds." -f $timeDiff.TotalSeconds);
    Write-Log -Path $LogFileName $("Script ran for {0} minutes." -f $timeDiff.TotalMinutes);
    Write-Log -Path $LogFileName $("Script End Time: {0} " -f $enddatetime);
    Write-Log -Path $LogFileName " *************************************** End    *************************************** "

}




#VHA3DP