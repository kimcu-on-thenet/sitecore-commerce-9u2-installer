$ErrorActionPreference = 'Stop'

. $PSScriptRoot\parameters.ps1

if (Get-Module("uninstall")) {
    Remove-Module "uninstall"
}
Import-Module "$PSScriptRoot/scripts/uninstall.psm1"

Write-Host "*******************************************************" -ForegroundColor Green
Write-Host " UN-Installing Sitecore Commerce" -ForegroundColor Green
Write-Host " Sitecore: $SiteName" -ForegroundColor Green
Write-Host " Commerce Host Name: $commerceSiteHostName" -ForegroundColor Green
Write-Host "*******************************************************" -ForegroundColor Green


# 1. Remove databases

$DatabaseServer = Get-Commerce-Database -SqlServer $SqlServer -SqlAdminUser $SqlAdminUser -SqlAdminPassword $SqlAdminPassword

Remove-Commerce-Database -Name $CommerceServicesGlobalDbName -Server $DatabaseServer
Remove-Commerce-Database -Name $CommerceServicesDbName -Server $DatabaseServer

# 2. Remove SQL Login
try
{
    $database = $DatabaseServer.Databases["$($scinstance)_core"]

    if($database.Users.Contains($FullUsername))
    {
        $database.Users[$FullUsername].Drop();
    }

    if ($DatabaseServer.Logins.Contains($FullUsername)) 
    { 
        $DatabaseServer.Logins[$FullUsername].Drop(); 
    }

    # 3. Remove LocalUser
    Remove-LocalUser -Name $UserName
}
catch {}

# 4. Remove Certificates
Remove-Certs -hostname $commerceSiteHostName
Remove-Certs -hostname "SitecoreIdentityServer_$($scinstance)"
Remove-Certs -hostname $commerceEngineCertName

# 5. Remove Commerce sites
$CommerceSites = "CommerceOps_$($scinstance)",
                 "CommerceShops_$($scinstance)",
                 "CommerceAuthoring_$($scinstance)",
                 "CommerceMinions_$($scinstance)",
                 "SitecoreBizFx_$($scinstance)",
                 "SitecoreIdentityServer_$($scinstance)"

foreach($site in $CommerceSites)
{
    Remove-SitecoreIisSite -name $site
}

foreach($site in $CommerceSites)
{
    $path = Join-Path -Path $scwebroot -ChildPath $site
    Remove-SitecoreFiles -path $path
}

# 6. Remove Solr Core
Remove-SitecoreSolrCore -SolrUrl $solrUrl -SolrPrefix $scinstance

# 7. Remove bindings
Remove-WebBinding -Name $SiteName -HostHeader "$($commerceSiteHostName)"
