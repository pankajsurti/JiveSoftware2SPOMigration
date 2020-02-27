Clear-Host 
$script2Run = $PSScriptRoot+"\Migrate-Group.ps1"
. $script2Run

$username = "dhiren.amin@va.gov"
$password = "Ad5628672!"
$userpass  = $username + ":" + $password
$bytes= [System.Text.Encoding]::UTF8.GetBytes($userpass)
$encodedlogin=[Convert]::ToBase64String($bytes)
$authheader = "Basic " + $encodedlogin
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization",$authheader)
$headers.Add("Accept","application/json")
$hosturi = "https://www.vapulse.va.gov/api/core/v3"

$PlaceIds = @()

Import-Csv E:\powershell\Jive\GroupsPlaceId.csv | ForEach-Object {
    $PlaceIds += $_.PlaceId
}

foreach ($PlaceId in $PlaceIds)
{

    Migrate-Group -placeId $PlaceId -pulseHostUri hosturi -headers $headers


}