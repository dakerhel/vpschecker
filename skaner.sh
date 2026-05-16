#!/usr/bin/env bash
# VPSChecker — terminal VPS scanner for Xray Reality / VLESS / Hysteria2
# Native checks only. No external benchmark scripts are executed.

set -o pipefail

VERSION="3.2.0"
LANG_CODE="ru"
ASSUME_YES=0
INSTALL_DEPS=1
AUTO_CLEAN=0
KEEP_DEPS=0
QUICK=0
FULL=0
CLEAR_SCREEN=1
NO_COLOR=0
RU_ENDPOINT=""
TIMEOUT_SHORT=6
TIMEOUT_MED=15
TIMEOUT_LONG=45

# ---------------- args ----------------
usage() {
  cat <<USAGE
VPSChecker v$VERSION

Usage:
  bash vpschecker.sh [options]

Options:
  -y, --yes                 Skip confirmation
  --lang ru|en              Language. Default: ru
  --quick                   Faster scan
  --full                    More checks
  --ru-endpoint URL         Optional controlled RU upload endpoint
  --no-install              Do not install missing packages
  --keep-deps               Do not suggest/remove installed packages
  --auto-clean              Remove packages installed by this run at the end
  --no-clear                Do not clear screen on start
  --no-color                Disable colors
  -h, --help                Show help

Examples:
  bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/vpschecker.sh) -y --lang ru
  bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/vpschecker.sh) --full -y --lang ru
  bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/vpschecker.sh) --ru-endpoint https://example.com/upload -y
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    --lang) shift; LANG_CODE="${1:-ru}" ;;
    --lang=*) LANG_CODE="${1#*=}" ;;
    --quick) QUICK=1 ;;
    --full) FULL=1 ;;
    --ru-endpoint) shift; RU_ENDPOINT="${1:-}" ;;
    --ru-endpoint=*) RU_ENDPOINT="${1#*=}" ;;
    --no-install) INSTALL_DEPS=0 ;;
    --keep-deps) KEEP_DEPS=1 ;;
    --auto-clean) AUTO_CLEAN=1 ;;
    --no-clear) CLEAR_SCREEN=0 ;;
    --no-color) NO_COLOR=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" ;;
  esac
  shift || true
done
case "$LANG_CODE" in ru|en) ;; *) LANG_CODE="ru" ;; esac

# ---------------- colors ----------------
if [ -t 1 ] && [ "$NO_COLOR" -eq 0 ]; then
  BOLD='\033[1m'; DIM='\033[2m'; RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; MAGENTA='\033[35m'; CYAN='\033[36m'; WHITE='\033[37m'; NC='\033[0m'
else
  BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; WHITE=''; NC=''
fi

# ---------------- i18n ----------------
T() {
  local k="$1"
  case "$LANG_CODE:$k" in
    ru:subtitle) echo "сканер VPS под Xray Reality · VLESS · Hysteria2" ;;
    en:subtitle) echo "VPS scanner for Xray Reality · VLESS · Hysteria2" ;;
    ru:confirm) echo "Сканер использует только собственные проверки: системные утилиты, DNS/HTTP/TLS/ICMP. Чужие benchmark-скрипты не запускаются. Продолжить? [Y/n]: " ;;
    en:confirm) echo "This scanner uses native checks only: system tools, DNS/HTTP/TLS/ICMP. No external benchmark scripts are executed. Continue? [Y/n]: " ;;
    ru:abort) echo "Отменено." ;;
    en:abort) echo "Aborted." ;;
    ru:auto) echo "АВТО" ;;
    en:auto) echo "AUTO" ;;
    ru:front) echo "FRONT / WHITELIST" ;;
    en:front) echo "FRONT / WHITELIST" ;;
    ru:exit) echo "EXIT / FOREIGN" ;;
    en:exit) echo "EXIT / FOREIGN" ;;
    ru:unknown) echo "НЕИЗВЕСТНО" ;;
    en:unknown) echo "UNKNOWN" ;;
    ru:excellent) echo "ОТЛИЧНО" ;;
    en:excellent) echo "EXCELLENT" ;;
    ru:good) echo "ХОРОШО" ;;
    en:good) echo "GOOD" ;;
    ru:medium) echo "СРЕДНЕ" ;;
    en:medium) echo "MEDIUM" ;;
    ru:bad) echo "ПЛОХО" ;;
    en:bad) echo "BAD" ;;
    ru:skip) echo "пропущено" ;;
    en:skip) echo "skipped" ;;
    *) echo "$k" ;;
  esac
}

