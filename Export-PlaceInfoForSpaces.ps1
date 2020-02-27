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
    'url' = $null
    'placeID' = $null
    'type' = $null
    'displayName' = $null
    'name' = $null
}


$array = @()

$response = Invoke-RestMethod -Uri $hosturi"/places/"$placeId -Headers $headers -Method Get

$url = "{0}/places/{1}/places" -f $hosturi, $placeId

$LogFileName = $("E:\LogFiles\SpacesInfo-{0}.txt" -f (Get-Date -Format "yyyy-MM-dd HHmm"))



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
        $obj.'url'         = $("https://www.vapulse.va.gov/community/{0}" -f $item.displayName)

        write-host $("{0} {1}" -f $item.placeID,$item.displayName) 
        
        $array += $obj

    }
    if ( $response.links.next -ne $null)
    {
        $url = $response.links.next
    }
    else
    {
        $keepLooping = $false
    }
} 

$array | Export-Csv $LogFileName -NoTypeInformation