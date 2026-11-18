<#
.SYNOPSIS
    teardown_lab.ps1

    Removes everything created by setup_pivot_network.ps1:
      - attacker, compromised, target containers
      - net-attacker, net-target networks

.USAGE
    .\teardown_pivot_network.ps1
#>

$NET_ATTACKER = "net-attacker"
$NET_TARGET   = "net-target"

Write-Host "[*] Removing containers..."
docker rm -f attacker compromised target 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "    (some containers may not have existed -- continuing)" }

Write-Host "[*] Removing networks..."
docker network rm $NET_ATTACKER $NET_TARGET 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "    (some networks may not have existed -- continuing)" }

Write-Host "[*] Teardown complete."