# ---------------- ui ----------------
say() { printf '%b\n' "$*"; }
hr() { printf '%b\n' "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
ok() { say "${GREEN}✔${NC} $*"; }
warn() { say "${YELLOW}⚠${NC} $*"; }
bad() { say "${RED}✖${NC} $*"; }
info() { say "${BLUE}ℹ${NC} $*"; }

bar() {
  local pct="${1:-0}" width=20 filled empty out=""
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100
  filled=$((pct * width / 100))
  empty=$((width - filled))
  while [ "$filled" -gt 0 ]; do out="${out}█"; filled=$((filled-1)); done
  while [ "$empty" -gt 0 ]; do out="${out}░"; empty=$((empty-1)); done
  printf '%s' "$out"
}






run_step() {
  local title="$1"
  shift

  STEP_NUM=$((STEP_NUM + 1))

  local tmp flag
  tmp="$(mktemp /tmp/vpschecker-step.XXXXXX 2>/dev/null || echo /tmp/vpschecker-step.$$)"
  flag="$(mktemp /tmp/vpschecker-spin.XXXXXX 2>/dev/null || echo /tmp/vpschecker-spin.$$)"

  (
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while [ -f "$flag" ]; do
      i=$(( (i + 1) % 10 ))
      printf "\r%b%s%b [%02d/%02d] %s..." "$CYAN" "${spin:$i:1}" "$NC" "$STEP_NUM" "$TOTAL_STEPS" "$title"
      sleep 0.08
    done
  ) &
  local spid=$!

  "$@" >"$tmp" 2>&1
  local rc=$?

  rm -f "$flag"
  wait "$spid" 2>/dev/null || true
  printf "\r%100s\r" " "

  printf "\n%b╭─ [%02d/%02d] %s%b\n" "$CYAN$BOLD" "$STEP_NUM" "$TOTAL_STEPS" "$title" "$NC"
  printf "%b│%b\n" "$DIM" "$NC"
  sed 's/^/  /' "$tmp"
  rm -f "$tmp"
  printf "%b│%b\n" "$DIM" "$NC"

  if [ "$rc" -eq 0 ]; then
    printf "%b╰─ ✔ %s%b\n" "$GREEN" "$title" "$NC"
  else
    printf "%b╰─ ⚠ %s%b\n" "$YELLOW" "$title" "$NC"
  fi

  return 0
}



kv() { printf '  %-24s %b\n' "$1" "$2"; }

small_banner() {
  [ "$CLEAR_SCREEN" -eq 1 ] && clear 2>/dev/null || true

  say "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  say "${BOLD} VPSChecker · VPN Node Analyzer${NC}"
  say "${DIM} VLESS · Reality · Hysteria2 · RU/EXIT routing · IP reputation${NC}"
  say "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  say "${DIM} Mode: $([ "$FULL" -eq 1 ] && echo full || echo standard) · Language: ${LANG_CODE} · Output: terminal-only${NC}"
  say ""
}

# ---------------- helpers ----------------
command_exists() { command -v "$1" >/dev/null 2>&1; }
clean_num() { awk 'BEGIN{v="'"${1:-0}"'"+0; printf "%.0f", v}'; }
float_ge() { awk "BEGIN{exit !($1 >= $2)}"; }
float_lt() { awk "BEGIN{exit !($1 < $2)}"; }

http_get() {
  local url="$1" t="${2:-$TIMEOUT_MED}"
  curl -4 -fsSL --max-time "$t" "$url" 2>/dev/null || true
}

http_probe() {
  local url="$1" t="${2:-$TIMEOUT_SHORT}"
  curl -4 -k -L -o /dev/null -sS --max-time "$t" -w "%{http_code}|%{time_connect}|%{time_appconnect}|%{time_total}|%{remote_ip}|%{ssl_verify_result}" "$url" 2>/dev/null || echo "000|0|0|0||x"
}

json_get() {
  local key="$1" data="$2"
  if command_exists jq; then
    printf '%s' "$data" | jq -r "$key // empty" 2>/dev/null
  else
    local k="${key#.}"
    printf '%s' "$data" | sed -n 's/.*"'"$k"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
  fi
}

pkg_manager() {
  if command_exists apt-get; then echo apt; return; fi
  if command_exists dnf; then echo dnf; return; fi
  if command_exists yum; then echo yum; return; fi
  if command_exists apk; then echo apk; return; fi
  echo none
}

INSTALLED_PKGS=""
PKGS_TO_REMOVE=""
install_deps() {
  local missing_bins="" c
  local need="curl awk sed grep cut sort head tail tr xargs dd date uname df free openssl ping ip ss"
  local optional="jq dig traceroute mtr tracepath bc timeout sysbench"

  for c in $need $optional; do
    command_exists "$c" || missing_bins="$missing_bins $c"
  done

  [ -z "$missing_bins" ] && { ok "Dependencies: OK"; return 0; }

  warn "Missing tools:$missing_bins"

  [ "$INSTALL_DEPS" -eq 0 ] && {
    warn "Running with fallbacks. Some checks will be skipped."
    return 0
  }

  local pm
  pm="$(pkg_manager)"
  [ "$pm" = none ] && {
    warn "No supported package manager found"
    return 0
  }

  local pkgs="" b pkg
  for b in $missing_bins; do
    case "$pm:$b" in
      apt:dig) pkg="dnsutils" ;;
      apt:ping) pkg="iputils-ping" ;;
      apt:tracepath) pkg="iputils-tracepath" ;;
      apt:mtr) pkg="mtr-tiny" ;;
      apt:ip|apt:ss) pkg="iproute2" ;;
      apt:timeout) pkg="coreutils" ;;
      dnf:dig|yum:dig) pkg="bind-utils" ;;
      dnf:ip|dnf:ss|yum:ip|yum:ss) pkg="iproute" ;;
      apk:dig) pkg="bind-tools" ;;
      apk:ip|apk:ss) pkg="iproute2" ;;
      apk:tracepath) pkg="iputils" ;;
      *) pkg="$b" ;;
    esac

    case " $pkgs " in
      *" $pkg "*) ;;
      *) pkgs="$pkgs $pkg" ;;
    esac
  done

  [ -z "$pkgs" ] && return 0

  info "Installing missing dependencies via $pm:$pkgs"
  export DEBIAN_FRONTEND=noninteractive

  case "$pm" in
    apt)
      apt-get update -qq >/dev/null 2>&1 || true
      apt-get install -y $pkgs >/dev/null 2>&1 || true
      ;;
    dnf)
      dnf install -y $pkgs >/dev/null 2>&1 || true
      ;;
    yum)
      yum install -y $pkgs >/dev/null 2>&1 || true
      ;;
    apk)
      apk add --no-cache $pkgs >/dev/null 2>&1 || true
      ;;
  esac

  INSTALLED_PKGS="$(printf '%s' "$pkgs" | xargs)"
  PKGS_TO_REMOVE="$INSTALLED_PKGS"

  [ -n "$INSTALLED_PKGS" ] && ok "Installed for this run:$INSTALLED_PKGS"
}

