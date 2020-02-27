Clear-Host 
$script2Run = $PSScriptRoot+"\Migrate-JivePlace.ps1"
. $script2Run
$username = "TODO"
$password = "TODO"


$userpass  = $username + ":" + $password
$bytes= [System.Text.Encoding]::UTF8.GetBytes($userpass)
$encodedlogin=[Convert]::ToBase64String($bytes)
$authheader = "Basic " + $encodedlogin
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization",$authheader)
$headers.Add("Accept","application/json")
$hosturi = "https://www.{{TODOYourURL}}.com/api/core/v3"

$PlaceIds = @()
$connAdmin  = Connect-PnPOnline -Url https://{{TODO-YOURTENANTNAME}}-admin.sharepoint.com -ReturnConnection -UseWebLogin
$connGraph = Connect-PnPOnline -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All" -Url https://{{TODO-YOURTENANTNAME}}-admin.sharepoint.com -ReturnConnection -UseWebLogin

Import-Csv $PSScriptRoot"\JivePlaceId.csv" | ForEach-Object {
    $PlaceIds += $_.PlaceId
}

foreach ($PlaceId in $PlaceIds)
{
    if ( $PlaceId.Trim().Length -gt 0 )
    {
        Migrate-JivePlace -placeId $PlaceId.Trim() -pulseHostUri hosturi -headers $headers -psScriptRoot $PSScriptRoot -connAdmin $connAdmin
    }
}