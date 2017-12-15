#Requires -RunAsAdministrator
#Requires -Modules IISAdministration, Microsoft.PowerShell.Archive, SQLPS

$version = '9.1.1'
$dnnInstallUrl = "https://github.com/dnnsoftware/Dnn.Platform/releases/download/v$version/DNN_Platform_$version.129-232_Install.zip"
$installZip = "$PSScriptRoot\install_$version.zip"
$siteDir = "$PSScriptRoot\wwwroot\"
$siteName = "dnn-platform_docker_build_$version"
$port = '55555'
$webConfigPath = "$siteDir\web.config"

if (-not (Test-Path $installZip)) {
    Invoke-WebRequest $dnnInstallUrl -OutFile $installZip
}

if (Test-Path $siteDir) {
    Remove-Item $siteDir -Recurse -Force
}

Expand-Archive $installZip $siteDir

New-IISSite -Name $siteName -PhysicalPath $siteDir -BindingInformation "*:${port}:" -Force

$site = Get-IISSite -Name $siteName
$appPoolName = $site.Applications.ApplicationPoolName
$manager = Get-IISServerManager
$sid = $manager.ApplicationPools[$appPoolName].RawAttributes.applicationPoolSid
icacls $siteDir /grant "*$($sid):M" /T /Q
icacls $siteDir /grant "IUSR:R" /T /Q

[xml]$config = Get-Content $webConfigPath
$config.configuration.connectionStrings.GetElementsByTagName("add") `
    | Where-Object { $_.name -eq 'SiteSqlServer' } `
    | ForEach-Object { $_.connectionString = "Server=(local);Database=$siteName;Integrated Security=True"; }
$config.Save($webConfigPath)

Invoke-Sqlcmd -Query:"CREATE DATABASE [$siteName];" -Database:master
if (-not (Test-Path "SQLSERVER:\SQL\(local)\DEFAULT\Logins\$(Encode-SQLName "IIS AppPool\$appPoolName")")) {
    Invoke-Sqlcmd -Query:"CREATE LOGIN [IIS AppPool\$appPoolName] FROM WINDOWS WITH DEFAULT_DATABASE = [$siteName];" -Database:master
}
Invoke-Sqlcmd -Query:"CREATE USER [IIS AppPool\$appPoolName] FOR LOGIN [IIS AppPool\$appPoolName];" -Database:$siteName
Invoke-Sqlcmd -Query:"EXEC sp_addrolemember N'db_owner', N'IIS AppPool\$appPoolName';" -Database:$siteName

(Invoke-WebRequest "http://localhost:$port/Install/Install.aspx?mode=install").Content

Remove-IISSite -Name $siteName -Confirm:$false
Invoke-Sqlcmd -Query:"DROP DATABASE [$siteName];" -Database:master

docker build -t dnn-platform:latest $PSScriptRoot