confirm() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  printf '%b' "$(T confirm)"
  read -r ans || ans=""
  ans="$(printf '%s' "$ans" | tr -d '\r' | xargs)"
  case "$ans" in ""|y|Y|yes|YES|Yes|да|Да|ДА) return 0 ;; *) say "$(T abort)"; exit 1 ;; esac
}

# ---------------- global state ----------------
PUBLIC_IP=""; COUNTRY=""; COUNTRY2=""; CITY=""; ASN=""; ORG=""; ISP=""; ROLE="UNKNOWN"
CPU_CORES=1; RAM_MB=0; AESNI="no"; BBR="unknown"; VIRT="unknown"; IPV6="no"
CRYPTO_MBPS=0; DISK_MBPS=0; RU_AVG=999; RU_LOSS=100; GLOBAL_AVG=999; GLOBAL_LOSS=100; JITTER=0
YANDEX_DL=0; RU_UPLOAD=0; RU_UPLOAD_SOURCE="none"
SERV_OK=0; SERV_TOTAL=0; SNI_OK=0; SNI_TOTAL=0; UDP_SCORE=0; MTU_HINT="unknown"
DNSBL_HITS=0; WARNINGS=""; NOTES=""
STEP_NUM=0
TOTAL_STEPS=12
REALITY=0; VLESS=0; HYSTERIA=0; RU_SCORE=0; STREAM_SCORE=0

add_warning() { WARNINGS="${WARNINGS}\n- $1"; }
add_note() { NOTES="${NOTES}\n- $1"; }

score_word() {
  local pct="$1"
  if [ "$pct" -ge 85 ]; then T excellent
  elif [ "$pct" -ge 70 ]; then T good
  elif [ "$pct" -ge 45 ]; then T medium
  else T bad
  fi
}

# ---------------- checks ----------------
check_system() {
  
  local os cpu disk_free kernel
  os="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}" || uname -s)"
  kernel="$(uname -r)"
  cpu="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | xargs || echo unknown)"
  CPU_CORES="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)"
  RAM_MB="$(free -m 2>/dev/null | awk '/Mem:/ {print $2+0}' || echo 0)"
  disk_free="$(df -h / 2>/dev/null | awk 'NR==2 {print $4" free / "$2" total"}' || echo unknown)"
  VIRT="$(systemd-detect-virt 2>/dev/null || echo unknown)"
  BBR="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  grep -m1 -qw aes /proc/cpuinfo 2>/dev/null && AESNI="yes" || AESNI="no"
  ip -6 route 2>/dev/null | grep -q default && IPV6="yes" || IPV6="no"

  kv "OS" "$os"
  kv "Kernel" "$kernel"
  kv "CPU" "$cpu"
  kv "Cores / RAM" "$CPU_CORES / ${RAM_MB} MB"
  kv "Disk" "$disk_free"
  kv "Virtualization" "$VIRT"
  kv "TCP congestion" "$BBR"
  kv "AES-NI" "$AESNI"
  kv "IPv6" "$IPV6"

  [ "$BBR" = bbr ] && ok "BBR enabled" || { warn "BBR is not enabled"; add_warning "BBR disabled: TCP speed may be worse under load"; }
  [ "$AESNI" = yes ] && ok "AES-NI present" || add_warning "AES-NI not detected"
}

