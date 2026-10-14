# 📄 README.md

<!--
  MITM Sniper — README
  Author: Alteriza
  Contributors (AI assistants): DeepSeek (V2.0+), Gemini (V1.0)
-->

<div align="center">

# 🎯 MITM Sniper

**Interactive ARP Spoof + Full-Detail Packet Capture + Rich Web Viewer**

[![Platform](https://img.shields.io/badge/platform-Linux-blue?style=flat-square)](#requirements)
[![Tested On](https://img.shields.io/badge/tested%20on-Arch%20Linux-1793d1?style=flat-square&logo=arch-linux)](#requirements)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnu-bash)](#)
[![Python](https://img.shields.io/badge/python-3.8%2B-3776AB?style=flat-square&logo=python)](#)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](#license)

*Built for network forensics, security research, and CTF/lab environments.*

</div>

---

## 📑 Table of Contents

- [🌐 English Documentation](#-english-documentation)
  - [What is MITM Sniper?](#what-is-mitm-sniper)
  - [Features](#features)
  - [Architecture](#architecture)
  - [Requirements](#requirements)
  - [Installation](#installation)
  - [Usage](#usage)
  - [The Viewer](#the-viewer)
  - [JSON Output Format](#json-output-format)
  - [Troubleshooting](#troubleshooting)
  - [Project Structure](#project-structure)
  - [Legal Disclaimer](#legal-disclaimer)
  - [Credits](#credits)
- [🇮🇩 Dokumentasi Bahasa Indonesia](#-dokumentasi-bahasa-indonesia)
  - [Apa itu MITM Sniper?](#apa-itu-mitm-sniper)
  - [Fitur](#fitur)
  - [Arsitektur](#arsitektur)
  - [Kebutuhan](#kebutuhan)
  - [Instalasi](#instalasi)
  - [Cara Pakai](#cara-pakai)
  - [Viewer](#viewer)
  - [Format Output JSON](#format-output-json)
  - [Troubleshooting](#troubleshooting-1)
  - [Struktur Proyek](#struktur-proyek)
  - [Disclaimer Legal](#disclaimer-legal)
  - [Kredit](#kredit)
- [📜 License](#-license)

---

# 🌐 English Documentation

## What is MITM Sniper?

**MITM Sniper** is a Bash-based tool that combines three core components into one workflow:

1. **[bettercap](https://www.bettercap.org/)** — performs ARP spoofing (MITM) against a target device or an entire subnet.
2. **[tshark](https://www.wireshark.org/docs/man-pages/tshark.html)** (Wireshark CLI) — captures packets to a `.pcap` file with **no size cap** and **no field truncation**.
3. **A custom Python decoder + web viewer** — converts the pcap into a rich, filterable JSON file and serves an interactive HTML viewer at `http://localhost:4040`.

The goal: give security researchers, students, and network engineers a **one-command** way to perform authorized MITM tests and inspect every packet down to the raw payload (with automatic hex → text decoding).

---

## Features

| Category | Feature |
|---|---|
| **Attack modes** | Single-target ARP spoof (one IP) or whole-subnet spoof (all devices behind the gateway). |
| **Capture engine** | Full pcap capture via `tshark` with no packet cap and no payload truncation. |
| **Live UI** | `bettercap` runs in a separate `xterm` window in **interactive mode** so you can see live events. |
| **Rich decoding** | 43 packet fields extracted per frame: Ethernet, IP, TCP, UDP, HTTP, DNS, TLS, payload. |
| **Payload decoding** | Automatic hex → UTF-8 / Latin-1 decode with a *printable-ratio* flag. View payload as Text, ASCII, Hexdump, or raw Hex. |
| **Web viewer** | Dark-theme HTML viewer with 5 tabs: Packets, HTTP, DNS, TLS SNI, Streams. Click any row for a full detail panel. |
| **Copy / download** | Copy HTTP headers, copy payload as text / ASCII / hex, download raw payload as `.bin`. |
| **Robust** | Graceful `tshark` shutdown (SIGINT + wait) so pcap buffers always flush. Fallback to `/var/tmp` if the script directory is not writable by the `wireshark` system user. |
| **Standalone decoder** | `pcap2json.py` can be run on any existing `.pcap` file — no re-capture needed. |

---

## Architecture

```
┌────────────────┐    ┌────────────────┐    ┌──────────────────┐
│   mitm.sh      │───▶│   bettercap    │───▶│   ARP spoof      │
│ (orchestrator) │    │  (xterm, UI)   │    │ traffic via us   │
│                │    └────────────────┘    └──────────────────┘
│                │
│                │───▶┌────────────────┐    ┌──────────────────┐
│                │    │     tshark     │───▶│  capture.pcap    │
│                │    └────────────────┘    └────────┬─────────┘
│                │                                   │
│                │───▶┌────────────────┐◀──────────────┘
│                │    │  pcap2json.py  │
│                │    └────────┬───────┘
│                │             ▼
│                │    ┌────────────────┐
│                │    │  capture.json  │
│                │    └────────┬───────┘
│                │             ▼
│                │───▶┌────────────────┐    ┌──────────────────┐
└────────────────┘    │  viewer.html   │───▶│ python http.srv  │
                      └────────────────┘    │ localhost:4040   │
                                            └──────────────────┘
```

**Three files, one workflow:**

| File | Role |
|---|---|
| `mitm.sh` | Main orchestrator — user input, ARP spoof, capture, cleanup. |
| `pcap2json.py` | Standalone decoder — pcap → rich JSON via `subprocess` calling `tshark`. |
| `viewer.html` | Standalone web UI — reads `capture.json` and renders the interactive viewer. |

---

## Requirements

### Tested Platform

- ✅ **Arch Linux** (rolling, kernel 6.x, tested with `bettercap 2.32+`, `tshark 4.x`)
- ⚠️ **Other distros (Debian/Ubuntu/Fedora/Kali/Parrot)**: should work but **not tested**. Package names differ — see the table below.
- ❌ **macOS / Windows**: **NOT tested**, likely broken due to different interface naming and the `xterm` dependency.

> **Disclaimer:** The author only validates this tool on Arch Linux. If you run it on another distro, you accept the risk — please open an issue with your distro + version if you find a bug.

### Required Packages

| Tool | Why | Arch package | Debian/Ubuntu | Fedora |
|---|---|---|---|---|
| `bettercap` | ARP spoof engine | `bettercap` | `bettercap` | `bettercap` |
| `tshark` | Packet capture CLI | `wireshark-cli` | `tshark` | `wireshark-cli` |
| `xterm` | Live bettercap UI | `xterm` | `xterm` | `xterm` |
| `python3` | Decoder + HTTP server | `python` | `python3` | `python3` |
| `iproute2` | `ip`, `ss` commands | `iproute2` | `iproute2` | `iproute2` |
| `awk` | Text processing | `gawk` | `gawk` / `mawk` | `gawk` |

### Hardware / Network Requirements

- **Root privileges** (`sudo`).
- A **Wi-Fi or Ethernet interface** that supports ARP spoofing.
- The interface must be on the **same L2 network** as your target(s).
- **IP forwarding** does *not* need to be enabled manually — bettercap handles it.

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/mitm-sniper.git
cd mitm-sniper
```

### 2. Install dependencies

**Arch Linux (recommended, tested):**
```bash
sudo pacman -S bettercap wireshark-cli xterm python iproute2 gawk
```

**Debian / Ubuntu / Kali / Parrot:**
```bash
sudo apt update
sudo apt install bettercap tshark xterm python3 iproute2 gawk
```

**Fedora / RHEL:**
```bash
sudo dnf install bettercap wireshark-cli xterm python3 iproute2 gawk
```

> 💡 On distros where `bettercap` is not in the official repo, install it from source: https://www.bettercap.org/installation/

### 3. Make scripts executable

```bash
chmod +x mitm.sh pcap2json.py
```

### 4. (Optional) Add `wireshark` group permissions

If you want to run `tshark` without triggering the "drop privilege to `wireshark` user" behavior, add yourself to the `wireshark` group:

```bash
sudo usermod -aG wireshark "$USER"
# log out and log back in
```

> The script already handles the missing-permission case by falling back to `/var/tmp`, so this step is optional.

---

## Usage

### Basic run

```bash
sudo ./mitm.sh
```

### Interactive flow

The script will ask you, step by step:

1. **Interface** — e.g. `wlan0`, `eth0`.
2. **Scan** — probes the LAN for 7 seconds and prints discovered hosts.
3. **Target IP** — leave **empty** to sniff the **whole subnet**, or fill in a single IP for **single-target mode**.
4. **Gateway IP** — press Enter for auto-detect via `ip route`.
5. **Confirmation** — shows a summary, press Enter to start.

Then:

- An **`xterm` window** opens with `bettercap` in interactive mode (live ARP spoof + packet sniffing).
- `tshark` captures silently in the background.
- Press **Enter** in the main terminal to stop.
- The script **restores ARP tables** automatically and moves the pcap to the script folder.
- `pcap2json.py` runs and generates `capture.json`.
- You're asked whether to open the viewer at `http://localhost:4040` (default: **Y**).

### Standalone decoder

Decode any existing pcap **without** re-running the attack:

```bash
python3 pcap2json.py capture_20260114_103045.pcap capture.json \
    [mode] [iface] [gateway] [subnet]
```

Example:
```bash
python3 pcap2json.py capture.pcap capture.json SINGLE wlan0 192.168.1.1 192.168.1.0/24
```

The extra arguments are **optional** — they only populate the `meta` section of the output JSON.

### Serving the viewer manually

```bash
python3 -m http.server 4040 --bind 127.0.0.1
# then open http://localhost:4040/viewer.html
```

---

## The Viewer

Once served, open **`http://localhost:4040/viewer.html`**. The UI has:

### Top bar
- PCAP filename, capture mode, interface, total packets, total bytes, duration.

### Stat cards
- Packets, Bytes, Duration, Protocols, Unique IPs, HTTP requests, DNS queries, TLS SNI count.

### 5 tabs

| Tab | Content |
|---|---|
| 📦 **Packets** | Full packet list. Sortable by any column, filter by protocol or host, live text search. Click any row → detail panel. |
| 🌐 **HTTP** | All HTTP requests captured (method, host, URI, User-Agent, Referer, Content-Type). |
| 🔎 **DNS** | All DNS queries + source IP. |
| 🔒 **TLS** | All unique TLS SNI (server hostnames) seen in handshakes. |
| 🔀 **Streams** | TCP/UDP streams aggregated by bytes, packet count, hosts, ports. |

### Detail panel (right drawer)

Click any packet row → the right drawer slides in with:

- **Frame** — number, timestamp, length, protocol stack.
- **Ethernet** — src/dst MAC.
- **IP** — src/dst, TTL, IP protocol number.
- **Transport** — TCP (ports, flags, seq/ack, stream, data length) or UDP (ports, length, stream).
- **HTTP** — method, host, URI, full URI, status code, UA, referer, cookie, content-type, content-length, plus full request/response header lines.
- **DNS** — query name, type, A/AAAA/CNAME answers.
- **TLS** — SNI, record version, handshake type.
- **Payload** — size, detected encoding, printable ratio, then 4 tabs:
  - **Text** — auto-decoded UTF-8 / Latin-1.
  - **ASCII** — non-printables as `·`, tabs/newlines visualised.
  - **Hexdump** — classic `xxd`-style layout.
  - **Raw Hex** — the hex string as-is.
- **Copy buttons** — copy headers, payload text, payload ASCII, payload hex, or download raw payload as `.bin`.

### Keyboard

- **Esc** — close the detail drawer.

---

## JSON Output Format

```jsonc
{
  "meta": {
    "pcap_file": "capture_20260114_103045.pcap",
    "total": 15234,
    "total_bytes": 12874321,
    "duration_sec": 42.317,
    "mode": "SINGLE",              // "SINGLE" or "ALL"
    "interface": "wlan0",
    "gateway": "192.168.1.1",
    "subnet": "192.168.1.0/24",
    "generated": "2026-01-14 10:31:22"
  },
  "stats": {
    "protocols": [ {"proto": "TLSv1.2", "count": 421} ],
    "top_src":   [ {"ip": "192.168.1.5", "count": 810} ],
    "top_dst":   [ {"ip": "1.1.1.1", "count": 320} ]
  },
  "http_requests":  [ {"no": 42, "src": "...", "dst": "...", "method": "GET",
                       "host": "example.com", "uri": "/", "user_agent": "..."} ],
  "http_responses": [ {"no": 43, "src": "...", "dst": "...", "status": 200} ],
  "dns_queries":    [ {"no": 12, "src": "192.168.1.5", "name": "example.com"} ],
  "tls_snis":       [ "example.com", "cloudflare.com" ],
  "streams": [
    { "id": "TCP 0", "packets": 84, "bytes": 128743,
      "srcs": ["192.168.1.5"], "dsts": ["1.1.1.1"],
      "protos": ["TLSv1.2"], "sport": 44321, "dport": 443 }
  ],
  "packets": [
    {
      "no": 1,
      "time": 1791973584.7537,
      "len": 66,
      "protocols": "eth:ethertype:ip:tcp",
      "eth": { "src": "aa:bb:cc:dd:ee:ff", "dst": "11:22:33:44:55:66" },
      "ip":  { "src": "192.168.1.5", "dst": "8.8.8.8",
               "proto_num": 6, "ttl": 64 },
      "proto": "TCP",
      "info": "44321 → 443 [ACK] Seq=1 Ack=1 Win=61 Len=0",
      "src_port": 44321,
      "dst_port": 443,
      "tcp": { "sport": 44321, "dport": 443, "flags": "0x010",
               "seq": "1", "ack": "1", "stream": 0, "data_len": 0 },
      "http": { "method": "GET", "host": "example.com", "uri": "/",
                "user_agent": "Mozilla/5.0 …",
                "request_lines": ["GET / HTTP/1.1", "Host: example.com"] },
      "dns": { "name": "example.com", "a": ["93.184.216.34"],
               "is_response": false },
      "tls": { "sni": "example.com", "record_version": "0x0303",
               "handshake_type": "1" },
      "payload": {
        "size": 512,
        "encoding": "utf-8",       // or "latin-1" or "text"
        "utf8_valid": true,
        "printable_ratio": 0.94,
        "text": "GET / HTTP/1.1\r\nHost: …",
        "hex":  "474554202f20485454502f312e310d0a..."
      }
    }
  ]
}
```

> The JSON has **no size cap** and **no payload truncation**. For very large captures (>500 MB pcap), consider parsing the file with `jq` instead of loading it in a browser tab.

---

## Troubleshooting

### ❌ `tshark gagal start` / `Permission denied` on the pcap path

**Cause:** On Arch (and some Debian-based distros), `tshark` is set up to drop privileges to the system user `wireshark`. That user typically cannot traverse `/home/<your-user>` (which is often `0700`).

**Fix:** The script automatically falls back to `/var/tmp`. If you want to always capture to the script folder, either:
- Move the script directory outside `/home` (e.g. `/opt/mitm-sniper`), **or**
- Grant access:
  ```bash
  sudo setfacl -m u:wireshark:x /home/<your-user>
  sudo setfacl -m u:wireshark:x /home/<your-user>/<path-to-script>
  sudo setfacl -m u:wireshark:rwx /home/<your-user>/<path-to-script>
  ```

### ❌ Port `4040` already in use

Kill whatever is holding the port:
```bash
sudo ss -tlnp | grep :4040
sudo kill <PID>
```
Or change `HTTP_PORT` inside `mitm.sh`.

### ❌ `xterm` window is empty / closes immediately

- Make sure `xterm` is installed (`sudo pacman -S xterm`).
- If `bettercap` exited with an error, the window will `-hold` so you can read the message.

### ❌ Viewer shows no packets

- Check that `capture.json` was generated (`ls -la capture.json`).
- Open the browser dev console (F12) and look for a fetch error.
- Make sure you're accessing the viewer via `http://localhost:4040/viewer.html` (not `file://`).

### ❌ HTTPS traffic shows no payload

This is **expected**. TLS encrypts the payload. You will only see:
- TLS SNI (the target hostname) — visible in the TLS handshake.
- Encrypted application data length and timing.

To see HTTPS plaintext, you'd need to install a CA on the target or use a TLS-terminating proxy — **out of scope** for this tool.

### ❌ `bettercap` fails to bind to the interface

Some Wi-Fi drivers require monitor mode. Try:
```bash
sudo ip link set wlan0 down
sudo iw wlan0 set monitor control
sudo ip link set wlan0 up
```
…or use `airmon-ng`. **Not all cards support monitor mode.**

---

## Project Structure

```
mitm-sniper/
├── mitm.sh          # Main orchestrator (bash)
├── pcap2json.py     # Standalone pcap → JSON decoder
├── viewer.html      # Standalone web viewer
├── README.md        # This file
└── LICENSE          # MIT
```

Generated at runtime (not committed):

```
├── capture_YYYYMMDD_HHMMSS.pcap   # Raw packet capture
├── capture.json                   # Decoded packet data
├── tshark.log                     # tshark stderr (for debugging)
└── .pkts.tsv                      # Temp file (auto-deleted)
```

Add to `.gitignore`:
```
*.pcap
capture.json
tshark.log
.pkts.tsv
```

---

## Legal Disclaimer

> ⚠️ **FOR AUTHORIZED SECURITY TESTING ONLY.**
>
> ARP spoofing is a man-in-the-middle attack. Performing it on networks **you do not own or have explicit written permission to test** is illegal in most jurisdictions and can result in criminal charges.
>
> **Acceptable uses:**
> - Your own home / lab network.
> - Networks where you have a signed penetration testing authorization.
> - CTF / hack-the-box style environments.
> - Educational settings with instructor approval.
>
> **Not acceptable:**
> - Public Wi-Fi (cafés, airports, hotels).
> - Corporate networks without written permission.
> - Any network belonging to someone else.
>
> The author (**Alteriza**) and the AI assistants (**DeepSeek**, **Gemini**) are **not responsible** for any misuse of this tool. You alone are responsible for your actions. Use it ethically.

---

## Credits

| Role | Name |
|---|---|
| **Author / Maintainer** | **Alteriza** |
| **AI Assistant (V2.0+)** | **DeepSeek** — refactor, rich viewer, JSON pipeline, robustness fixes. |
| **AI Assistant (V1.0)** | **Gemini** — original proof-of-concept script that inspired the current architecture. |
| **Core dependencies** | [bettercap](https://www.bettercap.org/), [Wireshark/tshark](https://www.wireshark.org/) |

Special thanks to the open-source community behind `bettercap`, `tshark`, and the countless ARP spoof tutorials that made this project possible.

---

# 🇮🇩 Dokumentasi Bahasa Indonesia

## Apa itu MITM Sniper?

**MITM Sniper** adalah tool berbasis Bash yang menggabungkan tiga komponen dalam satu alur kerja:

1. **[bettercap](https://www.bettercap.org/)** — melakukan ARP spoofing (MITM) ke satu target atau seluruh subnet.
2. **[tshark](https://www.wireshark.org/docs/man-pages/tshark.html)** (Wireshark CLI) — menangkap paket ke file `.pcap` **tanpa batas ukuran** dan **tanpa pemotongan field**.
3. **Decoder Python + web viewer custom** — mengubah pcap menjadi JSON yang kaya dan menyajikan viewer HTML interaktif di `http://localhost:4040`.

Tujuan: memberi pentester, mahasiswa, dan network engineer cara **satu perintah** untuk melakukan uji MITM (yang sah) dan memeriksa setiap paket hingga payload mentah (dengan auto-decode hex → teks).

---

## Fitur

| Kategori | Fitur |
|---|---|
| **Mode serangan** | ARP spoof single-target (satu IP) atau whole-subnet (semua device di belakang gateway). |
| **Mesin capture** | Capture pcap penuh via `tshark` tanpa cap paket dan tanpa pemotongan payload. |
| **UI Live** | `bettercap` jalan di jendela `xterm` terpisah dalam **mode interaktif** — jadi bisa lihat event live. |
| **Decode kaya** | 43 field per frame: Ethernet, IP, TCP, UDP, HTTP, DNS, TLS, payload. |
| **Decode payload** | Auto-decode hex → UTF-8 / Latin-1 dengan flag *printable-ratio*. View payload sebagai Text, ASCII, Hexdump, atau Hex mentah. |
| **Web viewer** | Viewer HTML dark-theme dengan 5 tab: Packets, HTTP, DNS, TLS SNI, Streams. Klik row manapun → detail panel lengkap. |
| **Copy / download** | Copy HTTP headers, copy payload sebagai text / ASCII / hex, download raw payload sebagai `.bin`. |
| **Robust** | Graceful shutdown `tshark` (SIGINT + wait) sehingga buffer pcap selalu ke-flush. Fallback ke `/var/tmp` kalau folder script tidak writable oleh user `wireshark`. |
| **Decoder standalone** | `pcap2json.py` bisa dijalankan ke file `.pcap` lama — tanpa perlu re-capture. |

---

## Arsitektur

```
┌────────────────┐    ┌────────────────┐    ┌──────────────────┐
│   mitm.sh      │───▶│   bettercap    │───▶│   ARP spoof      │
│ (orchestrator) │    │  (xterm, UI)   │    │ traffic lewat    │
│                │    └────────────────┘    └──────────────────┘
│                │
│                │───▶┌────────────────┐    ┌──────────────────┐
│                │    │     tshark     │───▶│  capture.pcap    │
│                │    └────────────────┘    └────────┬─────────┘
│                │                                   │
│                │───▶┌────────────────┐◀──────────────┘
│                │    │  pcap2json.py  │
│                │    └────────┬───────┘
│                │             ▼
│                │    ┌────────────────┐
│                │    │  capture.json  │
│                │    └────────┬───────┘
│                │             ▼
│                │───▶┌────────────────┐    ┌──────────────────┐
└────────────────┘    │  viewer.html   │───▶│ python http.srv  │
                      └────────────────┘    │ localhost:4040   │
                                            └──────────────────┘
```

**Tiga file, satu alur:**

| File | Peran |
|---|---|
| `mitm.sh` | Orchestrator utama — input user, ARP spoof, capture, cleanup. |
| `pcap2json.py` | Decoder standalone — pcap → JSON kaya via `subprocess` panggil `tshark`. |
| `viewer.html` | Web UI standalone — baca `capture.json` dan render viewer interaktif. |

---

## Kebutuhan

### Platform yang Sudah Ditest

- ✅ **Arch Linux** (rolling, kernel 6.x, dites dengan `bettercap 2.32+`, `tshark 4.x`)
- ⚠️ **Distro lain (Debian/Ubuntu/Fedora/Kali/Parrot)**: secara teori jalan tapi **belum dites**. Nama paket beda — lihat tabel di bawah.
- ❌ **macOS / Windows**: **BELUM dites**, kemungkinan besar gagal karena perbedaan penamaan interface dan dependency `xterm`.

> **Disclaimer:** Author hanya memvalidasi tool ini di Arch Linux. Kalau lo jalanin di distro lain, lo terima risikonya — silakan buka issue dengan distro + versi kalau nemu bug.

### Paket yang Dibutuhkan

| Tool | Kenapa | Paket Arch | Debian/Ubuntu | Fedora |
|---|---|---|---|---|
| `bettercap` | Mesin ARP spoof | `bettercap` | `bettercap` | `bettercap` |
| `tshark` | CLI capture paket | `wireshark-cli` | `tshark` | `wireshark-cli` |
| `xterm` | UI live bettercap | `xterm` | `xterm` | `xterm` |
| `python3` | Decoder + HTTP server | `python` | `python3` | `python3` |
| `iproute2` | Command `ip`, `ss` | `iproute2` | `iproute2` | `iproute2` |
| `awk` | Text processing | `gawk` | `gawk` / `mawk` | `gawk` |

### Kebutuhan Hardware / Jaringan

- **Hak akses root** (`sudo`).
- Interface **Wi-Fi atau Ethernet** yang mendukung ARP spoofing.
- Interface harus di **jaringan L2 yang sama** dengan target.
- **IP forwarding** tidak perlu diaktifkan manual — bettercap yang handle.

---

## Instalasi

### 1. Clone repo

```bash
git clone https://github.com/<username-lo>/mitm-sniper.git
cd mitm-sniper
```

### 2. Install dependency

**Arch Linux (recommended, sudah dites):**
```bash
sudo pacman -S bettercap wireshark-cli xterm python iproute2 gawk
```

**Debian / Ubuntu / Kali / Parrot:**
```bash
sudo apt update
sudo apt install bettercap tshark xterm python3 iproute2 gawk
```

**Fedora / RHEL:**
```bash
sudo dnf install bettercap wireshark-cli xterm python3 iproute2 gawk
```

> 💡 Kalau `bettercap` ga ada di repo resmi, install dari source: https://www.bettercap.org/installation/

### 3. Kasih permission executable

```bash
chmod +x mitm.sh pcap2json.py
```

### 4. (Opsional) Tambah ke grup `wireshark`

Kalau mau `tshark` jalan tanpa trigger "drop privilege ke user `wireshark`":

```bash
sudo usermod -aG wireshark "$USER"
# log out lalu login lagi
```

> Script udah handle kasus permission ini dengan fallback ke `/var/tmp`, jadi step ini opsional.

---

## Cara Pakai

### Jalanin dasar

```bash
sudo ./mitm.sh
```

### Alur interaktif

Script bakal nanya step by step:

1. **Interface** — mis. `wlan0`, `eth0`.
2. **Scan** — probe LAN 7 detik, print host yang ketemu.
3. **IP Target** — **kosongkan** untuk sniff **seluruh subnet**, atau isi 1 IP untuk **single-target**.
4. **IP Gateway** — Enter untuk auto-detect via `ip route`.
5. **Konfirmasi** — tampil summary, Enter untuk mulai.

Lalu:

- **Jendela `xterm`** kebuka dengan `bettercap` di mode interaktif (ARP spoof + sniff live).
- `tshark` capture di background.
- Tekan **Enter** di terminal utama untuk stop.
- Script **restore ARP table** otomatis dan pindahin pcap ke folder script.
- `pcap2json.py` jalan → generate `capture.json`.
- Ditanya apakah mau buka viewer di `http://localhost:4040` (default: **Y**).

### Decoder standalone

Decode pcap lama **tanpa** re-run serangan:

```bash
python3 pcap2json.py capture_20260114_103045.pcap capture.json \
    [mode] [iface] [gateway] [subnet]
```

Contoh:
```bash
python3 pcap2json.py capture.pcap capture.json SINGLE wlan0 192.168.1.1 192.168.1.0/24
```

Argumen tambahan **opsional** — cuma ngisi section `meta` di JSON.

### Serve viewer manual

```bash
python3 -m http.server 4040 --bind 127.0.0.1
# buka http://localhost:4040/viewer.html
```

---

## Viewer

Setelah di-serve, buka **`http://localhost:4040/viewer.html`**. UI-nya ada:

### Top bar
- Nama file PCAP, mode capture, interface, total paket, total byte, durasi.

### Stat cards
- Packets, Bytes, Duration, Protocols, Unique IPs, HTTP requests, DNS queries, TLS SNI count.

### 5 tab

| Tab | Isi |
|---|---|
| 📦 **Packets** | List paket lengkap. Bisa sort per kolom, filter per protocol atau host, live text search. Klik row manapun → detail panel. |
| 🌐 **HTTP** | Semua HTTP request (method, host, URI, User-Agent, Referer, Content-Type). |
| 🔎 **DNS** | Semua DNS query + IP sumber. |
| 🔒 **TLS** | Semua SNI unik (hostname) dari handshake TLS. |
| 🔀 **Streams** | TCP/UDP stream digabung, diurut paket & byte, host, port. |

### Detail panel (drawer kanan)

Klik row paket → drawer kanan slide in:

- **Frame** — nomor, timestamp, panjang, protocol stack.
- **Ethernet** — src/dst MAC.
- **IP** — src/dst, TTL, IP protocol number.
- **Transport** — TCP (port, flags, seq/ack, stream, data length) atau UDP (port, length, stream).
- **HTTP** — method, host, URI, full URI, status, UA, referer, cookie, content-type, content-length, plus full request/response header lines.
- **DNS** — query name, type, jawaban A/AAAA/CNAME.
- **TLS** — SNI, record version, handshake type.
- **Payload** — size, encoding terdeteksi, printable ratio, lalu 4 sub-tab:
  - **Text** — auto-decode UTF-8 / Latin-1.
  - **ASCII** — non-printable jadi `·`, tab/newline divisualisasi.
  - **Hexdump** — layout klasik `xxd`.
  - **Raw Hex** — string hex apa adanya.
- **Tombol copy** — copy headers, payload text, payload ASCII, payload hex, atau download raw payload sebagai `.bin`.

### Keyboard

- **Esc** — tutup detail drawer.

---

## Format Output JSON

Sama seperti contoh di bagian English di atas. Poin penting:

- Field `meta` berisi info capture (file, total, bytes, durasi, mode, interface, gateway, subnet).
- Field `stats` berisi aggregate: protocol counter, top 20 source & destination IP.
- Field `http_requests`, `http_responses`, `dns_queries`, `tls_snis`, `streams` adalah versi ringkas untuk panel tab.
- Field `packets` berisi **semua paket lengkap** dengan struktur nested (eth / ip / tcp / udp / http / dns / tls / payload).

> JSON **tanpa cap size** dan **tanpa pemotongan payload**. Untuk capture sangat besar (>500 MB pcap), pertimbangkan parse pakai `jq` daripada load di browser.

---

## Troubleshooting

### ❌ `tshark gagal start` / `Permission denied` ke path pcap

**Penyebab:** Di Arch (dan beberapa distro Debian-based), `tshark` di-setup untuk drop privilege ke system user `wireshark`. User itu biasanya tidak bisa traverse `/home/<user-lo>` (yang sering `0700`).

**Fix:** Script otomatis fallback ke `/var/tmp`. Kalau mau selalu capture ke folder script:
- Pindahkan folder script ke luar `/home` (mis. `/opt/mitm-sniper`), **atau**
- Kasih akses:
  ```bash
  sudo setfacl -m u:wireshark:x /home/<user-lo>
  sudo setfacl -m u:wireshark:x /home/<user-lo>/<path-ke-script>
  sudo setfacl -m u:wireshark:rwx /home/<user-lo>/<path-ke-script>
  ```

### ❌ Port `4040` sedang dipakai

Bunuh yang pegang port:
```bash
sudo ss -tlnp | grep :4040
sudo kill <PID>
```
Atau ganti `HTTP_PORT` di dalam `mitm.sh`.

### ❌ Jendela `xterm` kosong / langsung nutup

- Pastikan `xterm` terinstall (`sudo pacman -S xterm`).
- Kalau `bettercap` exit karena error, window akan `-hold` biar lo bisa baca pesannya.

### ❌ Viewer ga nampilin paket

- Cek `capture.json` udah ke-generate (`ls -la capture.json`).
- Buka browser dev console (F12), liat error fetch.
- Pastikan akses viewer via `http://localhost:4040/viewer.html` (bukan `file://`).

### ❌ Traffic HTTPS ga ada payload-nya

Ini **wajar**. TLS mengenkripsi payload. Lo cuma akan lihat:
- TLS SNI (hostname target) — kelihatan di handshake TLS.
- Panjang & timing application data (terenkripsi).

Buat lihat plaintext HTTPS, lo perlu install CA di target atau pakai TLS-terminating proxy — **di luar scope** tool ini.

### ❌ `bettercap` gagal bind ke interface

Beberapa driver Wi-Fi butuh monitor mode. Coba:
```bash
sudo ip link set wlan0 down
sudo iw wlan0 set monitor control
sudo ip link set wlan0 up
```
…atau pakai `airmon-ng`. **Ga semua kartu dukung monitor mode.**

---

## Struktur Proyek

```
mitm-sniper/
├── mitm.sh          # Orchestrator utama (bash)
├── pcap2json.py     # Decoder pcap → JSON standalone
├── viewer.html      # Web viewer standalone
├── README.md        # File ini
└── LICENSE          # MIT
```

Generated saat runtime (jangan di-commit):

```
├── capture_YYYYMMDD_HHMMSS.pcap   # Raw packet capture
├── capture.json                   # Data paket hasil decode
├── tshark.log                     # tshark stderr (buat debug)
└── .pkts.tsv                      # Temp file (auto-delete)
```

Tambahin ke `.gitignore`:
```
*.pcap
capture.json
tshark.log
.pkts.tsv
```

---

## Disclaimer Legal

> ⚠️ **HANYA UNTUK SECURITY TESTING YANG SAH.**
>
> ARP spoofing adalah serangan man-in-the-middle. Melakukannya di jaringan yang **bukan milik lo atau tanpa izin tertulis** adalah ilegal di hampir semua yurisdiksi dan bisa kena tuntutan pidana.
>
> **Penggunaan yang boleh:**
> - Jaringan rumah / lab sendiri.
> - Jaringan yang lo punya surat izin pentest tertulis.
> - Lingkungan CTF / hack-the-box.
> - Setting edukasi dengan izin instruktur.
>
> **Yang ga boleh:**
> - Wi-Fi publik (kafe, bandara, hotel).
> - Jaringan korporat tanpa izin tertulis.
> - Jaringan milik orang lain.
>
> Author (**Alteriza**) dan asisten AI (**DeepSeek**, **Gemini**) **tidak bertanggung jawab** atas penyalahgunaan tool ini. Lo sendiri yang bertanggung jawab atas tindakan lo. Pakai dengan etis.

---

## Kredit

| Peran | Nama |
|---|---|
| **Author / Maintainer** | **Alteriza** |
| **Asisten AI (V2.0+)** | **DeepSeek** — refactor, viewer kaya, pipeline JSON, fix robustness. |
| **Asisten AI (V1.0)** | **Gemini** — script proof-of-concept awal yang menginspirasi arsitektur sekarang. |
| **Dependency utama** | [bettercap](https://www.bettercap.org/), [Wireshark/tshark](https://www.wireshark.org/) |

Terima kasih khusus buat komunitas open-source di balik `bettercap`, `tshark`, dan tutorial-tutorial ARP spoof yang bikin proyek ini mungkin.

---

# 📜 License

MIT License — see [LICENSE](LICENSE) for the full text.

<div align="center">

**⭐ Kalau tool ini berguna, kasih bintang di GitHub ya! ⭐**

Made with 🖤 by **Alteriza** · Powered by **DeepSeek** & **Gemini**

</div>

---
