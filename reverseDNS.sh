if [ $# -lt 1 ]; then
    echo "[!] Usage: SubDomainRecon.sh [ip-list]"
    exit 1
fi

while read ip; do
	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		buf=$(host "$ip" | awk '{ print $5 }' | sed ' s/\.$//g')
		if [ $? -eq 0 ] && [ $buf != "3(NXDOMAIN)" ]
		then
			echo "$buf"
		fi
	fi
done < $1
