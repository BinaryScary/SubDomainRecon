#!/bin/bash

# amass, massdns, altdns, commonspeak
# all.txt, commonspeak****, words.txt, resolvers.txt
# full paths
listDir="/root/ToolKit/wordlists"
massDir="/root/ToolKit/Tools/massdns"
commonDir="/root/ToolKit/Tools/commonspeak"

if [ $# -lt 2 ]; then
    echo "[!] Usage: SubDomainRecon.sh [domain] [out-file]"
    exit 1
fi

DOMAIN=$1
OUTFILE=$2

# amass scrape
echo "===== AMASS ====="
amass enum --passive -d $DOMAIN -o tempAmass.txt
if [ $? -ne 0 ]; then
    echo "AMASS Failed"
	exit 1
fi
cat tempAmass.txt | massdns -r "$massDir"/lists/resolvers.txt -t A -o S -w tempMassAmass.txt
if [ $? -ne 0 ]; then
    echo "massdns amass Failed"
	exit 1
fi

# massdns all.txt
echo "===== all.txt ====="
"$massDir"/scripts/subbrute.py "$listDir"/all.txt $DOMAIN | massdns -r "$massDir"/lists/resolvers.txt -t A -o S -w tempMassAll.txt
if [ $? -ne 0 ]; then
    echo "massdns all.txt Failed"
	exit 1
fi

# massdns hackernews commonspeak
echo "===== CommonSpeak ====="
comHackList=$(ls -t "$commonDir"/hackernews/output/compiled | head -1)
cat "$commonDir"/hackernews/output/compiled/$comHackList | massdns -r "$massDir"/lists/resolvers.txt -t A -o S -w tempMassComHack.txt
if [ $? -ne 0 ]; then
    echo "massdns commonspeak Failed"
	exit 1
fi

# trim results, combine and remove unique entries
cat tempMassAll.txt tempMassComHack.txt tempMassAmass.txt | awk '{print $3}' | sed 's/\.$//g' | sort -u > tempPreAlt.txt

# remove IP's
sed '/^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/d' tempPreAlt.txt > tempNoIPPreAlt.txt

# create altdns list
echo "===== AltDNS ====="
altdns -i tempNoIPPreAlt.txt -o tempAltDomains.txt -w "$listDir"/words.txt 
if [ $? -ne 0 ]; then
    echo "AltDNS Failed"
	exit 1
fi

# massdns altdns
cat tempAltDomains.txt | massdns -r "$massDir"/lists/resolvers.txt -t A -o S -w tempMassAlt.txt
if [ $? -ne 0 ]; then
    echo "massdns AltDNS Failed"
	exit 1
fi

# combine all lists
cat tempMassAlt.txt | awk '{print $3}' | sed 's/\.$//g' | cat - tempPreAlt.txt | sort -u > "$OUTFILE"

echo "[-] Done!"
# remove temp files
rm tempAmass.txt tempMassAll.txt tempMassComHack.txt tempPreAlt.txt  tempNoIPPreAlt.txt tempAltDomains.txt tempMassAlt.txt tempMassAmass.txt
