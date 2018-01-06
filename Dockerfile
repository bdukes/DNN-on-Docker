# this Dockerfile borrows ideas from https://github.com/Microsoft/mssql-docker/blob/1efc4cf9b78fa5fccea682f26067189660af85c8/windows/mssql-server-windows-express/dockerfile
FROM microsoft/aspnet

SHELL ["powershell", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop';"]

ENV connection_string _

COPY Start.ps1 /

COPY wwwroot/ C:\\inetpub\\wwwroot

# based on https://serverfault.com/a/888006
RUN Import-Module IISAdministration; \
    $manager = Get-IISServerManager; \
    $sid = $manager.ApplicationPools['DefaultAppPool'].RawAttributes.applicationPoolSid; \
    icacls C:\inetpub\wwwroot /grant "*$($sid):M" /T /Q;

# DNS workaround, from https://github.com/docker/for-win/issues/500#issuecomment-289373352
RUN Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name ServerPriorityTimeLimit -Value 0 -Type DWord

ENTRYPOINT [ "powershell", "-NoProfile", "-Command", "./Start.ps1 -connectionString $env:connection_string -Verbose" ]
