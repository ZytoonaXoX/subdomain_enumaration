#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC} advanced_sub_finder.sh <domain>"
    echo -e "Example: advanced_sub_finder.sh example.com"
    exit 1
fi

DOMAIN=$(echo "$1" | sed 's~https\?://~~' | sed 's~/.*~~' | tr '[:upper:]' '[:lower:]')

if ! echo "$DOMAIN" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$'; then
    echo -e "${RED}[!] Invalid domain: $DOMAIN${NC}"
    exit 1
fi

echo -e "${CYAN}[*] Target: $DOMAIN${NC}"

> subdomains.txt
> valid_subdomains.txt
> invalid_subdomains.txt
> subdomain_ip.txt

filter_subs() {
    grep -E "^[a-zA-Z0-9._-]+\.$DOMAIN$" | grep -v '^\.' | sort -u
}

echo -e "${YELLOW}[*] Querying archive.org...${NC}"
curl -s "https://web.archive.org/cdx/search/cdx?url=*.$DOMAIN/*&output=text&fl=original&collapse=urlkey" \
    | grep -oE "https?://[a-zA-Z0-9._-]+" \
    | sed 's~https\?://~~' \
    | filter_subs >> subdomains.txt

echo -e "${YELLOW}[*] Querying crt.sh...${NC}"
curl -s "https://crt.sh/?q=%.$DOMAIN&output=json" \
    | jq -r '.[].name_value' 2>/dev/null \
    | sed 's/\*\.//g' \
    | filter_subs >> subdomains.txt

echo -e "${YELLOW}[*] Querying certspotter.com...${NC}"
curl -s "https://api.certspotter.com/v1/issuances?domain=$DOMAIN&include_subdomains=true&expand=dns_names" \
    | jq -r '.[].dns_names[]' 2>/dev/null \
    | filter_subs >> subdomains.txt

echo -e "${YELLOW}[*] Querying hackertarget.com...${NC}"
curl -s "https://api.hackertarget.com/hostsearch/?q=$DOMAIN" \
    | cut -d "," -f 1 \
    | filter_subs >> subdomains.txt

echo -e "${YELLOW}[*] Querying rapiddns.io...${NC}"
curl -s "https://rapiddns.io/subdomain/$DOMAIN?full=1" \
    | grep -oE "[a-zA-Z0-9._-]+\.$DOMAIN" \
    | filter_subs >> subdomains.txt

echo -e "${YELLOW}[*] Querying urlscan.io...${NC}"
curl -s "https://urlscan.io/api/v1/search/?q=domain:$DOMAIN&size=10000" \
    | jq -r '.results[].page.domain' 2>/dev/null \
    | filter_subs >> subdomains.txt

sort -u subdomains.txt -o subdomains.txt
TOTAL=$(wc -l < subdomains.txt)
echo -e "${CYAN}[+] Collection done — $TOTAL unique subdomains found${NC}"

echo -e "${CYAN}[*] Validating via DNS resolution...${NC}"
count=0
for sub in $(cat subdomains.txt); do
    if dig +short "$sub" 2>/dev/null | grep -qE '^[0-9]+\.|^[a-zA-Z]'; then
        echo "$sub" >> valid_subdomains.txt
        echo -e "  ${GREEN}[+] ALIVE${NC}  $sub"
        ((count++))
    else
        echo "$sub" >> invalid_subdomains.txt
    fi
done

echo -e "${CYAN}[+] $count / $TOTAL subdomains resolved${NC}"

echo -e "${CYAN}[*] Resolving IPs...${NC}"
while read -r sub; do
    ips=$(dig +short "$sub" 2>/dev/null | grep -E '^[0-9]{1,3}\.' | tr '\n' ',')
    if [ -n "$ips" ]; then
        echo "$sub --> $ips" >> subdomain_ip.txt
    fi
done < valid_subdomains.txt
