#!/bin/bash
#
# setup_pivot_network.sh
#
# Builds a 3-container Docker lab for demonstrating a network pivot:
#
#   [attacker]  <--net-attacker-->  [compromised]  <--net-target-->  [target]
#   Docker A                         Docker B                         Docker C
#
# - attacker (Docker A):    only on net-attacker. Has nmap + proxychains4 + ssh client + ssh server.
# - compromised (Docker B): dual-homed on BOTH networks. Has ssh client.
# - target (Docker C):      only on net-target. Not directly reachable from attacker.
#
set -e

IMAGE="ubuntu:22.04"

NET_ATTACKER="net-attacker"
NET_TARGET="net-target"

SUBNET_ATTACKER="10.10.1.0/24"
SUBNET_TARGET="10.10.2.0/24"

IP_ATTACKER="10.10.1.10"          # attacker on net-attacker
IP_COMPROMISED_A="10.10.1.20"     # compromised on net-attacker
IP_COMPROMISED_B="10.10.2.20"     # compromised on net-target
IP_TARGET="10.10.2.10"            # target on net-target

if [ -z $1 ]; then
	echo "Use one of the 3 options while running the program:"
	echo "$0 hint"
	echo "$0 hard"
	echo "$0 easy"
	exit
fi

if [[ $1 == "hint" ]]; then
	echo ""
	echo " Try this:"
	echo "   sudo docker exec -it compromised bash"
	#echo "   ssh root@${IP_ATTACKER}            # password: toor"
	echo "   ssh -R 9050 -N root@${IP_ATTACKER}  # open a SOCKS proxy through compromised, connecting back to the attacker (password: toor)"
	echo "   (in another shell, run 'sudo docker exec -it attacker bash')"
	echo "   proxychains4 nmap -sT -Pn ${IP_TARGET}"
	echo "============================================================"
	exit
fi

echo "[*] Creating networks..."
docker network create --subnet="${SUBNET_ATTACKER}" "${NET_ATTACKER}"
docker network create --subnet="${SUBNET_TARGET}" "${NET_TARGET}"

echo "[*] Starting containers..."
docker run -dit --name attacker --hostname attacker \
  --network "${NET_ATTACKER}" --ip "${IP_ATTACKER}" \
  "${IMAGE}" sleep infinity

docker run -dit --name compromised --hostname compromised \
  --network "${NET_ATTACKER}" --ip "${IP_COMPROMISED_A}" \
  "${IMAGE}" sleep infinity

docker run -dit --name target --hostname target \
  --network "${NET_TARGET}" --ip "${IP_TARGET}" \
  "${IMAGE}" sleep infinity

echo "[*] Making 'compromised' dual-homed (joining it to net-target as well)..."
docker network connect --ip "${IP_COMPROMISED_B}" "${NET_TARGET}" compromised

if [[ $1 == "easy" ]]; then
	echo "[*] Installing tools on attacker (nmap, proxychains4, ssh client, ssh server)..."
	docker exec attacker bash -c "
	  apt-get update -qq &&
	  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
	    nmap vim curl proxychains4 openssh-client iputils-ping iproute2 openssh-server >/dev/null
	  mkdir -p /var/run/sshd &&
	  echo 'root:toor' | chpasswd &&
	  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config &&
	  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config &&
	  service ssh start
	"

fi

if [[ $1 == "hard" ]]; then
	echo "[*] Installing tools on attacker (nmap, proxychains4, ssh client, ssh server)..."
	echo "[ WARNING ] This is hard mode, you need to install and configure SSH Server, Client, and proxychains4"
	docker exec attacker bash -c "
	  apt-get update -qq &&
	  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
	    nmap vim curl iputils-ping iproute2 >/dev/null
	"
fi


echo "[*] Installing tools on compromised (ssh client and others)..."
docker exec compromised bash -c "
  apt-get update -qq &&
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    openssh-client iputils-ping iproute2 sudo >/dev/null
"

echo "[*] Installing a target service on target (nginx, so there's something to scan/reach)..."
docker exec target bash -c "
  apt-get update -qq &&
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    nginx iputils-ping iproute2 >/dev/null &&
  service nginx start
"

echo ""
echo "============================================================"
echo " Setup complete."
echo "============================================================"
echo " attacker     : ${IP_ATTACKER}        (net-attacker only)"
echo " compromised  : ${IP_COMPROMISED_A}   (net-attacker)"
echo "                ${IP_COMPROMISED_B}   (net-target)"
echo " target       : ${IP_TARGET}          (net-target only)"
echo " attacker CANNOT reach target directly (different networks)."
echo " compromised CAN reach both -- it's the pivot point."
echo ""


echo " To log into attacker machine, run this: sudo docker exec -it attacker bash"
echo " Remember, you compromised the 'pivot' machine. So run this to log in to the pivot: sudo docker exec -it compromised bash"
echo " Your goal is to run nmap against the port 80 on IP 10.10.2.10"
