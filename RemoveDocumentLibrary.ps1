#https://www.sharepointdiary.com/2019/03/fix-list-cannot-be-deleted-while-on-hold-or-retention-policy-error.html

#Parameters

$SiteURL = "https://{yourtenantname}.sharepoint.com/sites/vhahomeless-veterans-community-employment-services"

$ListName = "Documents"

 

#Connect to the Site

Connect-PnPOnline -URL $SiteURL -Credentials (Get-Credential)

 

#Get the web & document Library

$Web = Get-PnPWeb

$List = Get-PnPList -Identity $ListName

 

#Function to delete all Files and sub-folders from a Folder

Function Empty-PnPFolder([Microsoft.SharePoint.Client.Folder]$Folder)

{

    #Get the site relative path of the Folder

    $FolderSiteRelativeURL = $Folder.ServerRelativeUrl.Replace($web.ServerRelativeUrl,"")

 

    #Get All files in the folder

    $Files = Get-PnPFolderItem -FolderSiteRelativeUrl $FolderSiteRelativeURL -ItemType File

     

    #Delete all files in the Folder

    ForEach ($File in $Files)

    {

        #Delete File

        Remove-PnPFile -ServerRelativeUrl $File.ServerRelativeURL -Force -Recycle

        Write-Host -f Green ("Deleted File: '{0}' at '{1}'" -f $File.Name, $File.ServerRelativeURL)        

    }

 

    #Process all Sub-Folders

    $SubFolders = Get-PnPFolderItem -FolderSiteRelativeUrl $FolderSiteRelativeURL -ItemType Folder

    Foreach($SubFolder in $SubFolders)

    {

        #Exclude "Forms" and Hidden folders

        If( ($SubFolder.Name -ne "Forms") -and (-Not($SubFolder.Name.StartsWith("_"))))

        {

            #Call the function recursively

            Empty-PnPFolder -Folder $SubFolder

 

            #Delete the folder

            Remove-PnPFolder -Name $SubFolder.Name -Folder $FolderSiteRelativeURL -Force -Recycle

            Write-Host -f Green ("Deleted Folder: '{0}' at '{1}'" -f $SubFolder.Name, $SubFolder.ServerRelativeURL)

        }

    }

}

 

#Get the Root Folder of the Document Library and call the function to empty folder contents recursively

Empty-PnPFolder -Folder $List.RootFolder

 

#Now delete the document library

Remove-PnPList -Identity $ListName -Recycle -Force

Write-host -f Green "Document Library Deleted Successfully!"


#Read more: https://www.sharepointdiary.com/2019/03/fix-list-cannot-be-deleted-while-on-hold-or-retention-policy-error.html#ixzz6B2mycRrh
