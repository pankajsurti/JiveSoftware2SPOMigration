$tenant = "{yourtenantname}";
$tenantSiteurl = "https://{0}-admin.sharepoint.com/" -f $tenant # Tenant Admin URL  

$site = read-host $("Please enter your site url {0} :" -f $tenantSiteurl)
$webUrl = "https://{0}.sharepoint.com/sites/{1}" -f $tenant, $site;
Write-Host $("Checking to {0}" -f $webUrl);

Write-Host $("Connecting to {0}" -f $tenantSiteurl);
$adminConn = Connect-PnPOnline -Url $tenantSiteurl -Credentials (Get-Credential) -ReturnConnection
$IsSiteCollExists = ([bool] (Get-PnPTenantSite -Url $webUrl -Connection $adminConn -ErrorAction SilentlyContinue) -eq $true)

if ( $IsSiteCollExists -eq $true )
{

    $message = $("Are you sure you want to delete {0} [y/n]" -f $webUrl)
    $confirmation = Read-Host $message
    while ($confirmation -ne "y")
    {
        if ( $confirmation -eq 'n' ) {exit}
        $confirmation = Read-Host $message
    }
    Write-Output $("Deleting {0}..." -f $webUrl)
    Remove-PnPTenantSite -Url $webUrl -Connection $adminConn -Force -SkipRecycleBin -Verbose 
    Write-Output $("Site {0} is deleted..." -f $webUrl)
}
else
{
    Write-Host $("{0} site does not exist." -f $webUrl);
}

$tenant = "{yourtenantname}";
$tenantSiteurl = "https://{0}-admin.sharepoint.com/" -f $tenant # Tenant Admin URL  

$credential = Get-Credential
$connAdmin = Connect-PnPOnline -Url https://{yourtenantname}-admin.sharepoint.com -ReturnConnection -UseWebLogin

Connect-PnPOnline $tenantSiteurl -credential $credential
Remove-PnPTenantSite https://{yourtenantname}.sharepoint.com/sites/vhahomeless-veterans-community-employment-services

$credential = Get-Credential
Connect-PnPOnline https://{yourtenantname}.sharepoint.com/sites/homeless-veterans-community-employment-services -credential $credential -Scopes "Group.Read.All"
Remove-PnPUnifiedGroup -Identity groupID // you can get group Ids from Get-PnPUnifiedGroup


Connect-PnPOnline "https://{yourtenantname}-admin.sharepoint.com" -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All" -Credentials $cred
$unifiedGroup = Get-PnPUnifiedGroup -Identity "Group Name"
Remove-PnPUnifiedGroup -Identity $unifiedGroup.ID 
Disconnect-PnPOnline