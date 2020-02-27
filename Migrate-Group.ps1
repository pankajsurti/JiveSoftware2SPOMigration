Clear-Host 

add-type -assemblyName "System.Collections"
get-date
$LogFileName = "" #make as global 
$hosturi = "" #make as global 
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" #make as global

$connAdmin = Connect-PnPOnline -Url https://dvagov-admin.sharepoint.com -ReturnConnection -UseWebLogin


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
        #Write-Output  $message 
        #Write-Host  $message 
        #$host.UI.RawUI.ForegroundColor = $savedColor
    }
    End
    {
    }
}


function Get-PlaceById([string]$placeId) 
{
    $response = Invoke-RestMethod -Uri $hosturi"/places/"$placeId -Headers $headers -Method Get
    return $response
}

function assign-permisions ($uri, $parentConn, $WebRelativePath    )
{
    $currentWeb = Get-PnPWeb $WebRelativePath -Connection $parentConn 
    $ownersgroupname = $currentWeb.Title +' Owners'
    $membersgroupname = $currentWeb.Title +' Members'
    $groupname 
    $Ownersgroup = Get-PnPGroup -Identity $ownersgroupname -Connection $parentConn -Web $currentWeb 
    $membersgroup = Get-PnPGroup -Identity $membersgroupname -Connection $parentConn -Web $currentWeb 
    $g 

    $responsedocs = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    do 
    {
        foreach($listItem in ($responsedocs.list))
        {         
            if ( $listItem.state -eq 'owner' ) 
            {
                #write-host $listItem.state  "   " $listItem.person.emails.value
                Write-Log -Path $LogFileName $("{0} {1}" -f $listItem.state,$listItem.person.emails.value);
                Add-PnPUserToGroup -LoginName $listItem.person.emails.value -Identity $Ownersgroup  
            }
            elseif  ( $listItem.state -eq 'memberrrrrr' )   # change memberrrrrr to member
            {
                #write-host $listItem.state  "   " $listItem.person.emails.value
                Write-Log -Path $LogFileName $("{0} {1}" -f $listItem.state,$listItem.person.emails.value);
                Add-PnPUserToGroup -LoginName $listItem.person.emails.value -Identity $membersgroup
                   
            }
        }
        $nextitems = $responsedocs.links.next 
        if ( $nextitems) 
        {
            $responsedocs =Invoke-RestMethod -Uri $nextitems -Headers $headers -Method Get
        
        }
    }while ($nextitems)          
}    


