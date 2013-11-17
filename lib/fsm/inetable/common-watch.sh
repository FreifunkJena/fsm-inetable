#Common watcher functions
SO=$1
SN=$2
interface=$3
[ -n $interface ] 

vpn_fallback=$(uci -q get fsm.$interface.vpn_fallback)
queenmode=$(uci -q get fsm.$interface.net_queenmode)

return_queenmode () {
	local watcher=$(basename $0)
	logmessage "Queen-Mode set to: $queenmode"
	case $watcher in
		queen |\
		queen-vpn-routed |\
		queen-vpn-gwdhcp |\
		queen-vpn-bridge |\
		ghost)
		case $queenmode in
			routed |\
			default)
				logmessage "Using default queen mode -> Queen State"
				echo queen
			;;
			vpn-routed)
				logmessage "Running connection test for queen mode: $queenmode"
				if test_connectivity $interface vpn-routed; then 
					logmessage "Connection test OK -> Routed VPN Queen State"
					echo queen-vpn-routed
				elif [ "$vpn_fallback" == "true" ]; then
					logmessage "Connection test failed & fallback enabled -> Queen State"
					echo queen
			;;
			vpn-gwdhcp)
				logmessage "Running connection test for queen mode: $queenmode"
				if test_connectivity $interface vpn-gwdhcp; then 
					logmessage "Connection test OK -> DHCP Remote Gateway Queen State"
					echo queen-vpn-gwdhcp
				elif [ "$vpn_fallback" == "true" ]; then
					logmessage "Connection test failed & fallback enabled -> Queen State"
					echo queen
			;;
			vpn-bridge)
				logmessage "Running connection test for queen mode: $queenmode"
				if test_connectivity $interface vpn-bridge; then
					logmessage "Connection test OK -> VPN Queen State"
					echo queen-vpn-bridge
				elif [ "$vpn_fallback" == "true" ]; then
					logmessage "Connection test failed & fallback enabled -> Queen State"
					echo queen
				fi
			;;
			*)
				logmessage "Error: Invalid queen mode: $queenmode"
				exit 1
			;;
		esac
	;;
		*)
		case $queenmode in
			routed |\
			default)
				logmessage "Using default queen mode -> Queen State"
				echo queen
			;;
			vpn-routed)
				logmessage "Running connection test for queen mode: $queenmode"
				if test_connectivity $interface vpn-routed; then 
					logmessage "Connection test OK -> Routed VPN Queen State"
					echo queen-vpn-routed
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
			vpn-gwdhcp)
				logmessage "Running connection test for queen mode: $queenmode"
				if test_connectivity $interface vpn-gwdhcp; then 
					logmessage "Connection test OK -> DHCP Remote Gateway Queen State"
					echo queen-vpn-gwdhcp
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
			vpn-bridge)
				logmessage "Running connection test for queen mode: $queenmode"
				if test_connectivity $interface vpn-bridge; then
					logmessage "Connection test OK -> VPN Queen State"
					echo queen-vpn-bridge
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
				logmessage "Error: Invalid queen mode: $queenmode"
				exit 1
			;;
		esac
		;;
	esac
}