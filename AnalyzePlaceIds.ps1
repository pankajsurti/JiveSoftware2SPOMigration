Clear-Host 
$script2Run = $PSScriptRoot+"\Migrate-JivePlace.ps1"
. $script2Run

$username = ""
$password = ""
$userpass  = $username + ":" + $password
$bytes= [System.Text.Encoding]::UTF8.GetBytes($userpass)
$encodedlogin=[Convert]::ToBase64String($bytes)
$authheader = "Basic " + $encodedlogin
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization",$authheader)
$headers.Add("Accept","application/json")
$hosturi = "https://{yourhostapi}/api/core/v3"



$PlaceIds = @()


$OutputFolderPath = $("{0}\AnalyzeFiles\{1}" -f $psScriptRoot, (Get-Date -Format "MM-dd-yy"))
$OutputFileName = $("{0}\AnalyzePlaceIdsInfo.csv" -f $OutputFolderPath)
if( -not ( Test-Path -Path $OutputFolderPath ) )
{
    # create directory
    New-Item -ItemType Directory -Force -Path $OutputFolderPath
}



function Get-ContentsInfoByPlaceId([string]$placeId) 
{
    $totalContenSize = 0
    $objContentsTemplate = @{
        'contentType'=$null
        'name' = $null
        'size' = $null
        'type' = $null
        'contentID' = $null
        'author' = $null
        'published' = $null
    }

    $ContentsArray = @()
    $OutputContentFileName = $("{0}\ContentsFor{1}.csv" -f $OutputFolderPath, $placeId)
    $contentsURI = $("{0}/places/{1}/contents" -f $hosturi, $placeId)
    write-host  $("URL : {0}" -f $contentsURI)        
    $responsedocs = Invoke-RestMethod -Uri $contentsURI -Headers $headers -Method Get
    do 
    {
        foreach($listItem in ($responsedocs.list))
        {
            write-host $listItem.type
            if($listItem.type -eq "file")
            {
                $obj = New-Object -TypeName PSObject -Property $objContentsTemplate
                $obj.'contentType'=$listItem.contentType
                $obj.'name' = $listItem.name
                $obj.'size' = $listItem.size
                $obj.'type' = $listItem.type
                $obj.'contentID' = $listItem.contentID
                $obj.'author' = $listItem.author.emails[0].value
                $obj.'published' = $listItem.published

                #write-host $("{0} {1}" -f $listItem.name,$listItem.contentType) 
                $ContentsArray += $obj
                $totalContenSize += $listItem.size ###increment size by file size

            }
            if($listItem.type -eq "event")
            {
            }
            if($listItem.type -eq "document")
            {
            }
        }
        $nextitems = $responsedocs.links.next 
        if ( $nextitems) 
        {
            write-host  $("URL : {0}" -f $nextitems)        
            $responsedocs =Invoke-RestMethod -Uri $nextitems -Headers $headers -Method Get
        }
    }while ($nextitems)          

    $ContentsArray | Export-Csv $OutputContentFileName -NoTypeInformation

    return $totalContenSize

}

function Get-TotalMembersCountByPlaceId([string]$placeId) 
{
    $totalMembersCount = 0
    $membersURI = $("{0}/members/places/{1}" -f $hosturi, $placeId)
    write-host  $("URL : {0}" -f $membersURI)        
    $responsedocs = Invoke-RestMethod -Uri $membersURI -Headers $headers -Method Get
    do 
    {
        foreach($listItem in ($responsedocs.list))
        {
            if ( $listItem.state -eq 'owner' ) 
            {
                $totalMembersCount += 1
            }
            elseif  ( $listItem.state -eq 'member' )   # change memberrrrrr to member
            {
                $totalMembersCount += 1
            }
        }
        $nextitems = $responsedocs.links.next 
        if ( $nextitems) 
        {
            write-host  $("URL : {0}" -f $nextitems)        
            $responsedocs =Invoke-RestMethod -Uri $nextitems -Headers $headers -Method Get
        }
    }while ($nextitems)          
    return $totalMembersCount
}


