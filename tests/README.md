## Test Environment

The test files in this directory contains 2 data files for 2 cars. The data files (bltctl-devices.out & bltctl-scan.out) were assemble from bluetoothctl output. The VIN & MAC address are fake but for tests, it's perfect.


## Vehicles' data:
```
VIN               BLE LN             MAC Address
5YJ3F1FB9JF111111 Scc424e6b9eb21875C FF:EE:DD:CC:BB:AA
5YJ3F1FB9JF888888 S4a15fba3fa21e4ceC AA:BB:CC:DD:EE:FF

# Use the info here below to setup your test env.
export BLE_MAC_LIST="FF:EE:DD:CC:BB:AA|AA:BB:CC:DD:EE:FF"
export VIN_LIST="5YJ3F1FB9JF111111|5YJ3F1FB9JF888888"
export DEBUG=true # or false

# Default data files' path/filenames
export bltctlDevicesFile=/app/bltctl-devices.out
export bltctlScanFile=/app/bltctl-scan.out
```


## bluetoothctl-file (script)

- When running tests using the data files, `bluetoothctl-file` interacts with our application the same way `bluetoothctl` does. It currently supports the `scan on` and `devices` commands. Those 2 commands are currently the only one that our application uses.
- bluetoothctl-file doesn't need any argument and by default it will use the path/filenames mentioned above but to change the path/filenames, you just need to export the 2 variables. Here's an example:

```
export bltctlDevicesFile=/MyOwnDataFiles/bltctl-my-devices.out
export bltctlScanFile=/MyOwnDataFiles/bltctl-my-scan.out
```
