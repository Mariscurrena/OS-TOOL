# OSTOOL

**OSTOOL** is a lightweight Bash-based network scanner that detects all devices in your local network and attempts to guess their operating systems by analyzing the Time-To-Live (TTL) value in ICMP (ping) responses.

### 🔍 Features

- Scans your local network using `arp-scan`
- Automatically pings all detected IPs
- Guesses operating system based on TTL:
  - `ttl=128` → Windows
  - `ttl=64` → Linux / macOS
  - `ttl=254` → Solaris
- Groups and displays devices by OS
- Detects unreachable hosts
- Includes a colorful ASCII banner
- CLI flags for interface and color control

### 🛠️ Requirements

- Linux system
- `arp-scan` (`sudo apt install arp-scan`)
- `ip` command (usually available by default via `iproute2`)
- `ping` command

### 🚀 Usage

```bash
chmod +x ostool
./ostool -I <interface>