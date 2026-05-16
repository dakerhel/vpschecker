# vpschecker
Vps checker

# VPSChecker

Terminal VPS scanner for VPN nodes.

Designed for:

- VLESS
- Reality
- Hysteria2
- RU / EXIT routing
- Telegram bots
- VPN infrastructure
- Russian users

The checker does NOT execute external benchmark scripts.

All checks are implemented natively inside the script.


# Features

- VPS system analysis
- CPU / RAM / virtualization detection
- AES-NI / BBR checks
- IP / GEO / ASN detection
- RU / EU role detection
- Reality / VLESS suitability
- Hysteria2 UDP / QUIC readiness
- Telegram / Discord reachability
- DNSBL / anti-fraud checks
- Yandex / RU direction checks
- VPN node capacity estimate
- automatic dependency installation
- automatic cleanup after scan



# Quick commands

---

## Standard scan

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) -y --lang ru
```

---

## Full scan

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) --full -y --lang ru
```

---

## Full scan + auto cleanup

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) --full --auto-clean -y --lang ru
```

---

## Quick scan

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) --quick -y --lang ru
```

---

## English language

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) --lang en -y
```

---

## No ANSI colors

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) --full --no-color -y
```

---

## Do not clear terminal

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) --no-clear -y
```

---

## Keep installed dependencies

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) --keep-deps -y
```

---

## No dependency installation

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) --no-install -y
```

---

## Full VPN node analysis

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh) --full --auto-clean --lang ru -y
```

---

## Verify RAW file

```bash
curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh | head
```

---

## Verify line count

```bash
curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh | wc -l
```

---

## Download script locally

```bash
curl -Ls https://raw.githubusercontent.com/dakerhel/vpschecker/main/skaner.sh -o skaner.sh
```

---

## Local run

```bash
bash skaner.sh --full --auto-clean -y --lang ru
```

---

## Make executable

```bash
chmod +x skaner.sh
```

---

## Run executable file

```bash
./skaner.sh --full --auto-clean -y --lang ru
```
