#WConnChecker

WConnChecker is a tool for Self-Connection to the WiFi Network, based on the idea of YAWAC (Yet Another Wifi Auto Connect).

This project is thinking in cuban people that have OpenWRT and use ETECSA's WiFi network. 

WConnChecker has some features added:
- Set a random Name each boot and new connection
- Set Prefix for random Name
- Limit for how many times to search for AP
- Delay in seconds between iw scans
- Use nslookup or ping to test connection
- Check if exist IP assigned
- Rules for connection check
- Test Fail Limit to reconfigure the network with new values
- Black List of MAC.

For more information, please, read document YAWAC_README.md included. 

## Installation

Copy all the files in the router with the same folders tree and apply the right permissions.
```bash
cp -R ./wconnchecker/* /
chmod 644 /etc/config/wconnchecker
chmod 755 /etc/init.d/wconnchecker /usr/bin/wconnchecker.sh
```

Enable WConnChecker, to start on boot and run it.
```bash
/etc/init.d/wconnchecker enable
/etc/init.d/wconnchecker start
```


## Remove

Stop WConnChecker, disable the start on boot, and remove files.
```bash
/etc/init.d/wconnchecker stop
/etc/init.d/wconnchecker disable
rm -f /etc/config/wconnchecker /etc/init.d/wconnchecker /usr/bin/wconnchecker.sh
```

