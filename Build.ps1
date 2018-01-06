#Requires -RunAsAdministrator
#Requires -Modules IISAdministration, Microsoft.PowerShell.Archive, SqlServer

$version = '9.1.1'
$dnnInstallUrl = "https://github.com/dnnsoftware/Dnn.Platform/releases/download/v$version/DNN_Platform_$version.129-232_Install.zip"
$installZip = "$PSScriptRoot\install_$version.zip"
$dbDir = "$PSScriptRoot\db\"
$siteDir = "$PSScriptRoot\wwwroot\"
$siteName = "dnn-platform_docker_build_$version"
$port = '55555'
$webConfigPath = "$siteDir\web.config"
$installConfigPath = "$siteDir\Install\DotNetNuke.install.config.resources"

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

[xml]$webConfig = Get-Content $webConfigPath
$webConfig.configuration.connectionStrings.GetElementsByTagName("add") `
    | Where-Object { $_.name -eq 'SiteSqlServer' } `
    | ForEach-Object { $_.connectionString = "Server=(local);Database=$siteName;Integrated Security=True"; }
$webConfig.Save($webConfigPath)

if (Test-Path $dbDir) {
    Remove-Item $dbDir -Recurse -Force
}

mkdir $dbDir

Invoke-Sqlcmd -Query:"CREATE DATABASE [$siteName] ON (NAME=dnn, FILENAME='$dbDir\dnn.mdf') LOG ON (NAME=dnn_log, FILENAME='$dbDir\dnn_log.ldf');" -Database:master
if (-not (Test-Path "SQLSERVER:\SQL\(local)\DEFAULT\Logins\$(ConvertTo-EncodedSqlName "IIS AppPool\$appPoolName")")) {
    Invoke-Sqlcmd -Query:"CREATE LOGIN [IIS AppPool\$appPoolName] FROM WINDOWS WITH DEFAULT_DATABASE = [$siteName];" -Database:master
}
Invoke-Sqlcmd -Query:"CREATE USER [IIS AppPool\$appPoolName] FOR LOGIN [IIS AppPool\$appPoolName];" -Database:$siteName
Invoke-Sqlcmd -Query:"EXEC sp_addrolemember N'db_owner', N'IIS AppPool\$appPoolName';" -Database:$siteName

[xml]$installConfig = Get-Content $installConfigPath
$installConfig.dotnetnuke.portals.portal.templatefile = 'Blank Website.template'
$installConfig.dotnetnuke.settings.AutoAddPortalAlias = 'Y'
$installConfig.Save($installConfigPath)

(Invoke-WebRequest "http://localhost:$port/Install/Install.aspx?mode=install").Content

Remove-IISSite -Name $siteName -Confirm:$false
Invoke-Sqlcmd -Query:"ALTER DATABASE [$siteName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;" -Database:master
Invoke-Sqlcmd -Query:"ALTER DATABASE [$siteName] SET MULTI_USER WITH ROLLBACK IMMEDIATE;" -Database:master
Invoke-Sqlcmd -Query:"EXEC sp_detach_db @dbname='$siteName', @skipchecks='true';" -Database:master

docker build -t dnn-platform:$version $PSScriptRoot
