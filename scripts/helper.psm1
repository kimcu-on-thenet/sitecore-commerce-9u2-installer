Function Generate-Username
{
	param (
        [string] $InstanceName,
        [string] $Originame = "CSFndRuntimeUser"
	)
	
	return "$($InstanceName)$($Originame)" |  % { $_.substring(0, [System.Math]::Min(20, $_.Length)) }
}

Function Create-Export-Certificate
{
    param (
        [string] $hostname,
        [string] $exportCertPath
    )

    $CertStoreLocation = 'Cert:\LocalMachine\My'
    $certificate = GetCertificateByDnsName -DnsName $hostname -CertStoreLocation $CertStoreLocation

    if ($null -eq $certificate) {
        $certificate = New-SelfSignedCertificate -certstorelocation $CertStoreLocation -dnsname $hostname
    }
    $certhash = $($certificate.thumbprint)
    $certAddress = "$($CertStoreLocation)\$($certhash)"
    Export-Certificate -Cert $certAddress -FilePath $exportCertPath
}

Function GetCertificateByDnsName{

    param
	(
		[Parameter(Mandatory = $true)]
		[ValidateScript({ $_.StartsWith("cert:\", "CurrentCultureIgnoreCase")})]
		[string] $CertStoreLocation,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $DnsName
	)

    $certificates = Get-ChildItem -Path $CertStoreLocation -Recurse | Where-Object {
		$DnsName -eq $_.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
	}

	if (( $certificates | Measure-Object ).Count -gt 1) {

		NewInvalidOperationException -Message "Multiple certificates returned from $CertStoreLocation for Name $DnsName ($($certificates.length) found)"
	}

	if ($null -eq $certificates) {

		Write-Verbose -Message "Failed to find certificate with Name $DnsName"
	}
	else {

		Write-Verbose -Message "Success, found certificate for Name $DnsName (thumbprint: $($certificates.thumbprint))"
	}

	return $certificates
}

Function Initialize-Folder {
    param (
        [string] $FolderPath
    )

    If(Test-path $FolderPath) 
    {
        Remove-item $FolderPath -Force -Recurse
    }

    New-Item -Path $FolderPath -ItemType "directory"
}

Function Remove-Logs {
    param (
        [string] $FromPath
    )

    Get-ChildItem -Path $FromPath -Include ('*.log', '*.InstallLog') -Recurse | ForEach-Object -Process {Remove-Item $_.fullname}
}

Function Copy-File
{
    param (
        [string] $CopyFrom,
        [string] $CopyTo
    )

    If (!(Test-Path -Path $CopyFrom)){
        throw "The path at $($CopyFrom) not found"
    }

    Copy-Item -Path $CopyFrom -Destination $CopyTo -Force
}

Function Create-CommerceEngineCertificate 
{
    param (
        [string] $HostName,
        [string] $OutputCertPath
    )

    Create-Export-Certificate -hostname $HostName -exportCertPath $OutputCertPath
}

Function Extract-SitecoreCommerce-Package 
{
    param (
        [string] $CommercePackagePath,
        [string] $ExtractTo
    )
    
    Expand-Archive -Path $CommercePackagePath -DestinationPath $ExtractTo
}

Function Extract-SitecoreCommerce-SubPackages
{
    param (
        [string] $PackageName,
        [string] $PackagePath,
        [string] $ExtractToFolder
    )
    $PackageZipFile = Join-Path -Path $PackagePath -ChildPath "$($PackageName).zip"
    $PackageExtractFolder = Join-Path -Path $ExtractToFolder -ChildPath "$($PackageName)"

    Expand-Archive -Path $PackageZipFile -DestinationPath $PackageExtractFolder
}

Function Modify-CommerceEngine-Package
{
    param (
        [string] $EnginePackagePath,
        [string] $EnginePackageName,
        [string] $OverrideConfigPath,
        [string] $CommerceServicesGlobalDbName,
        [string] $SitecoreDbServer = $($Env:COMPUTERNAME)
    )

    $EngineZipPackage = Join-Path -Path $EnginePackagePath -ChildPath "$($EnginePackageName).zip"

    $JsonFile = Join-Path -Path $OverrideConfigPath -ChildPath "bootstrap/Global.json"
    $JsonContent = (Get-Content $JsonFile | Out-String | ConvertFrom-Json)

    foreach($policyValue in $JsonContent.Policies.'$values')
    {
        switch ($policyValue.'$type') {
            'Sitecore.Commerce.Plugin.SQL.EntityStoreSqlPolicy, Sitecore.Commerce.Plugin.SQL' 
            {  
                $policyValue.Database = $CommerceServicesGlobalDbName
                $policyValue.Server = $SitecoreDbServer
            }
            'Plugin.Sample.Upgrade.MigrationSqlPolicy, Plugin.Sample.Upgrade' 
            {
                $policyValue.SourceStoreSqlPolicy.Database = $CommerceServicesGlobalDbName
                $policyValue.SourceStoreSqlPolicy.Server = $SitecoreDbServer
            }
            Default {}
        }
    }

    $WWWTemporaryPath = Join-Path -Path $EnginePackagePath -ChildPath "wwwroot"
    $GlobalTemporaryPath = Join-Path -Path $WWWTemporaryPath -ChildPath "bootstrap"
    If (Test-Path -Path $GlobalTemporaryPath)
    {
        Remove-Item -Path $GlobalTemporaryPath -Recurse -Force
    }
    New-Item -Path $GlobalTemporaryPath -ItemType "directory" -Force
    $GlobalConfigFile = Join-Path -Path $GlobalTemporaryPath -ChildPath "Global.json"
    $JsonContent | ConvertTo-Json -Depth 100 | Out-File -FilePath $GlobalConfigFile -Force

    Compress-Archive -Path $WWWTemporaryPath -Update -DestinationPath $EngineZipPackage
}

Function Override-Configurations {
    param (
        [string] $OverrideFromSource,
        [string] $DestinationPath
    )

    If (!(Test-Path -Path $OverrideFromSource)){
        throw "The path at $($OverrideFromSource) not found"
    }

    If (!(Test-Path -Path $DestinationPath)){
        throw "The path at $($DestinationPath) not found"
    }

    Get-ChildItem -Path $OverrideFromSource | ForEach-Object -Process { Copy-Item $_.fullname "$($DestinationPath)" -Recurse -Force }
}

Function Remove-Bindings-Certs
{
    param (
        [string] $InstanceName,
        [string] $HostHeaderName
    )
    $bindingHosts = Get-WebBinding -Name $InstanceName -HostHeader "$($HostHeaderName)" 

    If (!($null -eq $bindingHosts)) {
        Remove-WebBinding -Name $InstanceName -HostHeader "$($HostHeaderName)"
        Remove-Certs -HostName "$($HostHeaderName)"
    }
}

Function Remove-Certs
{
    param (
        [string] $HostName
    )
    $cert = Get-ChildItem -Path "cert:\LocalMachine\My" | Where-Object { $_.subject -like "CN=$HostName" }
    if ($cert -and $cert.Thumbprint) {
        $certPath = "cert:\LocalMachine\My\" + $cert.Thumbprint
        Remove-Item $certPath
        Write-Host "Removing certificate ($certPath)" -ForegroundColor Green
    }
    else {
        Write-Host "Could not find certificate under cert:\LocalMachine\My" -ForegroundColor Yellow
    }
}