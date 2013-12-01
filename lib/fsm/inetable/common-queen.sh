#Common queen state functions
SO=$1
SN=$2
interface=$3
[ -n $interface ] 

getentry () {
	local net_queenrange_start=$(get_fsmsetting net_queenrange_start)
	local net_queenrange_end=$(get_fsmsetting net_queenrange_end)
	[ -n "$net_queenrange_start" ] 
	[ -n "$net_queenrange_end" ] 
	case $1 in
		free |\
		ghost|\
		queen)
			p2ptbl show $gwiptbl \
			| cut -f1,2 \
			| egrep "[0-9]*"$'\t'"$1" \
			| awk -v Frst=$net_queenrange_start -v Last=$net_queenrange_end ' $1 >= Frst && $1 <= Last ' \
			| $2 \
			| head -n1 \
			| cut -f1
		;;
		owned)
			p2ptbl show $gwiptbl \
			| grep "$NodeId" \
			| cut -f1,2 \
			| awk -v Frst=$net_queenrange_start -v Last=$net_queenrange_end ' $1 >= Frst && $1 <= Last ' \
			| $2 \
			| head -n1 \
			| cut -f1
			;;
		*)
		exit 1
	esac
}

getoct3 ()  {
	# get our old IP if possible
	# if we had an IP in the past, log that we use it ;)
	local oct=$(getentry owned "sort -n") && [ -n "$oct" ] && logger -t fsm "Found old IP, re-using it"
	# get the lowest free addr if we dont previously owned a IP
	[ -z "$oct" ] && local oct=$(getentry free "sort -n") && [ -n "$oct" ] && logger -t fsm "Using free IP"
	# no free addrs? -> steal an addr from a random ghost
	[ -z "$oct" ] && local oct=$(getentry ghost "shuf") && [ -n "$oct" ] && logger -t fsm "Warning! No free IP's left. Got an IP from a ghost!"
	# no ghost addrs? -> steal an addr from a random queen
	[ -z "$oct" ] && local oct=$(getentry queen "shuf") && [ -n "$oct" ] && logger -t fsm "Warning! Address space exhaustion! Stealing IP from random Queen!"
	echo "$oct"
}

setsplash () {
	local gwip=$1
	local enabled=$(get_fsmsetting splash_enabled)
	if [ "$enabled" == "true" ]; then
		local real_iface=$(get_iface)
		local nosplash_server=$(get_fsmsetting splash_except_servers)
		local nosplash_clients=$(get_fsmsetting splash_except_clients)
		logmessage "[Splash] Redirecting internet traffic on TCP Port 80 to $gwip:81"
		logmessage "[Splash] Redirect DNS requests to $gwip:53"
		iptables -t nat -F inet_unsplashed_$interface
		iptables -t nat -A inet_unsplashed_$interface -i $real_iface -p tcp --dport 80 -j DNAT --to $gwip:81
		iptables -t nat -A inet_unsplashed_$interface -i $real_iface -p udp --dport 53 -j DNAT --to $gwip:53
		if [ -n "$nosplash_server" ]; then
			logmessage "[Splash] Adding server splash exceptions:"
			for host in $(echo $nosplash_server)
			do
				logmessage "[Splash] Never splashing traffic to $host"
				iptables -t nat -I inet_unsplashed_$interface -i $real_iface -d $host -j ACCEPT
			done
		fi
		if [ -n "$nosplash_clients" ]; then
			logmessage "[Splash] Adding client splash exceptions:"
			for mac in $(echo $nosplash_client)
			do
				logmessage "[Splash] Never splashing client $host"
				iptables -t nat -I inet_unsplashed_$interface 1 -m mac --mac-source $mac -j ACCEPT
			done
		fi
	else
		logmessage "[Splash] Splash disabled, allowing all traffic to pass"
	fi
}

mesh_set_dhcp() {
	local start_ip=$1
	local end_ip=$2
	local netmask=$3
	local gateway=$4
	local dns=$5
	local iface=$(get_iface)
	local net_dhcpleasetime=$(get_fsmsetting net_dhcpleasetime)
	[ -n net_dhcpleasetime ]

	# Remove old DHCP settings
	sed \
    -e "/$interface settings/d" \
    -i "/tmp/dnsmasq.conf"
	# Write new settings
	logmessage "Setting new DHCP server parameters:"
	logmessage "Start IP: $start_ip End IP: $end_ip Netmask: $netmask DHCP-Leasetime: $net_dhcpleasetime"
	echo "dhcp-range=$iface,$start_ip,$end_ip,$netmask,$net_dhcpleasetime # $interface settings" \
		>> "/tmp/dnsmasq.conf"
	if [ -n "$gateway" ]; then
		logmessage "Setting DHCP-Lease gateway to: $gateway"
		echo "dhcp-option=$iface,3,$gateway # $interface settings" \
		>> "/tmp/dnsmasq.conf"
	fi
	if [ -n "$dns" ]; then
		logmessage "Setting DHCP-Lease DNS server(s) to: $dns"
		echo "dhcp-option=$iface,6,$(echo $dns | sed 's/ /,/g')  # $interface settings" \
		>> "/tmp/dnsmasq.conf"
	fi
	logmessage "Restarting DHCP server with new settings"
	/etc/init.d/dnsmasq restart || true
}

mesh_set_dhcp_fake() {
	local start_ip=$1
	local end_ip=$2
	local netmask=$3
	local fakeip=$4
	# Remove old DHCP settings
	sed \
    -e "/$interface settings/d" \
    -i "/tmp/dnsmasq.conf"
	# Write new settings
	logmessage "Setting new DHCP server parameters:"
	logmessage "Start IP: $start_ip End IP: $end_ip Netmask: $netmask DHCP-Leasetime: 5m"
	logmessage "Setting fake DNS record for all queries to: $fakeip"
	echo "dhcp-range=$(get_iface),$start_ip,$end_ip,$netmask,$DHCPLeaseTime # $interface settings" \
		>> "/tmp/dnsmasq.conf"
	echo "address=/#/$fakeip # $interface settings" \
		>> "/tmp/dnsmasq.conf"
	logmessage "Restarting DHCP server with new settings"
	/etc/init.d/dnsmasq restart || true
}


mesh_remove_dhcp() {
	# Remove old DHCP settings
	sed \
    -e "/$interface settings/d" \
    -i "/tmp/dnsmasq.conf"
	logmessage "Removing DHCP server settings"
}

get_bestgateway () {
	local gateways="$1"
	for host in $(echo $gateways)
	do
		if [ -n "$best" ]; then
			local pingresult="$(ping $host -c 4 | grep round-trip | cut -f4 -d'/')"
			if [ -n "$pingresult" ]; then
				local testresult=$(echo "$old_pingresult $pingresult" | awk '{if ($1 > $2) print 1; else print 0}')
				if [ -n "$testresult" -a "$testresult" -eq 1 ]; then
					local best="$host"
				fi
			fi
		else
			local pingresult=$(ping $host -c 4 | grep round-trip | cut -f4 -d'/')
			if [ -n "$pingresult" ]; then
				local old_pingresult="$pingresult"
				local best="$host"
			fi
		fi
	done
	echo $best
}
