$Env:AZP_URL = "https://dev.azure.com/razorspoint"
$Env:AZP_TOKEN = "hlizgdfho737u3fmtzrlu3wxpmiz3r6kzdzajcegtvrnla5hmwha"
$Env:AZP_AGENT_NAME = "mydockeragent"

if (-not (Test-Path Env:AZP_URL)) {
  Write-Error "error: missing AZP_URL environment variable"
  exit 1
}
  
if (-not (Test-Path Env:AZP_TOKEN_FILE)) {
  if (-not (Test-Path Env:AZP_TOKEN)) {
    Write-Error "error: missing AZP_TOKEN environment variable"
    exit 1
  }
  
  $Env:AZP_TOKEN_FILE = "\azp\.token"
  if (-not (Test-Path "\azp")) {
    New-Item -Path "\azp" -ItemType Directory | Out-Null
  }
  $Env:AZP_TOKEN | Out-File -FilePath $Env:AZP_TOKEN_FILE
}
  
Remove-Item Env:AZP_TOKEN
  
if ($Env:AZP_WORK -and -not (Test-Path Env:AZP_WORK)) {
  New-Item $Env:AZP_WORK -ItemType directory | Out-Null
}
  
New-Item "\azp\agent" -ItemType directory | Out-Null
  
# Let the agent ignore the token env variables
$Env:VSO_AGENT_IGNORE = "AZP_TOKEN,AZP_TOKEN_FILE"
  
Set-Location "\azp\agent"
  
Write-Host "1. Determining matching Azure Pipelines agent..." -ForegroundColor Cyan
  
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$(Get-Content ${Env:AZP_TOKEN_FILE})"))
$package = Invoke-RestMethod -Headers @{Authorization = ("Basic $base64AuthInfo") } "$(${Env:AZP_URL})/_apis/distributedtask/packages/agent?platform=linux-x64&`$top=1"
$packageUrl = $package[0].Value.downloadUrl
$downloadedFileName = Split-Path -Path $packageUrl -Leaf
  
Write-Host $packageUrl
  
Write-Host "2. Downloading and installing Azure Pipelines agent..." -ForegroundColor Cyan
  
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($packageUrl, "$(Get-Location)/$downloadedFileName")
  
tar -xf $downloadedFileName -C "/azp/agent"

#Expand-Archive -Path $downloadedFileName -DestinationPath "\azp\agent"
  
try {
  Write-Host "3. Configuring Azure Pipelines agent..." -ForegroundColor Cyan
  
  #bash -c 'export AGENT_ALLOW_RUNASROOT="1"'

  $env:AGENT_ALLOW_RUNASROOT = "1"

  ./config.sh --unattended `
    --agent "$(if (Test-Path Env:AZP_AGENT_NAME) { ${Env:AZP_AGENT_NAME} } else { ${Env:computername} })" `
    --url "$(${Env:AZP_URL})" `
    --auth PAT `
    --token "$(Get-Content ${Env:AZP_TOKEN_FILE})" `
    --pool "$(if (Test-Path Env:AZP_POOL) { ${Env:AZP_POOL} } else { 'Default' })" `
    --work "$(if (Test-Path Env:AZP_WORK) { ${Env:AZP_WORK} } else { '_work' })" `
    --replace
  
  # remove the administrative token before accepting work
  Remove-Item "/../$Env:AZP_TOKEN_FILE" -Recurse -Force
  
  Write-Host "4. Running Azure Pipelines agent..." -ForegroundColor Cyan
  
  .\run.sh
}
finally {
  Write-Host "Cleanup. Removing Azure Pipelines agent..." -ForegroundColor Cyan
  
  ./config.sh remove --unattended `
    --auth PAT `
    --token "$(Get-Content ${Env:AZP_TOKEN_FILE})"
}