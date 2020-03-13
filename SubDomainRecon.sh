#!/bin/bash

# dependencies: amass, massdns, altdns, commonspeak
# lists: all.txt, commonspeak****, words.txt, resolvers.txt
# full paths
listDir="/root/ToolKit/Tools/SubDomainRecon"
massDir="/root/ToolKit/Tools/massdns"
commonDir="/root/ToolKit/Tools/commonspeak"
bassDir="/root/ToolKit/Tools/bass"
subjackGoDir="/root/go"

if [ $# -lt 2 ]; then
    echo "[!] Usage: SubDomainRecon.sh [domain] [out-file]"
    exit 1
fi

DOMAIN=$1
OUTFILE=$2

# check for wildcards
wildcard=$(dig +short abcdefghijklmnopqrstuvwxyz9999."$DOMAIN" | wc -l)
if [ $wildcard -ne 0 ]; then
    echo "[!] Wildcard DNS detected"
fi

# grab resolvers for domain
echo "===== bass ====="
cd "$bassDir"
python3 "$bassDir"/bass.py -d "$DOMAIN" -o "$listDir"/resolvers.txt
cd -

# amass scrape
echo "===== AMASS ====="
amass enum --passive -d $DOMAIN -o tempAmass.txt
if [ $? -ne 0 ]; then
    echo "AMASS Failed"
	exit 1
fi
cat tempAmass.txt | massdns -r "$listDir"/resolvers.txt -t A -o S -w tempMassAmass.txt
if [ $? -ne 0 ]; then
    echo "massdns amass Failed"
	exit 1
fi
echo "===== AMASS-Done ====="

# massdns all.txt
echo "===== all.txt ====="
"$massDir"/scripts/subbrute.py "$listDir"/all.txt $DOMAIN | massdns -r "$listDir"/resolvers.txt -t A -o S -w tempMassAll.txt
if [ $? -ne 0 ]; then
    echo "massdns all.txt Failed"
	exit 1
fi
echo "===== all.txt-Done ====="

# massdns hackernews commonspeak
echo "===== CommonSpeak ====="

# check if commonspeak is old
comHackList=$(ls -t -d "$commonDir"/stackoverflow/output/compiled/* | head -1)
lastUpdate="$(stat -c %Y $comHackList)"
now="$(date +%s)"
let diff="${now}-${lastUpdate}"

if [ "$diff" -gt "604800" ]; then
    "$commonDir"/stackoverflow/stackoverflow-subdomains.sh commonspeak-270116
fi

python2 "$commonDir"/domainConcat.py "$DOMAIN" "$comHackList" | massdns -r "$listDir"/resolvers.txt -t A -o S -w tempMassComHack.txt
if [ $? -ne 0 ]; then
    echo "massdns commonspeak Failed"
	exit 1
fi
echo "===== CommonSpeak-Done ====="

# trim results front '*.' & end '.' , combine and remove unique entries for altDNS
cat tempMassAll.txt tempMassComHack.txt tempMassAmass.txt | awk '{print $1}' | sed 's/^\*\.//g; s/\.$//g' | sort -u > tempPreAlt.txt

# remove IP's (not needed)
# sed '/^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/d' tempPreAlt.txt > tempNoIPPreAlt.txt

# create altdns list
echo "===== AltDNS ====="
altdns -i tempPreAlt.txt -o tempAltDomains.txt -w "$listDir"/words.txt 
if [ $? -ne 0 ]; then
    echo "AltDNS Failed"
	exit 1
fi

# massdns altdns
cat tempAltDomains.txt | massdns -r "$listDir"/resolvers.txt -t A -o S -w tempMassAlt.txt
if [ $? -ne 0 ]; then
    echo "massdns AltDNS Failed"
	exit 1
fi
echo "===== AltDNS-Done ====="

# single list of trimmed domains
cat tempMassAlt.txt | awk '{print $1}' | sed 's/^\*\.//g; s/\.$//g' | cat - tempPreAlt.txt | sort -u > "$OUTFILE"

# cut all uniq domains no matter record
# list of all A and CNAME records
cat tempMassAlt.txt tempMassAll.txt tempMassComHack.txt tempMassAmass.txt | sort -u -t" " -k1,1 > "$OUTFILE.records"

# combine final list and Amass scrapped list for subJack
cat "$OUTFILE.records" tempAmass.txt | sort -u > tempSubJack.txt

# httprobe check for http servers
cat "$OUTFILE" | httprobe -c 100 | sort -u > "$OUTFILE.servers"

echo "===== SubJack ====="
# subdomain takeover check from amass output (should I check results too?)
"$subjackGoDir"/bin/subjack -w tempSubJack.txt -t 100 -timeout 30 -ssl -c "$subjackGoDir"/src/github.com/haccer/subjack/fingerprints.json -o "$OUTFILE.takeover"
echo "===== SubJack-Done ====="

echo "[-] SubDomains:"
cat "$OUTFILE"
echo "[-] HTTP Servers:"
cat "$OUTFILE.http"
echo "[-] TakeOvers:"
if [ -f "$OUTFILE.takeover" ]; then cat "$OUTFILE.takeover"; fi
if [ $wildcard -ne 0 ]; then
    echo "[!] Wildcard DNS detected, find the wildcard server IP and filter results excluding it"
fi

# remove temp files
rm tempAmass.txt tempMassAll.txt tempMassComHack.txt tempPreAlt.txt  tempNoIPPreAlt.txt tempAltDomains.txt tempMassAlt.txt tempMassAmass.txt tempSubJack.txt