check_ip_geo() {
  
  PUBLIC_IP="$(http_get https://api.ipify.org 6)"
  [ -z "$PUBLIC_IP" ] && PUBLIC_IP="$(http_get https://ifconfig.me/ip 6)"
  local d1 d2 asline
  d1="$(http_get "https://ipwho.is/${PUBLIC_IP}" 10)"
  d2="$(http_get "http://ip-api.com/json/${PUBLIC_IP}?fields=status,country,countryCode,city,as,asname,isp,org,query" 10)"
  COUNTRY="$(json_get .country "$d1")"; CITY="$(json_get .city "$d1")"
  COUNTRY2="$(json_get .country "$d2")"
  ASN="$(json_get .connection.asn "$d1")"; ORG="$(json_get .connection.org "$d1")"
  [ -z "$ORG" ] && ORG="$(json_get .isp "$d2")"
  asline="$(json_get .as "$d2")"; [ -z "$ASN" ] && ASN="$(printf '%s' "$asline" | awk '{print $1}')"
  ISP="$(json_get .isp "$d2")"

  kv "Public IPv4" "${BOLD}${PUBLIC_IP:-unknown}${NC}"
  kv "Geo #1" "${COUNTRY:-unknown}, ${CITY:-unknown}"
  kv "Geo #2" "${COUNTRY2:-unknown}"
  kv "ASN / Org" "${ASN:-unknown} / ${ORG:-unknown}"
  [ -n "$COUNTRY" ] && [ "$COUNTRY" = "$COUNTRY2" ] && ok "Geo databases agree" || { warn "Geo databases differ or unavailable"; add_warning "Geo mismatch may affect services and CDN routing"; }

  local lower; lower="$(printf '%s %s %s' "$COUNTRY" "$ORG" "$ISP" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *russia*|*russian*|*росси*) ROLE="FRONT" ;;
    *) ROLE="EXIT" ;;
  esac
  echo "$lower" | grep -Eiq 'yandex|vk cloud|selectel|timeweb|mts|rostelecom|beeline|megafon' && ROLE="FRONT"
  echo "$lower" | grep -Eiq 'hetzner|ovh|m247|digitalocean|amazon|google|microsoft|oracle|linode|contabo|aeza|pq|hosting|cloud|server|data|colo|vps' && add_warning "Datacenter ASN: streaming/anti-fraud services may detect VPN/proxy"

  kv "Detected role" "${BOLD}$( [ "$ROLE" = FRONT ] && T front || T exit )${NC}"
}

check_crypto_cpu() {
  
  if ! command_exists openssl; then warn "openssl missing"; return; fi
  local chacha aes raw
  raw="$(timeout 24 openssl speed -elapsed -evp chacha20-poly1305 2>/dev/null || true)"
  chacha="$(printf '%s' "$raw" | awk '/chacha20-poly1305/ {print $(NF-1)}' | tail -n1)"
  raw="$(timeout 24 openssl speed -elapsed -evp aes-128-gcm 2>/dev/null || true)"
  aes="$(printf '%s' "$raw" | awk '/aes-128-gcm/ {print $(NF-1)}' | tail -n1)"
  [ -n "$chacha" ] && CRYPTO_MBPS="$(awk "BEGIN{printf \"%.0f\", ($chacha*8)/1000}")"
  kv "ChaCha20-Poly1305" "${chacha:-n/a} kB/s"
  kv "AES-128-GCM" "${aes:-n/a} kB/s"
  kv "Crypto estimate" "${CRYPTO_MBPS:-0} Mbps class"

  if [ "$FULL" -eq 1 ] && command_exists sysbench; then
    local sb
    sb="$(timeout 20 sysbench cpu --threads=1 --time=8 run 2>/dev/null | awk -F: '/events per second/ {gsub(/ /,"",$2); print $2}' | head -n1)"
    [ -n "$sb" ] && kv "Sysbench single-core" "${sb} events/sec"
  fi
  if [ "$CRYPTO_MBPS" -ge 3000 ] 2>/dev/null; then ok "Strong crypto headroom"
  elif [ "$CRYPTO_MBPS" -ge 800 ] 2>/dev/null; then ok "Enough crypto for normal VPN load"
  else warn "Crypto headroom looks limited"; add_warning "CPU/crypto may bottleneck many users or Hysteria2 under load"; fi
}

check_disk() {
  
  [ "$QUICK" -eq 1 ] && { info "quick mode: disk write skipped"; return; }
  local tmp out speed
  tmp="$(mktemp /tmp/vpschecker-dd.XXXXXX 2>/dev/null || echo /tmp/vpschecker-dd.$$)"
  out="$(dd if=/dev/zero of="$tmp" bs=64M count=3 conv=fdatasync 2>&1 || true)"
  rm -f "$tmp"
  speed="$(printf '%s' "$out" | awk -F, '/copied/ {gsub(/^ /,"",$NF); print $NF}' | tail -n1)"
  DISK_MBPS="$(printf '%s' "$speed" | awk '{if($2=="GB/s") print $1*1000; else if($2=="MB/s") print $1; else print 0}' | cut -d. -f1)"
  kv "Sequential write" "${speed:-unknown}"
  [ "${DISK_MBPS:-0}" -ge 100 ] && ok "Disk is acceptable for VPN" || warn "Disk is slow; usually not critical for VPN"
}

