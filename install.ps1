$ErrorActionPreference = 'Stop'
. $PSScriptRoot\parameters.ps1

Write-Host "*******************************************************" -ForegroundColor Green
Write-Host " Installing Sitecore Commerce" -ForegroundColor Green
Write-Host " Sitecore: $SiteName" -ForegroundColor Green
Write-Host " Commerce Host Name: $commerceSiteHostName" -ForegroundColor Green
Write-Host "*******************************************************" -ForegroundColor Green

# 0. Initializing the 'deploy' folder which stores the installation stuffs
Initialize-Folder -FolderPath $deployPath
Remove-Bindings-Certs -InstanceName $SiteName -HostHeaderName $commerceSiteHostName

$AppConfigIncludeFolder = Join-Path -Path $SitesContentRootPath -ChildPath $SiteName | Join-Path -ChildPath "App_Config/Include"
Write-Host "Copy $($ZCustomFolder) to $($AppConfigIncludeFolder)" -ForegroundColor Green
Copy-Item -Path $ZCustomFolder -Destination $AppConfigIncludeFolder -Recurse -Force

# 1. Create and export the certificate for 'Commerce Engine'
$commerceEngineCertName = "$($scinstance).commerce.engine"
$commerceEngineCertPath = Join-Path -Path $deployPath -ChildPath "$($commerceEngineCertName).cer"

Create-CommerceEngineCertificate -HostName $commerceEngineCertName -OutputCertPath $commerceEngineCertPath

# 2. Extracting the require 'zip' file
$CommerceZipPackageFile = Join-Path -Path $assetPath -ChildPath $commercePackage
Extract-SitecoreCommerce-Package -CommercePackagePath $CommerceZipPackageFile -ExtractTo $deployPath

# 3.
$commerceSIF = "SIF.Sitecore.Commerce.1.2.14"
$commerceBizFX = "Sitecore.BizFX.1.2.19"
$commerceEngineSDK = "Sitecore.Commerce.Engine.SDK.2.2.72"

$SubPackages = New-Object 'System.Collections.Generic.List[String]'
$SubPackages.Add($commerceSIF)
$SubPackages.Add($commerceBizFX)
$SubPackages.Add($commerceEngineSDK)

foreach ($item in $SubPackages) {
    Extract-SitecoreCommerce-SubPackages -PackagePath $deployPath -PackageName $item -ExtractToFolder $deployPath
}

# 4. Modify the incorrect configuration from Sitecore
$commerceEngine = "Sitecore.Commerce.Engine.2.2.126"
$commerceEngineOverride = Join-Path -Path $OverrideConfigPath -ChildPath "Commerce.Engine" | Join-Path -ChildPath "wwwroot"

Modify-CommerceEngine-Package -EnginePackagePath $deployPath `
                              -EnginePackageName $commerceEngine `
                              -OverrideConfigPath $commerceEngineOverride `
                              -CommerceServicesGlobalDbName $CommerceServicesGlobalDbName `
                              -SitecoreDbServer $SqlServer

# 5. Copy the 'dacpag' file from 'Commerece.Engine.SDK' to the root of deployment folder
$DacPacFileName = "Sitecore.Commerce.Engine.DB.dacpac"
$SourceDacPacFile = Join-Path -Path $deployPath -ChildPath $commerceEngineSDK | Join-Path -ChildPath $DacPacFileName

Copy-File -CopyFrom $SourceDacPacFile -CopyTo $deployPath

# 6. Overriding some configurations which match the specific environment
$OverrideFromSource = Join-Path -Path $OverrideConfigPath -ChildPath "SIF"
$CommerceSIFPath = Join-Path -Path $deployPath -ChildPath $commerceSIF

Override-Configurations -OverrideFromSource $OverrideFromSource -DestinationPath $CommerceSIFPath

# 7. Copy the "Microsoft.Web.XmlTransform.dll" to the root of deployment folder
$WebTransformDll = "Microsoft.Web.XmlTransform.dll"
$SourceTransformDll = Join-Path -Path $assetPath -ChildPath $WebTransformDll
Copy-File -CopyFrom $SourceTransformDll -CopyTo $deployPath

# 8. Starting installed

$CurrentPath = $PSScriptRoot

try {
    Set-Location -Path "$($CommerceSIFPath)"
    
    . ".\sc.commerce.deploy.ps1" -InstanceName $scinstance `
                                -SiteName $SiteName `
                                -XConnectSiteName $XConnectSiteName `
                                -SiteHostHeaderName $commerceSiteHostName `
                                -WebInstallDir $SitesContentRootPath `
                                -ServicesPortSuffix $ServicesPortSuffix `
                                -SqlServer $SqlServer `
                                -CommerceServicesGlobalDbName $CommerceServicesGlobalDbName `
                                -CommerceServicesDbName $CommerceServicesDbName `
                                -CommerceEngineCertificatePath $commerceEngineCertPath `
                                -SolrUrl $solrUrl `
                                -SolrRoot $solrRootFolder `
                                -ResourceInstallPath $deployPath `
                                -BrainTreeAccount $BraintreeAccount `
                                -SitecoreModulesPath $assetPath `
                                -BizFxFolder $commerceBizFX `
                                -UserAccount $UserAccount `
                                -SitecoreUsername $SitecoreUsername `
                                -SitecoreUserPassword $SitecoreUserPassword
}
catch 
{
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.ItemName -ForegroundColor Red
}
finally
{
    Set-Location -Path "$($CurrentPath)"
}

Deploy-SPE-Remoting -SPERemotingZipFile $SPERemotingZipFile
Update-BusinessTool-Url -SiteUrl $SiteUrl `
                        -SitecoreUsername $SitecoreUsername `
                        -SitecoreUserPassword $SitecoreUserPassword `
                        -NewBusinessToolUrl $NewBusinessToolUrl

$AppConfigIncludeZCustom = Join-Path -Path $AppConfigIncludeFolder -ChildPath "Z.Custom"
Remove-Item -Path $AppConfigIncludeZCustom -Force -Recurse

