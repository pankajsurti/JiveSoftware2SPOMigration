cls 
$sitecollectionurl = "https://{yourtenantname}.sharepoint.com/sites/commsite"

$connAdmin = Connect-PnPOnline -Url https://{yourtenantname}-admin.sharepoint.com -ReturnConnection -UseWebLogin

$DeletedSite = Get-PnPTenantRecycleBinItem | Where {$_.URL -eq $sitecollectionurl}
$DeletedSite
#Read more: https://www.sharepointdiary.com/2017/12/sharepoint-online-delete-site-collection-from-recycle-bin.html#ixzz65nBldaSz
#Clear-PnPTenantRecycleBinItem -Url $sitecollectionurl -Force