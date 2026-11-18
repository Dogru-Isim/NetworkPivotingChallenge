# Network Pivot Lab

This lab builds a small 3-container Docker environment so you can practice
pivoting through a compromised host to reach a target on a network you
can't access directly:

```
[attacker]  <--net-attacker-->  [compromised]  <--net-target-->  [target]
```

- **attacker** — only on `net-attacker`. Cannot reach `target` directly.
- **compromised** — dual-homed on both networks. This is your pivot point.
- **target** — only on `net-target`, running nginx on port 80.

Your goal: get `nmap` running on `attacker` to successfully scan port 80
on `target` (`10.10.2.10`), by pivoting through `compromised`.

## Prerequisites

1. **Docker Desktop** installed and running.
   - Windows: requires WSL 2 (Docker Desktop will prompt you to enable it
     if it isn't already).
   - Make sure Docker Desktop is set to **Linux containers** mode (this is
     the default).
2. That's it — no other tools to install. Docker CLI and Docker Compose
   both ship with Docker Desktop automatically.

## Files

| File | Use on |
|---|---|
| `setup_pivot_network.sh` / `teardown_pivot_network.sh` | Linux, macOS |
| `setup_pivot_network.ps1` / `teardown_pivot_network.ps1` | Windows |

Both pairs do the same thing — pick the pair that matches your OS.

## Running the scripts

### Linux / macOS (bash)

Open a terminal in the folder containing these scripts. The first time,
make them executable:

```bash
chmod +x setup_pivot_network.sh teardown_pivot_network.sh
```

**Set up the lab** — choose a difficulty mode:

```bash
./setup_pivot_network.sh easy
```

**Tear down the lab** when you're done:

```bash
./teardown_pivot_network.sh
```

### Windows (PowerShell)

Open **PowerShell** (not Command Prompt) in the folder containing these
scripts.

PowerShell blocks scripts by default. If you see an error about
"running scripts is disabled on this system," run this once per session
before trying again:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

This only affects your current PowerShell window — it doesn't change any
system-wide settings.

**Set up the lab** — choose a difficulty mode:

```powershell
.\setup_pivot_network.ps1 easy
```

**Tear down the lab** when you're done:

```powershell
.\teardown_pivot_network.ps1
```

### Setup modes (both platforms)

| Mode | What it does |
|---|---|
| `easy` | Installs and configures `nmap`, `proxychains4`, and SSH client/server on `attacker` for you |
| `hard` | Installs only `nmap` on `attacker` — you configure SSH and `proxychains4` yourself |
| `hint` | Prints a walkthrough of the commands you need, without building anything |

Setup takes a minute or two while packages install inside the containers.

## Working the lab (same on every platform)

Everything from here on happens inside `docker exec`, so the commands
are identical whether your host is Linux, macOS, or Windows.

Log into the pivot host:

```bash
docker exec -it compromised bash
```

From there, open a reverse SOCKS proxy back to `attacker`:

```bash
ssh -R 9050 -N root@10.10.1.10   # password: toor
```

In a **second** terminal (or PowerShell window), log into `attacker` and
scan through the proxy:

```bash
docker exec -it attacker bash
```

```bash
proxychains4 nmap -sT -Pn 10.10.2.10
```

If you see port 80 open, you've successfully pivoted.

## Troubleshooting

- **"docker: command not found" / not recognized** — Docker Desktop (or
  the Docker daemon on Linux) isn't running yet, or needs a restart.
  Start it and wait until it reports "Running" before trying again.
- **Linux: "Permission denied" when running `./setup_pivot_network.sh`**
  — you skipped the `chmod +x` step above, or your user isn't in the
  `docker` group (try `sudo ./setup_pivot_network.sh easy` instead).
- **Windows: script won't run at all** — see the `Set-ExecutionPolicy`
  step above.
- **Containers already exist / name conflicts** — run the teardown
  script first, then set up again.
- **Networking seems off after a failed run** — teardown, then setup;
  the scripts are designed to be re-run safely.
