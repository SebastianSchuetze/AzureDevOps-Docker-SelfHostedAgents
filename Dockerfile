FROM mcr.microsoft.com/powershell:latest

WORKDIR /azp

COPY start.ps1 .

CMD pwsh ./start.ps1