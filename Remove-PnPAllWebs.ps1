#Function to delete a subsite and its all child sites

Function Remove-PnPAllWebs([Microsoft.SharePoint.Client.Web]$Web) 

{

    #Get All Subsites of the web

    $SubWebs  = Get-PnPSubWebs -Identity $Web

    ForEach($SubWeb in $SubWebs)

    {

        #Call the function recursively to remove subsites

        Remove-PnPAllWebs($SubWeb)

    }

    #Delete the subsite

    Remove-PnPWeb -Identity $Web -Force

    Write-host -f Green "Deleted Sub-Site:"$Web.URL

}

 


 

#Get Credentials to connect

#$Cred = Get-Credential

  

$url = "https://{yourtenantname}.sharepoint.com/sites/vhahomeless-veterans-community-employment-services/Homeless%20Veterans%20Community%20Employment%20Services%20(HVCES)"

$appId = ""
$appSecret = ""

$conn = Connect-PnPOnline -Url $Url -AppId $appId -AppSecret $appSecret -ReturnConnection



 

#Get the Web 

$Web = Get-PnPWeb

 

#sharepoint online delete subsite powershell

Remove-PnPAllWebs $Web


#Read more: https://www.sharepointdiary.com/2016/05/sharepoint-online-delete-subsite-using-powershell.html#ixzz6AVFzmSBO
