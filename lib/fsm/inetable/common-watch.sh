#Common watcher functions
SO=$1
SN=$2
interface=$3
[ -n $interface ] 

test_queenmode () {
	local watcher=$(basename $0)
	local net_queenmode="$1"
	local vpn_fallback=$(get_fsmsetting vpn_fallback)
	case $watcher in
		queen |\
		queen-vpn-routed |\
		queen-vpn-gwdhcp |\
		ghost)
			logmessage "Running connection test for queen mode: $net_queenmode"
			if test_connectivity $interface $net_queenmode; then 
				case $net_queenmode in
					vpn-routed)
						logmessage "Connection test OK -> Routed VPN Queen State"
						echo queen-vpn-routed
					;;
					vpn-gwdhcp)
						logmessage "Connection test OK -> DHCP Remote Gateway Queen State"
						echo queen-vpn-gwdhcp
					;;
					vpn-bridge)
						logmessage "Connection test OK -> VPN Queen State"
						echo queen-vpn-bridge
					;;
				esac
			elif [ "$vpn_fallback" == "true" ]; then
				logmessage "Connection test failed & fallback enabled -> Queen State"
				echo queen
			else
				#We only give a log message about becomming a ghost as the watcher script handles the rest
				logmessage "Connection test failed & fallback disabled -> Becoming a ghost (Boooo!)"
			fi
		;;
		queen-vpn-bridge |\
		drone |\
		testing)
			if test_connectivity $interface $net_queenmode; then 
				case $net_queenmode in
					vpn-routed)
						logmessage "Connection test OK -> Routed VPN Queen State"
						echo queen-vpn-routed
					;;
					vpn-gwdhcp)
						logmessage "Connection test OK -> DHCP Remote Gateway Queen State"
						echo queen-vpn-gwdhcp
					;;
					vpn-bridge)
						logmessage "Connection test OK -> VPN Queen State"
						echo queen-vpn-bridge
					;;
				esac
			elif [ "$vpn_fallback" == "true" ]; then
				logmessage "Connection test failed & fallback enabled -> Queen State"
				echo queen
			elif cloud_is_online; then
				logmessage "Connection test failed & cloud has gateways -> Drone State"
				echo drone
			else
				logmessage "Connection test failed & no gateways found -> Robinson State"
				echo robinson
			fi
		;;
		*)
			#We cannot be sure if we are in a state where we can test
			#the connection properly so we go into testing state
			logmessage "Queen state function called from unknown or default watcher script, entering connectiong testing mode"
			echo testing
		;;
	esac

}

return_queenstate () {
	local net_queenmode=$(get_fsmsetting net_queenmode)
	[ -n "$net_queenmode" ] || net_queenmode="default"
	logmessage "Queen-Mode set to: $net_queenmode"
	case $net_queenmode in
		routed |\
		default)
			logmessage "Using default queen mode -> Queen State"
			echo queen
		;;
		vpn-routed |\
		vpn-gwdhcp |\
		vpn-bridge)
			local return_state=$(test_queenmode $net_queenmode)
			echo $return_state
		;;
		*)
			logmessage "Error: Invalid queen mode: $net_queenmode"
			exit 1
		;;
	esac
}