function Prepare-site ($placeid, $currentWeb1, $parentConn, $WebRelativePath    )
{

    $currentWeb = Get-PnPWeb $WebRelativePath -Connection $parentConn 

    $l =  New-PnPList -Title "Html Documents" -Template WebPageLibrary -Web $currentWeb -Connection $parentConn -OnQuickLaunch -ErrorAction Ignore
    $l =  New-PnPList -Title "Categories" -Template GenericList -Web $currentWeb  -Connection $parentConn -OnQuickLaunch -ErrorAction Ignore
    $l =  New-PnPList -Title "Events" -Template Events -Web $currentWeb -Connection $parentConn -OnQuickLaunch -ErrorAction Ignore

    $doclist = Get-PnPList -Identity 'Documents' -Web $currentWeb -Connection $parentConn    
    $categorieslist = Get-PnPList -Identity 'Categories' -Web $currentWeb -Connection $parentConn     
    $listfields = (Get-PnPField -List $doclist -Web $currentWeb -Connection $parentConn).Title

    if(!($listfields-contains("Categories")))
    {
        #Write-Host -ForegroundColor green  $listfield.Title "   " $doclist.Title    
        Write-Log -Path $LogFileName $("{0} {1}" -f $listfield.Title , $doclist.Title );
    
        $lookupColumnId = [guid]::NewGuid().Guid
        $s = '<Field Type="LookupMulti" DisplayName="Categories" Name="Categories" ShowField="Title" Mult="TRUE" EnforceUniqueValues="FALSE" Required="FALSE" ID="' + $lookupColumnId + '" RelationshipDeleteBehavior="None" List="' + $categorieslist.Id + '" />'
        $field = Add-PnPFieldFromXml -FieldXml $s  -List $doclist -Web $currentWeb -Connection $parentConn
    }

    else 
    {
        #Write-Host -ForegroundColor red  $listfield.Title "   " $doclist.id 
        Write-Log -Path $LogFileName $("{0} {1}" -f $listfield.Title , $doclist.id );

        #Remove-PnPField -List $doclist "Categories"   -Force -Web $currentWeb 

    }
   
    $fields = (Get-PnpView -List $doclist -Identity "All Documents" -Web $currentWeb -Connection $parentConn).ViewFields
    if(!($fields-Contains("Categories")))
       
    {   
        $fields += "Categories"
        Set-PnPView -List $doclist -Identity "All Documents" -Fields $fields -Web $currentWeb -Connection $parentConn 
        #Write-Host $WebRelativePath -ForegroundColor Cyan  
        Write-Log -Path $LogFileName $("{0}{1}" -f $WebRelativePath, $doclist.Title );
    }
   
   
   if ( $categorieslist.ItemCount -eq 0) 
   {
       $uri = "https://www.vapulse.va.gov/api/core/v3/places/"+$placeid+"/categories"       
       $responsecategory = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
       foreach ( $category in $responsecategory.list)
       {
   
            $i = Add-PnPListItem -List "Categories" -Values @{"Title" = $category.name } -Connection $parentConn -Web $currentWeb
   
       }
   
    }
  
}

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
}


