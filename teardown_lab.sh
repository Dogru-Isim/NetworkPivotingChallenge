#!/bin/bash
#
# teardown_lab.sh
#
# Removes everything created by setup_pivot_network.sh:
#   - attacker, compromised, target containers
#   - net-attacker, net-target networks
#
set -e
 
NET_ATTACKER="net-attacker"
NET_TARGET="net-target"
 
echo "[*] Removing containers..."
docker rm -f attacker compromised target 2>/dev/null || true
 
echo "[*] Removing networks..."
docker network rm "${NET_ATTACKER}" "${NET_TARGET}" 2>/dev/null || true
 
echo "[*] Teardown complete."