function Get-PlaceById([string]$placeId) 
{
    write-host  $("URL : {0}/places/{1}" -f $hosturi, $placeId)        
    $response = Invoke-RestMethod -Uri $hosturi"/places/"$placeId -Headers $headers -Method Get
    return $response
}
function Write-Exception2LogFile($exception, $func2Report)
{
    Write-Host $("Caught an exception at : {0}" -f $func2Report)
    Write-Host $("Exception Type: {0}" -f $exception.GetType().FullName)
    Write-Host $LogFileName $("Exception Message: {0}"-f $exception.Message)
}

$objTemplate = @{
    'placeID' = $null
    'html'=$null
    'spourl' = $null
    'parent' = $null
    'type' = $null
    'displayName' = $null
    'name' = $null
    'groupType' = $null
    'TotalMembers' = $null
    'TotalContentSize' = $null

}

function Analyze-PlaceId($PlaceId, $SPOURL)
{
    try
    {
        $rs1 = Get-PlaceById -placeId $PlaceId

        if ($rs1.type -ne 'space')
        {
            $totalMemCount = $rs1.memberCount # Get-TotalMembersCountByPlaceId -placeId $PlaceId
        }
        $totalContentSize = Get-ContentsInfoByPlaceId -placeId $PlaceId

        $obj = New-Object -TypeName PSObject -Property $objTemplate
        $obj.'placeID'     = $rs1.placeID
        $obj.'type'        = $rs1.type
        $obj.'displayName' = $rs1.displayName
        $obj.'name'        = $rs1.name
        $obj.'groupType'   = $rs1.groupType
        $obj.'parent'      = $rs1.parent
        $obj.'html'        = $rs1.resources.html.ref
        if ($rs1.type -eq 'space')
        {
            if ( $SPOURL.Length -gt 0 )
            {
                $obj.'spourl'      = $("{0}/{1}" -f $SPOURL, $rs1.displayName)
            }
            else
            {
                $obj.'spourl'      = $("https://dvagov.sharepoint.com/sites/VHA{0}" -f $rs1.displayName)
            }
            $SPOURL = $obj.'spourl'
        }
        else
        {
            $obj.'spourl'      = $("https://dvagov.sharepoint.com/sites/VHA{0}" -f $rs1.displayName)
        }

        $obj.'TotalMembers' = $totalMemCount
        $obj.'TotalContentSize' = $totalContentSize

        write-host $("{0} {1}" -f $rs1.placeID,$rs1.name) 
        #$g_array += $obj
        $g_array.Add($obj)

        if ( ($rs1.type -eq 'space') -and ($rs1.childCount -gt 0) )
        {
            write-host  $("URL : {0}/places/{1}/places" -f $hosturi, $placeId)
            $response = Invoke-RestMethod -Uri $hosturi"/places/"$placeId"/places" -Headers $headers -Method Get
            foreach ($item in $response.list)
            {
                Analyze-PlaceId -PlaceId $item.placeID -SPOURL $SPOURL
            }
        }
    }
    catch
    {
        Write-Exception2LogFile -exception $_.Exception -func2Report "Analyze-PlaceId"
    }
}

$g_array = New-Object System.Collections.Generic.List[System.Object]
#$g_array = @()
function Process-AllPlaceIds()
{
    Import-Csv $PSScriptRoot"\JivePlaceId.csv" | ForEach-Object {
        $PlaceIds += $_.PlaceId
    }
    foreach ($PlaceId in $PlaceIds)
    {
        $placeId = $placeId.Trim()
        if ( $placeId.Length -gt 0 )
        {
            Analyze-PlaceId -PlaceId $PlaceId -SPOURL ""
        }
    }
    $g_array | Export-Csv $OutputFileName -NoTypeInformation
}

Process-AllPlaceIds