function Move-Contents($uri, $currentWeb2, $parentConn, $WebRelativePath    )
{
    
     $currentWeb = Get-PnPWeb $WebRelativePath -Connection $parentConn 
    # get contents
    #$uri = $rs1.resources.contents.ref
    
    $responsedocs = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    do {
        ForEach($listItem in ($responsedocs.list))
        {                                                                                                                                                                                                                                                                    
            if($listItem.type -eq "file")
            {
                #check Illegal Chars
                $filename = Check-InvalidChar ($listItem.name )
                #Check if file Exist 
                $FileSiteRelativeURL = "/Shared Documents/"+$filename  
                $FileExists = Get-PnPFile -Url $FileSiteRelativeURL -ErrorAction SilentlyContinue
                if($FileExists)
                {
                    #Write-host -f Green "File Exists!"   
                    Write-Log -Path $LogFileName $("*File Exists in SPO* {0}." -f $FileSiteRelativeURL);
                }
                else
                {
                    $catStr = "" #empty
                    foreach ( $category in $listItem.categories)
                    {
                        $query = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>{0}</Value></Eq></Where></Query></View>" -f $category
                        $foundCategory = Get-PnPListItem -List 'Categories'  -Query $query -Connection $parentConn -Web $currentWeb
                        if ( $foundCategory -eq $null )
                        {
                            $foundCategory = Add-PnPListItem -List "Categories" -Values @{"Title" = $category } -Connection $parentConn -Web $currentWeb
                        }
                        #$categorieslist.Add($foundCategory.Id)
                        if ( $catStr.Length -gt 0 )
                        {
                            $catStr = "{0},{1}" -f $catStr, $foundCategory.Id
                        }
                        else
                        {
                            $catStr = "{0}" -f $foundCategory.Id
                        }
                    }
                    #$query = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>"+ $listItem.categories +"</Value></Eq></Where></Query></View>"
                    #$ListItem1 = Get-PnPListItem -List 'Categories'  -Query $query -Connection $parentConn -Web $currentWeb

                    #get the file to the local disk
                    if ( $listItem.size -le  260004000)
                    {
                        $response = Invoke-RestMethod -Uri $listItem.binaryUrl -Headers $headers -Method Get
                        $aFileName = 'E:/developer/' + $filename 
                        [io.file]::WriteAllBytes($aFileName,$response.ToCharArray())
                        #$currentWeb = Get-PnPWeb -Connection $parentConn
                        #Upload Logo File
                        #Use Platting
                        $params = @{
                            "Path" = $aFileName;
                            "Folder" = "Shared Documents";
                            "Connection" = $parentConn;
                            "Web" = $currentWeb;
                        }
                        $valuesParams = @{
                            "Categories" = $catStr; 
                            "Title" = $listItem.name; 
                            "Author"=$listItem.author.emails[0].value;
                            "Editor"=$listItem.author.emails[0].value;  
                        }
                        $f = Add-PnPFile @params -Values $valuesParams
                        # Now the file is added to the SPO, delete from the local folder
                        Remove-Item $aFileName
                        #Write-host -f Green "File Exists!"   
                        Write-Log -Path $LogFileName $("**File added in SPO** {0}." -f $FileSiteRelativeURL);
                    }
                    else 
                    {
                        Write-Log -Path $LogFileName $("**~File TooLarge in size~** {0} size{1}." -f $FileSiteRelativeURL, $listItem.size );
                        #Write-host -f Yellow "****************File TooLarge************************" $listItem.name
                    }
                }
            }
            #TODO
            if($listItem.type -eq "event")
            {

                $e =  Add-PnPListItem -List "Event" -Values @{"Title" = $listItem.subject; "Category"=$listItem.eventType; "EventDate" = $listItem.startDate; "EndDate" = $listItem.endDate ; "Description"= $listItem.content.text} -Connection $parentConn -Web $currentWeb
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
                    #Write-host -f Green "File Exists!"   
                    Write-Log -Path $LogFileName $("*Wiki File Exists in SPO* {0}." -f $PageRelativeURL);
                }
                else
                {
                    $w = Add-PnPWikiPage -ServerRelativePageUrl $PageRelativeURL -Content $bodyContent -Connection $parentConn -Web $WebRelativePath 
                    Write-Log -Path $LogFileName $("**Wiki File added in SPO** {0}." -f $PageRelativeURL);
                }
            }
    }
        
        
    #get next 26 items 
    $nextitems = $responsedocs.links.next 
    if ( $nextitems) {
        $responsedocs =Invoke-RestMethod -Uri $nextitems -Headers $headers -Method Get
        }
    
    }while ( $nextitems) 



}

function Fix-BodyContent([string]$bodyContent)
{
    $localbodyContent = $bodyContent

    $localbodyContent = $localbodyContent.Replace("https://www.vapulse.va.gov/external-link.jspa?url=", "")
    $localbodyContent = $localbodyContent.Replace("%3A%2F%2F", "://")
    $localbodyContent = $localbodyContent.Replace("%2F", "/")

    return $localbodyContent

}


