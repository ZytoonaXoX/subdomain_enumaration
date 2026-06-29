# Subdomain Finder

A Bash-based subdomain enumeration tool that aggregates results from six OSINT sources, validates them via DNS resolution, and maps resolved subdomains to their IP addresses.

## Features

- Queries six sources for subdomain data:
  - **crt.sh** (Certificate Transparency logs)
  - **Wayback Machine CDX API** (archive.org)
  - **CertSpotter**
  - **HackerTarget**
  - **RapidDNS**
  - **URLScan.io**
- Validates and normalizes the input domain (strips protocol/path, lowercases)
- Filters all results so only subdomains matching the target domain are kept
- Deduplicates results across all sources
- Validates each candidate via `dig` DNS resolution
- Resolves IP addresses for every confirmed-live subdomain
- Color-coded terminal output for readability

## Requirements

- `bash`
- `curl`
- `jq`
- `dig` (from `dnsutils` / `bind-utils`)
- `sed`, `grep`, `cut` (standard on virtually all Linux/macOS systems)

Install dependencies (Debian/Ubuntu):
```bash
sudo apt install curl jq dnsutils
```

## Usage

```bash
chmod +x subdomain_enumeration.sh
./subdomain_enumeration.sh <domain>
```

**Example:**
```bash
./subdomain_enumeration.sh example.com
```

The domain can be passed with or without a scheme/path (e.g. `https://example.com/page` is automatically normalized to `example.com`).

## Output Files

The script generates four files in the current directory:

| File | Contents |
|------|----------|
| `subdomains.txt` | All unique subdomains collected from every source (pre-validation) |
| `valid_subdomains.txt` | Subdomains confirmed live via DNS resolution |
| `invalid_subdomains.txt` | Subdomains that did not resolve |
| `subdomain_ip.txt` | Live subdomains mapped to their resolved IP address(es), in `subdomain --> ip1,ip2,...` format |

## How It Works

1. **Input normalization** — strips `http(s)://` and any trailing path, lowercases the domain, and validates it against a domain-format regex
2. **Collection** — queries all six sources in sequence, piping each through a shared filter that keeps only valid subdomains of the target
3. **Deduplication** — merges and sorts all collected subdomains into a unique list
4. **DNS validation** — runs `dig +short` against each candidate to confirm it resolves
5. **IP resolution** — for every confirmed-live subdomain, extracts its IPv4 address(es) via `dig`

## Example Output

```
[*] Target: example.com
[*] Querying archive.org...
[*] Querying crt.sh...
[*] Querying certspotter.com...
[*] Querying hackertarget.com...
[*] Querying rapiddns.io...
[*] Querying urlscan.io...
[+] Collection done — 52 unique subdomains found
[*] Validating via DNS resolution...
  [+] ALIVE  www.example.com
  [+] ALIVE  mail.example.com
  ...
[+] 41 / 52 subdomains resolved
[*] Resolving IPs...
```

## Notes & Known Limitations

- All sources are queried sequentially, not in parallel — large domains may take a while to enumerate
- DNS validation depends on the resolver configured on your system; results may vary slightly between environments
- Some public APIs used here (e.g. URLScan.io, HackerTarget) are rate-limited; heavy/repeated use against the same domain may return partial results
- Only IPv4 addresses are extracted in the IP resolution step
- 
## Author

Built by Zytoona as part of ongoing offensive security / OSINT tooling practice.
