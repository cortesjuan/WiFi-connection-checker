#!/bin/sh

# WConnChecker
# Tool for Self-Connection to the WiFi Network
# https://github.com/cortesjuan/WiFi-connection-checker
# Based on the idea of YAWAC (Yet Another Wifi Auto Connect)
# https://github.com/mehdichaouch/YAWAC

. /etc/config/wconnchecker

APP=WConnChecker
LOGGER="logger -t $APP -s"
test_FailCount="0"

get_rand_mac() {
    macaddr=$(dd if=/dev/urandom bs=1024 count=1 2>/dev/null|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\)\(..\).*$/00:\2:\3:\4:\5:01/')
    echo $macaddr
}

get_rand_name() {
    newname=$rand_NamePREFIX$(head /dev/urandom | tr -dc "0-9a-f" | head -c16)
    echo $newname
}

get_BSSID() {
    mmac=$(uci show "wireless" | grep "bssid")
    mmac=${mymac##*=}
    mmac=${mymac:1:17}
    echo $mmac
}

check_ip() {
   if [ "$test_DHCPIP" -eq "1" ]; then
      has_ip=$(ifconfig $wIFACE | grep "inet addr:")
      if [ "$has_ip" ]; then
         $LOGGER "Ok, IP detected"
         echo "1"
      else
         $LOGGER "FAIL, No IP detected"
         echo "0" 
      fi
   else
      echo "1"
   fi
}

check_ping() {
    if [ "$test_useNslookup" -eq "1" ]; then
       net=$(nslookup ${test_addr} | grep "Name:")
    else
       net=$(ping -c5 ${test_addr} | grep "time=")
    fi
    if [ "$net" ]; then
       $LOGGER "Ok, Ping or Nslookup response"
       echo "1"
    else
       $LOGGER "FAIL, No Ping or Nslookup response"
       echo "0"   
    fi 
}

check_conn() {
    #check for internet connection, 5 ping sends
    #or use nslookup response 
    Res="0"
    if [ "$test_Rule" -eq "1" ]; then
       if [[ "$(check_ping)" -eq "1" || "$(check_ip)" -eq "1" ]]; then         
          Res="1"
       fi
    elif [ "$test_Rule" -eq "2" ]; then 
       if [ "$(check_ping)" -eq "1" ]; then
          Res="1"
       fi       
    elif [ "$test_Rule" -eq "3" ]; then 
       if [ "$(check_ip)" -eq "1" ]; then
          Res="1"
       fi 
    else
       if [[ "$(check_ip)" -eq "1" && "$(check_ping)" -eq "1" ]]; then         
          Res="1"
       fi
    fi   
    echo "$Res"
}

is_blackLst() {
    nmac=$1
    nmac=$(echo $nmac | tr '[a-z]' '[A-Z]')
    Res="0"
    n=0
    while [ "1" ]; do
       n=$(expr "$n" + "1")
       if [ "$n" == "21" ]; then
          #too much counts, breaking loop!
          break
       fi
       bmac=no"$n"_macaddr
       eval bmac=\$$bmac
       bmac=$(echo $bmac | tr '[a-z]' '[A-Z]')

       if [ "$bmac" = "" ]; then
          #MAC not existing or empty. Assume it's the end of the wlist file
          break
       elif [ "$bmac" == "$nmac" ]; then
          Res="1"
          break
       fi   
    done
    echo "$Res"
}

net_change() {
    #Previous MAC address
    oldMAC=$(get_BSSID) 
    newMAC=$oldMAC
    COUNT=0
    forceFlag=$1
    $LOGGER "Performing network scan to $wIFACE searching $wSSID..."
    while true; do
       APFound=$(iw $wIFACE scan \
           | grep -i "SSID: $wSSID" -B 8 \
           | sed -e "s/(on $wIFACE)//" \
           | egrep "(BSS|signal)" \
           | awk '{printf $2 "|"}' \
           | sed -re 's/([^|]+)\|([^|]+)\|?/\2 \1\n/g' \
           | sort \
           | head -n 1)

       APBestMAC=${APFound#* }
       APBestSignal=${APFound% *}  
       if [ "$APBestMAC" == "" ]; then
          echo "Nothing found..."
          continue
       fi

       blackLst=$(is_blackLst ${APBestMAC})   
       if [ "$blackLst" == "1" ]; then
          $LOGGER "Black List member detected: $APBestMAC"
          APBestMAC=""
          continue
       fi

       if [ "$APBestMAC" == "$oldMAC" ]; then
          if [ "$oldMAC" != "$newMAC" ]; then
             $LOGGER "Found previous station: $oldMAC ($APBestSignal), canceling..."
          fi
          newMAC=$APBestMAC
          break
       fi
       newMAC=$APBestMAC
       $LOGGER "Found better station: $APBestMAC ($APBestSignal)" 
       if [ "$forceFlag" == "--force" ]; then
          $LOGGER "Force mode activated! No time to loop!"
          break
       fi
       COUNT=$(( $COUNT + 1 ))
       if [ "$COUNT" -gt "$scan_LIMIT" ]; then
          break
       fi
       sleep $scan_DELAY
    done
    netCHG=0
    if [ "$rand_Mac" -eq "1" ]; then
        netCHG=1
        $LOGGER "Changing MAC address..."
        uci set wireless."$wIFACEName".macaddr="$(get_rand_mac)"
        uci commit wireless
    fi
    if [ "$rand_Name" -eq "1" ]; then
        netCHG=1
        $LOGGER "Changing hostname..."
        uci set network."$wWANName".hostname="$(get_rand_name)"
        uci commit network
    fi
    if [ "$oldMAC" != "$newMAC" ]; then
        netCHG=1
        $LOGGER "Found better AP: $newMAC, was: $oldMAC "
        uci set wireless."$wIFACEName".disabled="0"
        uci set wireless."$wIFACEName".ssid="$wSSID"
        uci set wireless."$wIFACEName".device="$wIFACEDevice"
        uci set wireless."$wIFACEName".encryption="$wEncryption"
        uci set wireless."$wIFACEName".key="$wKey"
        uci set wireless."$wIFACEName".mode="sta"
        uci set wireless."$wIFACEName".network="$wIFACENetwork"
        uci set wireless."$wIFACEName".bssid="$newMAC"

        uci commit wireless    
    elif [ "$forceFlag" == "force" ]; then
        netCHG=1
        $LOGGER "AP did not change but force mode was activated! Reloading wifi..."  
    fi
    if [ $netCHG -eq 1 ]; then
        wifi
        sleep $NewConnCheckTimer
    fi
}

if [ "$1" = "" ]; then
        echo "No arguments supplied"
elif [ "$1" = "--force" ]; then
        net_change $1
elif [ "$1" = "--daemon" ]; then
        net_change
        while true; do
           is_connected=$(check_conn)
           if [ "$is_connected" = "1" ]; then
              test_FailCount=0
              $LOGGER "Ok, Connected"
              sleep $ConnCheckTimer
           else
              test_FailCount=$(( $test_FailCount + 1 ))
              if [ "$test_FailCount" -lt "$test_failLimit" ]; then
                    # Run a scan on the wifi interface, incase that would recover the connection
                    $LOGGER "Performing network scan..."
                    iw $wIFACE scan 2>&1 >/dev/null
                    sleep $scan_DELAY
              else
                    net_change
              fi
           fi
        done
else
        echo "Wrong arguments"
fi