ping_one() {
  local host="$1" out loss avg dev
  out="$(timeout 12 ping -4 -c 6 -W 2 "$host" 2>/dev/null || true)"
  loss="$(printf '%s' "$out" | awk -F, '/packet loss/ {gsub(/% packet loss/,"",$3); gsub(/ /,"",$3); print $3}' | head -n1)"
  avg="$(printf '%s' "$out" | awk -F/ '/rtt|round-trip/ {print $5}' | head -n1)"
  dev="$(printf '%s' "$out" | awk -F/ '/rtt|round-trip/ {print $7}' | head -n1)"
  [ -z "$loss" ] && loss=100; [ -z "$avg" ] && avg=999; [ -z "$dev" ] && dev=0
  echo "$avg|$loss|$dev"
}

check_network() {
  
  local ru_targets="ya.ru vk.com mail.ru"
  local gl_targets="1.1.1.1 8.8.8.8 github.com telegram.org"
  local sum=0 cnt=0 losssum=0 jsum=0 host res avg loss dev
  for host in $ru_targets; do
    res="$(ping_one "$host")"; avg="${res%%|*}"; loss="$(echo "$res"|cut -d'|' -f2)"; dev="$(echo "$res"|cut -d'|' -f3)"
    [ "$loss" = 100 ] && bad "RU $host: no reply" || ok "RU $host: ${avg} ms, loss ${loss}%, jitter ${dev}"
    sum="$(awk "BEGIN{print $sum+$avg}")"; losssum="$(awk "BEGIN{print $losssum+$loss}")"; jsum="$(awk "BEGIN{print $jsum+$dev}")"; cnt=$((cnt+1))
  done
  RU_AVG="$(awk "BEGIN{printf \"%.0f\", $sum/$cnt}")"; RU_LOSS="$(awk "BEGIN{printf \"%.0f\", $losssum/$cnt}")"; JITTER="$(awk "BEGIN{printf \"%.1f\", $jsum/$cnt}")"

  sum=0; cnt=0; losssum=0
  for host in $gl_targets; do
    res="$(ping_one "$host")"; avg="${res%%|*}"; loss="$(echo "$res"|cut -d'|' -f2)"
    [ "$loss" = 100 ] && warn "Global $host: no reply" || ok "Global $host: ${avg} ms, loss ${loss}%"
    sum="$(awk "BEGIN{print $sum+$avg}")"; losssum="$(awk "BEGIN{print $losssum+$loss}")"; cnt=$((cnt+1))
  done
  GLOBAL_AVG="$(awk "BEGIN{printf \"%.0f\", $sum/$cnt}")"; GLOBAL_LOSS="$(awk "BEGIN{printf \"%.0f\", $losssum/$cnt}")"

  if command_exists tracepath; then
    MTU_HINT="$(timeout 10 tracepath -n 1.1.1.1 2>/dev/null | awk '/pmtu/ {print $NF; exit}')"
    [ -n "$MTU_HINT" ] && kv "PMTU hint" "$MTU_HINT" || MTU_HINT="unknown"
  fi
}

check_yandex_ru_upload() {
  
  local r code total dl_speed tmp up upload_code
  r="$(http_probe https://ya.ru 8)"; code="${r%%|*}"; total="$(echo "$r"|cut -d'|' -f4)"
  kv "Yandex probe" "HTTP $code, total ${total}s"
  dl_speed="$(curl -4 -L -o /dev/null -s --max-time 20 -w '%{speed_download}' https://avatars.mds.yandex.net/get-yapic/0/0-0/islands-200 2>/dev/null || echo 0)"
  YANDEX_DL="$(awk "BEGIN{printf \"%.1f\", ($dl_speed*8)/1000000}")"
  kv "Yandex small download" "${YANDEX_DL} Mbps"

  if [ -n "$RU_ENDPOINT" ]; then
    tmp="$(mktemp /tmp/vpschecker-upload.XXXXXX 2>/dev/null || echo /tmp/vpschecker-upload.$$)"
    dd if=/dev/zero of="$tmp" bs=1M count=16 >/dev/null 2>&1
    upload_code="$(curl -4 -sS -o /dev/null --max-time 45 -w '%{http_code}|%{speed_upload}' -X POST --data-binary "@$tmp" "$RU_ENDPOINT" 2>/dev/null || echo '000|0')"
    rm -f "$tmp"
    up="$(echo "$upload_code" | cut -d'|' -f2)"
    RU_UPLOAD="$(awk "BEGIN{printf \"%.1f\", ($up*8)/1000000}")"
    RU_UPLOAD_SOURCE="controlled endpoint"
    kv "RU upload endpoint" "${RU_UPLOAD} Mbps, HTTP $(echo "$upload_code" | cut -d'|' -f1)"
    float_ge "$RU_UPLOAD" 80 && ok "RU upload is good" || { warn "RU upload is limited"; add_warning "RU upload may limit simultaneous heavy users"; }
  else
    RU_UPLOAD_SOURCE="estimated from baseline only"
    warn "Exact RU upload not measured: no controlled RU endpoint provided"
    info "Use --ru-endpoint URL for real upload measurement to your RU node"
  fi
}

