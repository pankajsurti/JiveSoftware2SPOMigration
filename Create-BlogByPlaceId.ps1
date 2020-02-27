Clear-Host 
$staarttime = Get-Date
$username = "username"
$password = "password!"
$userpass  = $username + ":" + $password
$bytes= [System.Text.Encoding]::UTF8.GetBytes($userpass)
$encodedlogin=[Convert]::ToBase64String($bytes)
$authheader = "Basic " + $encodedlogin
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization",$authheader)
$headers.Add("Accept","application/json")
$hosturi = "https://{{baseurl}}/api/core/v3"

$placeId = "619001"


$url = "https://{yourtenantname}.sharepoint.com/sites/siteprovisioning-dev/"
$appId = ""
$appSecret = ""
$conn = Connect-PnPOnline -Url $Url -AppId $appId -AppSecret $appSecret -ReturnConnection

function Create-BlogByPlaceId([string]$placeId) 
{
    $response = Invoke-RestMethod  -Uri $hosturi"/places/"$placeId"" -Headers $headers -Method Get -Verbose 
    if ( $response.resources.blog )
    {
        # The blog is present
        $blogres = Invoke-RestMethod  -Uri $response.resources.blog.ref -Headers $headers -Method Get -Verbose 
        # extract name and type
        if ( $blogres.type -eq "blog")
        {
            # create blog sub site with the name.

            #TODO: please add your relative url for the parent web. 

            $blogSubWeb = New-PnPWeb -Title $blogres.name -Url $blogres.name -Description $blogres.description -Locale 1033 -Template "BLOG#0" -Connection $conn

            if ( $blogres.resources.contents )
            {
                $keepLooping = $true

                $urlForPosts = $blogres.resources.contents.ref

                while ( $keepLooping -eq $true )
                {
                    # the contents are found now get the post contents - content.ref tells number of blogs
                    $blogpostres = Invoke-RestMethod  -Uri  $urlForPosts -Headers $headers -Method Get -Verbose 
                    ForEach($listItem in ($blogpostres.list))
                    {
                        # now use the subject and body to add the post
                        # $listItem.content.text
                        Write-host $listItem.subject

                        Add-PnPListItem -List "Posts" -Values @{"Title" = $listItem.subject; "Body"=$listItem.content.text} -Web $blogSubWeb

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
        }

    }
}


Create-BlogByPlaceId -placeId $placeId

