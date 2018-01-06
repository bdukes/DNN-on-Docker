# this script borrows ideas from https://github.com/Microsoft/mssql-docker/blob/1efc4cf9b78fa5fccea682f26067189660af85c8/windows/mssql-server-windows-express/start.ps1

param(
    [Parameter(Mandatory = $false)]
    [string]$connectionString
);

if ($connectionString -eq '_') {
    Write-Verbose 'ERROR: You must provide a connection string.'
    Write-Verbose 'Set the environment variable connection_string to a connection string for a DNN database.'

    exit 1
}

[xml]$config = Get-Content C:\inetpub\wwwroot\web.config
$config.configuration.connectionStrings.GetElementsByTagName("add") `
    | Where-Object { $_.name -eq 'SiteSqlServer' } `
    | ForEach-Object { $_.connectionString = $connectionString; }
$config.Save('C:\inetpub\wwwroot\web.config')

./ServiceMonitor.exe w3svc