check_services() {
  
  local compact="YouTube:https://youtube.com Discord:https://discord.com TelegramAPI:https://api.telegram.org GitHub:https://github.com OpenAI:https://chat.openai.com Yandex:https://ya.ru"
  local full="Spotify:https://spotify.com Netflix:https://netflix.com Steam:https://store.steampowered.com Microsoft:https://www.microsoft.com Apple:https://www.apple.com DockerHub:https://hub.docker.com TikTok:https://www.tiktok.com"
  local list="$compact"
  [ "$FULL" -eq 1 ] || [ "$ROLE" = FRONT ] && list="$compact $full"
  SERV_TOTAL=0; SERV_OK=0
  local item name url res code tt
  for item in $list; do
    name="${item%%:*}"; url="${item#*:}"
    res="$(http_probe "$url" 10)"; code="$(echo "$res"|cut -d'|' -f1)"; tt="$(echo "$res"|cut -d'|' -f4)"
    SERV_TOTAL=$((SERV_TOTAL+1))
    if echo "$code" | grep -Eq '^(200|301|302|303|307|308|401|403)$'; then
      if [ "$name" = "OpenAI" ] && [ "$code" = "403" ]; then ok "$name: reachable, HTTP 403 expected, ${tt}s"; else ok "$name: HTTP $code, ${tt}s"; fi; SERV_OK=$((SERV_OK+1))
    else
      warn "$name: HTTP $code / timeout"
    fi
  done
}

check_sni_reality() {
  
  local candidates="www.microsoft.com www.apple.com www.yahoo.com www.bing.com www.cloudflare.com www.ubuntu.com www.mozilla.org github.com"
  SNI_TOTAL=0; SNI_OK=0
  local host res code tls total cert alpn
  for host in $candidates; do
    SNI_TOTAL=$((SNI_TOTAL+1))
    res="$(curl -4 -sS -I --connect-timeout 5 --max-time 10 -w '|%{http_code}|%{time_appconnect}|%{time_total}|%{ssl_verify_result}' "https://$host" -o /dev/null 2>/dev/null || echo '|000|0|0|x')"
    code="$(echo "$res"|awk -F'|' '{print $(NF-3)}')"; tls="$(echo "$res"|awk -F'|' '{print $(NF-2)}')"; total="$(echo "$res"|awk -F'|' '{print $(NF-1)}')"; cert="$(echo "$res"|awk -F'|' '{print $NF}')"
    if echo "$code" | grep -Eq '^(200|301|302|303|307|308|403)$' && [ "$cert" = 0 ]; then
      ok "$host: TLS OK, HTTP $code, handshake ${tls}s"; SNI_OK=$((SNI_OK+1))
    else
      warn "$host: weak candidate, HTTP $code, cert=$cert"
    fi
  done
  add_note "SNI/Reality target must be selected manually. Public universal SNI lists burn quickly."
}

check_telegram_discord() {
  
  local endpoints="TelegramAPI:https://api.telegram.org TelegramWeb:https://web.telegram.org Discord:https://discord.com DiscordGateway:https://gateway.discord.gg"
  local item name url res code tt okn=0 total=0
  for item in $endpoints; do
    name="${item%%:*}"; url="${item#*:}"
    res="$(http_probe "$url" 10)"; code="$(echo "$res"|cut -d'|' -f1)"; tt="$(echo "$res"|cut -d'|' -f4)"
    total=$((total+1))
    if echo "$code" | grep -Eq '^(200|301|302|303|307|308|401|403)$'; then ok "$name: HTTP $code, ${tt}s"; okn=$((okn+1)); else warn "$name: HTTP $code / timeout"; fi
  done
  [ "$okn" -lt 3 ] && add_warning "Telegram/Discord availability is not perfect"
}

check_udp_quic_ports() {
  
  UDP_SCORE=0
  if curl -V 2>/dev/null | grep -qi 'HTTP3'; then
    local res code total
    res="$(curl -4 --http3-only -sS -o /dev/null --max-time 12 -w '%{http_code}|%{time_total}' https://cloudflare.com 2>/dev/null || echo '000|0')"
    code="${res%%|*}"; total="${res#*|}"
    if echo "$code" | grep -Eq '^(200|301|302|403)$'; then ok "HTTP/3 QUIC works: HTTP $code, ${total}s"; UDP_SCORE=3; else warn "HTTP/3 QUIC failed or blocked"; UDP_SCORE=1; fi
  else
    warn "curl has no HTTP/3 support; QUIC check skipped"
    UDP_SCORE=1
  fi
  if command_exists nc; then
    info "UDP with nc is not fully reliable without echo server; using QUIC/latency/loss for Hysteria2 score"
  fi
  kv "UDP/QUIC score" "$UDP_SCORE/3"
}

