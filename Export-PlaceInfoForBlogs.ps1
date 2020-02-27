Clear-Host 

$username = ""
$password = ""
$userpass  = $username + ":" + $password
$bytes= [System.Text.Encoding]::UTF8.GetBytes($userpass)
$encodedlogin=[Convert]::ToBase64String($bytes)
$authheader = "Basic " + $encodedlogin
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization",$authheader)
$headers.Add("Accept","application/json")
$hosturi = "https://{baseurl}/api/core/v3"
$placeId = "1001"

$objTemplate = @{
    'html'=$null
    'parent' = $null
    'placeID' = $null
    'type' = $null
    'displayName' = $null
    'name' = $null
    'groupType' = $null
}

$array = @()

$url = "{0}/places?fields=parent,placeID,type,displayName,name,groupType,resources.html&filter=type(blog)" -f $hosturi

$LogFileName = $("E:\LogFiles\BlogsInfo-{0}.txt" -f (Get-Date -Format "yyyy-MM-dd HHmm"))


$keepLooping = $true
while ( $keepLooping -eq $true )
{
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    foreach ($item in $response.list)
    {

        $obj = New-Object -TypeName PSObject -Property $objTemplate

        $obj.'placeID'     = $item.placeID
        $obj.'type'        = $item.type
        $obj.'displayName' = $item.displayName
        $obj.'name'        = $item.name
        $obj.'groupType'   = $item.groupType
        $obj.'parent'      = $item.parent
        $obj.'html'      = $item.resources.html.ref

        write-host $("{0} {1}" -f $item.placeID,$item.name) 
        
        $array += $obj
    }
    if ( $response.links.next -ne $null)
    {
        $url = $response.links.next
        write-host $("url = {0}" -f $url) 
    }
    else
    {
        $keepLooping = $false
    }
} 

$array | Export-Csv $LogFileName -NoTypeInformation