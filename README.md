# FalconStor StorSafe Cache Capacity Nagios Check

This repository contains a Nagios check script for monitoring the cache capacity of FalconStor StorSafe storage systems. The script uses SNMP to gather cache capacity data and alerts based on user-defined warning and critical thresholds.

## Features

- Monitor used cache capacity (percentage and GB)
- Monitor available cache capacity (percentage and GB)
- Monitor total cache capacity (GB)
- Customizable warning and critical thresholds
- Supports multiple check types: UsedCache, AvailCache, TotalCache, and ALL

## Prerequisites

1. Install the `snmp` and `snmp-mibs-downloader` packages on your Nagios server.
2. Upload the MIB file of your FalconStor StorSafe (found on your FalconStor StorSafe server in `$ISHOME/etc/snmp/mibs`) to your Nagios server and place it in `/usr/share/snmp/mibs`.
3. Enable SNMP on your FalconStor StorSafe and set your community string.

## Installation

1. Clone this repository or download the `snmp_falconstor_cache.sh` script.
2. Place the script in your Nagios plugins directory, e.g., `/usr/local/nagios/libexec`.
3. Make the script executable with `chmod +x snmp_falconstor_cache.sh`.
4. Modify the `falcon_com` and `falcon_mib` variables in the script to match your configuration.
5. Test the script by executing it on your Nagios server.
6. Implement the script in your Nagios configuration by adding appropriate commands and service definitions (examples can be found in the script comments).

## Usage

./snmp_falconstor_cache.sh `-H` [FalconStor StorSafe IP-Address] `-c` [Check Type ('UsedCache', 'AvailCache', 'TotalCache', 'ALL')] `-W` [WARNING threshold] `-C` [CRITICAL threshold]

Replace `[FalconStor StorSafe IP-Address]` with the IP address of your FalconStor StorSafe system, choose the `[check type]` and set the `[WARNING threshold]` and `[CRITICAL threshold]` to the desired percentage values.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

## Contact

Jan Motulla - DE
github@mergedcloud.de