check_dnsbl_ipintel() {
  
  if [ -z "$PUBLIC_IP" ] || ! command_exists dig; then warn "DNSBL skipped"; return; fi
  local rev zone hit zones
  rev="$(printf '%s' "$PUBLIC_IP" | awk -F. '{print $4"."$3"."$2"."$1}')"
  zones="zen.spamhaus.org bl.spamcop.net b.barracudacentral.org dnsbl.sorbs.net"
  DNSBL_HITS=0
  for zone in $zones; do
    hit="$(timeout 6 dig +short "${rev}.${zone}" A 2>/dev/null | head -n1)"
    if [ -n "$hit" ]; then bad "$zone: LISTED ($hit)"; DNSBL_HITS=$((DNSBL_HITS+1)); else ok "$zone: clean"; fi
  done
  [ "$DNSBL_HITS" -gt 0 ] && add_warning "IP is listed in DNSBL; bad for mail/reputation, less critical for VPN"
  return 0
}

estimate_users() {
  
  local bw crypto effective base4k basefull safe_active safe_4k
  # If controlled RU upload exists, it dominates. Otherwise use conservative class from RU latency + no exact upload.
  if float_ge "${RU_UPLOAD:-0}" 1; then bw="$RU_UPLOAD"; else bw=100; fi
  crypto="${CRYPTO_MBPS:-0}"
  [ "$crypto" -le 0 ] 2>/dev/null && crypto=300
  effective="$(awk "BEGIN{m=$bw; if($crypto/3<m)m=$crypto/3; printf \"%.0f\", m}")"
  basefull="$(awk "BEGIN{printf \"%.0f\", $effective/6}")"     # active mixed users at strong load
  base4k="$(awk "BEGIN{printf \"%.0f\", $effective/25}")"       # simultaneous 4K streams
  safe_active=$((basefull-10)); [ "$safe_active" -lt 1 ] && safe_active=1
  safe_4k=$((base4k-1)); [ "$safe_4k" -lt 1 ] && safe_4k=1
  kv "Effective bottleneck" "~${effective} Mbps ${DIM}(bandwidth/crypto conservative)${NC}"
  kv "Heavy active users" "~${safe_active} ${DIM}(conservative, minus safety margin)${NC}"
  kv "4K streams" "~${safe_4k} ${DIM}(25 Mbps each, conservative)${NC}"
  add_note "User capacity is an estimate, not a guarantee. Real load depends on bitrate, protocol settings and client behavior."
}

compute_scores() {
  # protocol scores: intentionally conservative
  local geo=10 sys=10 crypto=0 ru=0 services=0 sni=0 hyst=0 mtu=5 ipintel=0
  [ "$BBR" = bbr ] || sys=$((sys-2))
  [ "$AESNI" = yes ] || sys=$((sys-2))
  [ "$CRYPTO_MBPS" -ge 3000 ] 2>/dev/null && crypto=25 || { [ "$CRYPTO_MBPS" -ge 800 ] 2>/dev/null && crypto=18 || crypto=10; }
  [ "$RU_LOSS" -eq 0 ] 2>/dev/null && [ "$RU_AVG" -lt 80 ] 2>/dev/null && ru=25 || { [ "$RU_LOSS" -le 5 ] 2>/dev/null && ru=15 || ru=5; }
  [ "$SERV_TOTAL" -gt 0 ] && services=$((SERV_OK*15/SERV_TOTAL)) || services=5
  [ "$SNI_TOTAL" -gt 0 ] && sni=$((SNI_OK*20/SNI_TOTAL)) || sni=5
  [ "$UDP_SCORE" -ge 3 ] && hyst=20 || { [ "$UDP_SCORE" -ge 1 ] && hyst=10 || hyst=3; }
  [ "$DNSBL_HITS" -eq 0 ] && ipintel=10 || ipintel=3

  REALITY=$((sys + crypto + ru + services + sni + ipintel))
  VLESS=$((sys + crypto + ru + services + ipintel + 10))
  HYSTERIA=$((sys + crypto/2 + ru + services + hyst + ipintel))
  RU_SCORE=$((ru*2 + services + sys + ipintel))
  STREAM_SCORE=$((services*3 + ipintel + geo))
  [ "$REALITY" -gt 100 ] && REALITY=100
  [ "$VLESS" -gt 100 ] && VLESS=100
  [ "$HYSTERIA" -gt 100 ] && HYSTERIA=100
  [ "$RU_SCORE" -gt 100 ] && RU_SCORE=100
  [ "$STREAM_SCORE" -gt 100 ] && STREAM_SCORE=100
}

