# Create external network and start Wazuh, Shuffle and forwarder stacks
$networkName = 'siem-net'

# Use script directory as base so the script works when called from any cwd
$base = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Create network if not exists
$exists = docker network ls --filter name=^$networkName$ --format "{{.Name}}"
if (-not $exists) {
    Write-Host "Creating docker network '$networkName'..."
    docker network create $networkName
} else {
    Write-Host "Docker network '$networkName' already exists."
}

# Start Wazuh stack
$repoRoot = Split-Path -Parent $base
# Prefer the repository submodule single-node compose if present
$officialCompose = Join-Path $repoRoot "wazuh\config\wazuh-docker\single-node\docker-compose.yml"
$localCompose = Join-Path $base "wazuh\docker-compose.yml"
$wazuhCompose = if (Test-Path $officialCompose) { $officialCompose } else { $localCompose }
if (Test-Path $wazuhCompose) {
    Write-Host "Starting Wazuh stack using $wazuhCompose ..."
    docker-compose -f $wazuhCompose up -d
} else {
    Write-Host "Wazuh compose not found at $wazuhCompose. Please check path."
}

# Ensure containers from the Wazuh compose are attached to the shared 'siem-net' network
Write-Host "Connecting Wazuh containers to network '$networkName' (so forwarder and Shuffle can reach them)..."
# Try to find containers by compose project label (single-node) or by name prefix
$projectName = 'single-node'
$containers = docker ps --filter "label=com.docker.compose.project=$projectName" --format "{{.Names}}"
if (-not $containers) {
    # fallback: find containers with name starting with 'single-node-wazuh' or 'wazuh'
    $containers = docker ps --format "{{.Names}}" | Where-Object { $_ -like "*wazuh*" }
}
foreach ($c in $containers) {
    if (-not [string]::IsNullOrEmpty($c)) {
        try {
            docker network connect $networkName $c 2>$null
            Write-Host "Connected $c to $networkName"
        } catch {
            Write-Host "Could not connect $c to $networkName (it may already be connected)"
        }
    }
}

# Start Shuffle stack (ensure path exists)
$shuffleDir = Join-Path (Split-Path -Parent $base) "shuffle\Shuffle"
if (Test-Path $shuffleDir) {
    Write-Host "Starting Shuffle stack from $shuffleDir ..."
    Push-Location $shuffleDir
    docker-compose up -d
    Pop-Location
} else {
    Write-Host "Shuffle directory not found at $shuffleDir. If Shuffle isn't cloned at 'shuffle/Shuffle' please clone it or adjust paths."
}

# Start forwarder (optional) if present
$forwarderDir = Join-Path $base "wazuh-forwarder"
$forwarderCompose = Join-Path $forwarderDir "docker-compose.yml"
if (Test-Path $forwarderCompose) {
    Write-Host "Starting Wazuh forwarder from $forwarderCompose ..."
    # Wait until Wazuh API is reachable (port 55000) before starting forwarder
    $wazuhApi = "http://wazuh-manager:55000"
    $maxTries = 30
    $try = 0
    while ($try -lt $maxTries) {
        try {
            $r = Invoke-WebRequest -Uri $wazuhApi -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            Write-Host "Wazuh API reachable at $wazuhApi"
            break
        } catch {
            Write-Host "Waiting for Wazuh API... ($($try+1)/$maxTries)"
            Start-Sleep -Seconds 5
            $try++
        }
    }
    if ($try -ge $maxTries) {
        Write-Host "Wazuh API not reachable after waiting. Starting forwarder anyway."
    }
    docker-compose -f $forwarderCompose up -d
} else {
    Write-Host "Forwarder compose not found at $forwarderCompose. You can start the forwarder manually in deploy/wazuh-forwarder."
}

Write-Host "Done."
