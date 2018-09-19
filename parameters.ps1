######## Site information
$scinstance = "sc92commerce"
$scwebroot = "D:\Inetpub\wwwroot\"
$solrUrl = "https://localhost:8983/solr"
$solrRootFolder = "D:\\_SolrData"

$HostNamePostFix = "dev.local"
$SiteName = "$($scinstance).$($HostNamePostFix)"
$SiteUrl = "https://$($SiteName)"
$XConnectSiteName = "$($scinstance)_xconnect.$($HostNamePostFix)"
$SitesContentRootPath = Join-Path -Path "$($scwebroot)" -ChildPath "/" | Resolve-Path

$SitecoreUsername = "sitecore\admin"
$SitecoreUserPassword = "b"


######## SQL Server Information
$SqlServer = $($Env:COMPUTERNAME) #OR "SQLServerName\SQLInstanceName"
$SqlAdminUser = "sa"
$SqlAdminPassword = '--------SqlAdminPassword--------------'


######## Deployment Information
$assetPath = Join-Path -Path $PSScriptRoot -ChildPath "assets"
$OverrideConfigPath = Join-Path -Path $assetPath -ChildPath "Overrides"
$ZCustomFolder = Join-Path -Path $assetPath -ChildPath "Z.Custom"

$deployPath = Join-Path -Path $PSScriptRoot -ChildPath "deploy"


######## Sitecore Commerce Information
$commerceEngineCertName = "$($scinstance).commerce.engine"
$commercePackage = "Sitecore.Commerce.2018.07-2.2.126.zip"
$commerceSiteHostName = "sxa.storefront.com"

$BraintreeAccount = @{
    MerchantId = '-------------Merchant ID-------------------'
    PublicKey = '--------------Public Key--------------------'
    PrivateKey = '-------------Private Key-------------------'
  }

if (Get-Module("helper")) {
    Remove-Module "helper"
}
Import-Module "$PSScriptRoot/scripts/helper.psm1"

$UserName = Generate-Username -InstanceName $scinstance -Originame "SCUser"
$UserAccount = @{
	Domain = $Env:COMPUTERNAME
	UserName = $UserName
	Password = 'Pu8azaCr'
}

$FullUsername = "$($Env:COMPUTERNAME)\$($UserName)"

$CommerceServicesGlobalDbName = "$($scinstance)_SitecoreCommerce9_Global"
$CommerceServicesDbName = "$($scinstance)_SitecoreCommerce9_SharedEnvironments"
$ServicesPortSuffix = "0" # Support for multiple instances

$SPERemotingZipFile = Join-Path -Path $assetPath -ChildPath "SPE Remoting-4.7.zip"
$NewBusinessToolUrl = "https://localhost:4200$ServicesPortSuffix"