function Create-BlogPosts([string]$urlForPosts, $blogSubWeb) 
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
                    $catStr = "" #empty
                    foreach ( $category in $blogListItem.categories)
                    {

                        $query = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>{0}</Value></Eq></Where></Query></View>" -f $category
                        $foundCategory = Get-PnPListItem -List 'Categories'  -Query $query -Connection $parentConn -Web $blogSubWeb 
                        if ( $foundCategory -eq $null )
                        {
                            $foundCategory = Add-PnPListItem -List "Categories" -Values @{"Title" = $category } -Web $blogSubWeb
                        }
                        if ( $catStr.Length -gt 0 )
                        {
                            $catStr = "{0},{1}" -f $catStr, $foundCategory.Id
                        }
                        else
                        {
                            $catStr = "{0}" -f $foundCategory.Id
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
                    Write-Log -Path $LogFileName  $("Post subject: {0}..." -f $blogListItem.subject)
                    #Write-Host $("Post subject: {0}..." -f $blogListItem.subject)
                    try{
                        $fix1 = Add-PnPListItem -List "Posts" -Values $params -Web $blogSubWeb
                    }
                    catch {
                        Write-Host "Error in Add-PnPListItem -List 'Posts'"
                    }
                }
                else
                {
                    Write-Log -Path $LogFileName $("Found Post with subject: {0}..." -f $blogListItem.subject)
                    #Write-Host $("Found Post with subject: {0}..." -f $blogListItem.subject)
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

function Get-PlacesById([string]$placeId, [string]$parentPlaceId, $parentWebUrlParam , $org) {

    # first get information about the place using place ID
    $rs1 = Get-PlaceById -placeId $placeId

    # check if site collection exist 
    
   
 
        # check id the place Id has the parent place id as 1001
        # if yes create this place as a site collection.

    if ( $rs1.type  -eq "group" )
    {
        # create a site collection and 
        $sitecollectionURL =  $org + $rs1.displayName
        $parentWebUrl = "/sites/"+$sitecollectionURL
        $parentWeb = "https://dvagov.sharepoint.com" + $parentWebUrl
            
        #write-host $parentWebUrl    -f green
        #write-host $parentWeb    -f green
        Write-Log -Path $LogFileName $("{0} {1} " -f $parentWebUrl, $parentWeb);

        $GlobalSCAAdminsSID = "c:0t.c|tenant|678699a0-0c14-429e-8867-6f63bddd2309"

        try
        {
            #Use splatting
            $params = @{
                'Type'            = 'TeamSite';
                'Alias'           = $sitecollectionURL;
                'Description'     = $rs1.description;
                'Title'           = $rs1.name;
                'Owner'           = $GlobalSCAAdminsSID;
                'Connection'      = $connAdmin;
            }
            #$p = New-PnPSite -Type TeamSite -Alias $sitecollectionURL -Description $rs1.description -Title $rs1.name -Owner $GlobalSCAAdminsSID -Connection $connAdmin -Verbose
            $p = New-PnPSite @params -Verbose -ErrorAction Stop
            #Write-Host " *** Create " $parentWebName " site collection ***"
            Write-Log -Path $LogFileName $("Created {0} site collection" -f $parentWebName);
        }
        catch
        {
            # assume the site is created
            Write-Log -Path $LogFileName  $("Connecting to {0}..." -f $parentWeb);
            $parentConn = Connect-PnPOnline -ReturnConnection -Url $parentWeb  -UseWebLogin
        }

        Add-PnPSiteCollectionAdmin -Owners @("Cameron.Cotten@va.gov","Nathaniel.Merwin@va.gov","Stacy.Washington@va.go","pankaj.surti@va.gov", "Michael.gurson@va.gov", "diana.alexander@va.gov") -Connection $parentConn

        #Get-AvatarByPlaceId -placeId $placeId -logoName $rs1.displayName

        #$currentWeb = Get-PnPWeb -Connection $parentConn

        #assign-permisions -uri $uri  -parentConn $parentConn -WebRelativePath $parentWebUrl 

        Prepare-site -placeid $rs1.placeid -parentConn $parentConn -WebRelativePath $parentWebUrl 
        Move-Contents -uri $rs1.resources.contents.ref  -parentConn $parentConn -WebRelativePath $parentWebUrl  
    }
    else
    {
        # create a sub site
        $parentWebUrl = $parentWebUrlParam
        #Write-Host "  Create subsite " $rs1.name " under " $parentWebName 
    }

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
                #Write-Host "  Create subsite " $item.name " under " $parentWebUrl
                Write-Log -Path $LogFileName $("  Create subsite {0} under {1}" -f $item.name, $parentWebUrl)
                #write-host $tempParentWebUrl  "    " $parentWebUrl   -ForegroundColor Yellow  
                Write-Log -Path $LogFileName $(" $tempParentWebUrl = {0} " -f $tempParentWebUrl)
                
                #Use splatting
                $params = @{
                    'Title'         = $item.name;
                    'Url'           = $item.displayName;
                    'Template'      = 'STS#0';
                    'Description'   = $item.description;
                    'Connection'    = $parentConn;
                }
                    
                #$s = New-PnPWeb -Title $item.name -Url $item.displayName -Web $parentWebUrl -Template "STS#0" -Description $item.description -Verbose -Connection $parentConn
                $s = New-PnPWeb @params -Verbose 
                                                 
                   
                Prepare-site -placeid $rs1.placeid  -parentConn $parentConn -WebRelativePath $tempParentWebUrl
                Move-Contents -uri $rs1.resources.contents.ref  -parentConn $parentConn -WebRelativePath $tempParentWebUrl      
                    
                Get-PlacesById -placeId $item.placeID -parentWebUrlParam $tempParentWebUrl
            }
            else
            {
                $tempParentWebUrl = $parentWebUrl + "/" + $item.displayName
                #write-host $tempParentWebUrl  "    " $parentWebUrl   -f gray 
                #Write-Host "  Create subsite " $item.name " under " $parentWebUrl "   "  $rs1.resources.html.ref   
                Write-Log -Path $LogFileName $("Create subsite {0} under {1}" -f $item.name, $parentWebUr)
                $s = New-PnPWeb -Title $item.name -Url $item.displayName  -Web $parentWebUrl -Template "STS#0" -Connection $parentConn -Description $item.description -Verbose
                #$subweb = get-pnpweb $tempParentWebUrl
                    
                Prepare-site -placeid $rs1.placeid -currentWeb $parentConn -WebRelativePath $tempParentWebUrl
                Move-Contents -uri $rs1.resources.contents.ref  -parentConn $parentConn -WebRelativePath $tempParentWebUrl
            }
        }
        if ($item.type -contains "blog")
        {
            $tempParentWebUrl = $parentWebUrl + "/" + $item.displayName
            #Write-Host "  Create subsite " $item.name " under " $parentWebUrl
            Write-Log -Path $LogFileName $("Create subsite {0} under {1}" -f $item.name, $tempParentWebUrl)
            #write-host $tempParentWebUrl  "    " $parentWebUrl   -ForegroundColor Yellow  
            try
            {
                #Use splatting
                $params = @{
                    'Title'         = $item.name;
                    'Url'           = $item.name;
                    'Description'   = $item.description;
                    'Template'      = 'BLOG#0';
                    'Local'         = 1033;
                    'Web'           = $parentWebUrl;
                    'Connection'    = $parentConn;
                }
                $s = New-PnPWeb @params -ErrorAction Stop
                #$s = New-PnPWeb -Title $item.name -Url $item.name -Description $item.description -Locale 1033 -Template "BLOG#0" -Web $parentWebUrl -Connection $parentConn
            }
            catch
            {
                $s = Get-PnPWeb -Identity $item.name
            }
            Create-BlogPosts -urlForPosts $item.resources.contents.ref -blogSubWeb $s
        }
    }
}

function Migrate-Group([string]$placeId, $pulseHostUri, $headers) 
{
    $org = 'vha'   ####  Chage ORG
    $sitePlaceid = $placeId  ####  Chage ORG
    $LogFileName = $("E:\LogFiles\Log-{0}-{1}.txt" -f $sitePlaceid , (Get-Date -Format "yyyy-MM-dd HHmm"))
    $staarttime = Get-Date
    Write-Log -Path $LogFileName " *************************************** Start  *************************************** "
    Write-Log -Path $LogFileName $("Script Start Time: {0} " -f $staarttime);

    $rs1 = Get-PlaceById -placeId $sitePlaceid
    #Get-PlacesById -placeId $sitePlaceid -parentPlaceId "1001" -org $org

    get-date
    $enddatetime = Get-Date
    $timeDiff = $staarttime - $enddatetime 

    Write-Log -Path $LogFileName $("Script ran for {0} minutes." -f $timeDiff.TotalMinutes);
    Write-Log -Path $LogFileName $("Script End Time: {0} " -f $enddatetime);
    Write-Log -Path $LogFileName " *************************************** End    *************************************** "

}




#VHA3DP