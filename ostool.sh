#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# OSTOOL - by Angel Mariscurrena.
# ----------------------------

print_banner() {
  COLORED=${COLORED:-1}
  if [ "$COLORED" -eq 1 ]; then
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    NC='\033[0m'
  else
    CYAN='' ; GREEN='' ; NC=''
  fi

  if [ "$COLORED" -eq 1 ]; then
    printf "%b\n" "${CYAN}"
  fi
  cat <<'EOF'
   ____   _____ _______  ____   ____   _      
  / __ \ / ____|__   __|/ __ \ / __ \ | |     
 | |  | | (___    | |  | |  | | |  | || |     
 | |  | |\___ \   | |  | |  | | |  | || |     
 | |__| |____) |  | |  | |__| | |__| || |___  
  \____/|_____/   |_|   \____/ \____/ |_____| 
                                              
EOF
  if [ "$COLORED" -eq 1 ]; then
    printf "%b\n" "${NC}"
  fi
  echo -e "${GREEN}OSTOOL - Local network IP detection and OS-guessing by TTL${NC}"
  echo -e "${CYAN}Author: Angel Mariscurrena${NC}\n"
  echo "Starting scan..."
  echo
}

### Usage method
usage() {
  cat <<EOF
Usage: $0 -I <interface>
  -I <interface>   Interface to use (e.g. wlan0)
  -h               Show this help
  -n               No colors in banner/output
EOF
  exit 2
}

### Options
COLORED=1
iface=""
while getopts ":I:h" opt; do
  case "$opt" in
    I) iface="$OPTARG" ;;
    h) usage ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

### Banner
print_banner

### Validates if an interface was submitted
if [ -z "${iface}" ]; then
  echo "You must provide an interface with -I" >&2
  usage
fi

### Checks if arp-scan is installed
if ! command -v arp-scan >/dev/null 2>&1; then
  echo "arp-scan is not installed. Install it (e.g. on Debian/Ubuntu: sudo apt install arp-scan)" >&2
  exit 3
fi

### Checks if interface is available or not
if ! ip link show "$iface" >/dev/null 2>&1; then
  echo "That interface is not available"
  exit 4
fi

### Executes ARP-SCAN and saves command output on variable arp_output
echo "Running: sudo arp-scan -I ${iface} --localnet"
arp_output=$(sudo arp-scan -I "$iface" --localnet 2>/dev/null || true)

### Extracts IPs using regex
ips=$(printf "%s\n" "$arp_output" | awk '
  function valid(ip){
    return (ip ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/)
  }
  {
    for(i=1;i<=NF;i++){
      if(valid($i)) { print $i }
    }
  }' | sort -u)

### Validates if any IP was found
if [ -z "$ips" ]; then
  echo "No IPs found by arp-scan."
  exit 0
fi

### Arrays for catalogue IPs based on their ttl code
windows_ips=()
linux_mac_ips=()
solaris_ips=()
unknown_ips=()
unreachable_ips=()

### get ttl function from ping IPs
get_ttl() {
  local ip=$1
  local out ttl
  if out=$(ping -c 1 -W 1 "$ip" 2>/dev/null); then
    ttl=$(printf "%s\n" "$out" | grep -o -i 'ttl=[0-9]\+' | head -n1 | cut -d= -f2 || true)
    printf "%s" "$ttl"
    return 0
  else
    ### Fail if host is unreacheable
    return 1
  fi
}

### Iteration
while IFS= read -r ip; do
  [ -z "$ip" ] && continue
  if ttl=$(get_ttl "$ip"); then
    ### If ttl empty is unknown
    if [ -z "$ttl" ]; then
      unknown_ips+=("$ip (no ttl)")
      echo "  $ip -> ttl: (none) => Unknown"
      continue
    fi

    case "$ttl" in
      128) windows_ips+=("$ip"); echo "  $ip -> ttl: $ttl => Windows" ;;
      64)  linux_mac_ips+=("$ip"); echo "  $ip -> ttl: $ttl => Linux/MacOS" ;;
      254) solaris_ips+=("$ip"); echo "  $ip -> ttl: $ttl => Solaris" ;;
      *)    unknown_ips+=("$ip (ttl=$ttl)"); echo "  $ip -> ttl: $ttl => Unknown/Other" ;;
    esac
  else
    unreachable_ips+=("$ip")
    echo "  $ip -> unreachable"
  fi
done <<< "$ips"

### Print Results
echo
echo "===== Summary grouped by possible OS ====="
echo

### Windows OS
if [ ${#windows_ips[@]} -gt 0 ]; then
  echo "Windows (ttl=128):"
  for x in "${windows_ips[@]}"; do printf "  %s\n" "$x"; done
  echo
fi

### GNU/LINUX Based OS
if [ ${#linux_mac_ips[@]} -gt 0 ]; then
  echo "Linux / MacOS (ttl=64):"
  for x in "${linux_mac_ips[@]}"; do printf "  %s\n" "$x"; done
  echo
fi

### Solaris OS
if [ ${#solaris_ips[@]} -gt 0 ]; then
  echo "Solaris (ttl=254):"
  for x in "${solaris_ips[@]}"; do printf "  %s\n" "$x"; done
  echo
fi

### Unknown OS
if [ ${#unknown_ips[@]} -gt 0 ]; then
  echo "Unknown / Other TTLs:"
  for x in "${unknown_ips[@]}"; do printf "  %s\n" "$x"; done
  echo
fi

### Unreacheable IPs
if [ ${#unreachable_ips[@]} -gt 0 ]; then
  echo "Unreachable (no ping reply):"
  for x in "${unreachable_ips[@]}"; do printf "  %s\n" "$x"; done
  echo
fi

echo "All Done."
