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

ENTRYPOINT [ "./Start.ps1", "-connection_string", "$env:connection_string", "Verbose" ]