final_summary() {
  compute_scores
  printf '\n%b\n' "${BOLD}${CYAN}FINAL${NC}"
  hr
  kv "Detected role" "${BOLD}$( [ "$ROLE" = FRONT ] && T front || T exit )${NC}"
  kv "Xray Reality" "${REALITY}/100  ${BOLD}$(score_word "$REALITY")${NC}"
  kv "VLESS TLS" "${VLESS}/100  ${BOLD}$(score_word "$VLESS")${NC}"
  kv "Hysteria2" "${HYSTERIA}/100  ${BOLD}$(score_word "$HYSTERIA")${NC}"
  kv "RU users" "${RU_SCORE}/100  ${BOLD}$(score_word "$RU_SCORE")${NC}"
  kv "Streaming compatibility" "${STREAM_SCORE}/100  ${BOLD}$(score_word "$STREAM_SCORE")${NC}"
  say ""
  kv "IP / ASN" "${PUBLIC_IP:-unknown} / ${ASN:-unknown} / ${ORG:-unknown}"
  kv "Geo" "${COUNTRY:-unknown}, ${CITY:-unknown}"
  kv "RU latency/loss" "${RU_AVG} ms / ${RU_LOSS}%"
  kv "Jitter" "${JITTER} ms"
  kv "Yandex download" "${YANDEX_DL} Mbps"
  kv "RU upload" "$( [ "$RU_UPLOAD" != 0 ] && echo "${RU_UPLOAD} Mbps (${RU_UPLOAD_SOURCE})" || echo "not measured; use --ru-endpoint" )"
  kv "MTU hint" "$MTU_HINT"
  say ""
  if [ -n "$(printf '%b' "$WARNINGS" | sed '/^[[:space:]]*$/d')" ]; then
    say "${BOLD}${YELLOW}Important:${NC}"
    printf '%b\n' "$WARNINGS" | sed '/^[[:space:]]*$/d'
  else
    ok "No critical issues detected"
  fi
  if [ -n "$(printf '%b' "$NOTES" | sed '/^[[:space:]]*$/d')" ]; then
    say ""
    say "${BOLD}${BLUE}Notes:${NC}"
    printf '%b\n' "$NOTES" | sed '/^[[:space:]]*$/d'
  fi
}

cleanup_info() {
  printf '\n%b\n' "${BOLD}${CYAN}CLEANUP${NC}"
  hr

  kv "Reports/logs" "none — terminal output only"
  kv "Temp files" "removed during execution"

  if [ -n "$INSTALLED_PKGS" ] && [ "$KEEP_DEPS" -eq 0 ]; then
    kv "Installed by checker" "$INSTALLED_PKGS"

    local pm
    pm="$(pkg_manager)"

    case "$pm" in
      apt) REMOVE_CMD="sudo apt-get remove -y $PKGS_TO_REMOVE && sudo apt-get autoremove -y" ;;
      dnf) REMOVE_CMD="sudo dnf remove -y $PKGS_TO_REMOVE" ;;
      yum) REMOVE_CMD="sudo yum remove -y $PKGS_TO_REMOVE" ;;
      apk) REMOVE_CMD="sudo apk del $PKGS_TO_REMOVE" ;;
      *) REMOVE_CMD="remove with your package manager: $PKGS_TO_REMOVE" ;;
    esac

    kv "Remove command" "$REMOVE_CMD"

    if [ "$AUTO_CLEAN" -eq 1 ]; then
      return 0
    fi

    printf '\n%b' "${YELLOW}Remove packages installed by this checker now? [y/N]: ${NC}"
    read -r ans || ans=""
    ans="$(printf '%s' "$ans" | tr -d '\r' | xargs)"

    case "$ans" in
      y|Y|yes|YES|Yes|да|Да|ДА)
        AUTO_CLEAN=1
        ;;
      *)
        info "Keeping installed packages"
        ;;
    esac
  else
    kv "Installed packages" "nothing by this run"
  fi
}

auto_clean() {
  [ "$AUTO_CLEAN" -eq 1 ] || return 0
  [ -z "$PKGS_TO_REMOVE" ] && return 0

  local pm
  pm="$(pkg_manager)"

  info "Removing packages installed by this checker:$PKGS_TO_REMOVE"

  case "$pm" in
    apt)
      apt-get remove -y $PKGS_TO_REMOVE >/dev/null 2>&1 || true
      apt-get autoremove -y >/dev/null 2>&1 || true
      ;;
    dnf)
      dnf remove -y $PKGS_TO_REMOVE >/dev/null 2>&1 || true
      ;;
    yum)
      yum remove -y $PKGS_TO_REMOVE >/dev/null 2>&1 || true
      ;;
    apk)
      apk del $PKGS_TO_REMOVE >/dev/null 2>&1 || true
      ;;
  esac

  ok "Cleanup completed"
}


main() {
  small_banner
  confirm
  install_deps

  run_step "Система и виртуализация" check_system
  run_step "IP, геолокация и роль сервера" check_ip_geo
  run_step "CPU и шифрование под VPN" check_crypto_cpu
  run_step "Диск и базовая производительность" check_disk
  run_step "Задержка, потери и стабильность сети" check_network
  run_step "Яндекс / РФ-направление / upload" check_yandex_ru_upload
  run_step "Доступность сервисов и геоблок" check_services
  run_step "Reality / VLESS / SNI-кандидаты" check_sni_reality
  run_step "Telegram, боты и Discord" check_telegram_discord
  run_step "Hysteria2: UDP, QUIC и MTU" check_udp_quic_ports
  run_step "IP reputation: hosting / anti-fraud / DNSBL" check_dnsbl_ipintel
  run_step "Оценка нагрузки и пользователей" estimate_users

  final_summary
  cleanup_info
  auto_clean
}


main "$@"
