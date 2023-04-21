#!/bin/bash

# Nagios check script for FalconStor StorSafe CacheCapacity
# File name: snmp_falconstor_cache.sh
# Version: 1.0.2
# Author: Jan Motulla - DE
# Contact: github@mergedcloud.de

# Usage:
#                               Arguments:
#                   -H [HOST IP-ADDRESS]
#                   -w [WARNING THRESHOLD FOR PERCENTAGE]
#                   -c [CRITICAL THRESHOLD FOR PERCENTAGE]
#
# 1. Upload the MIB file of your FalconStor StorSafe (you can find them on your FalconStor StorSafe server in $ISHOME/etc/snmp/mibs) to your Nagios machine and place it into /usr/share/snmp/mibs.
# 2. Enable SNMP on your FalconStor StorSafe and set your community string. You can find directions on the internet.
# 3. Upload this script to your Nagios machine and place it in your script folder e.g. /usr/local/nagios/libexec and make it executable with "chmod +x snmp_falconstor_cache.sh".
# 4. Change the following variables "falcon_com" and "falcon_mib" so it matches your configuration.
# 5. Test the script by simply executing it on your Nagios machine.
# 6. Implement the script.
#
# Examples for commands.cfg and services.cfg:
#
#                               commands.cfg
# define command {
#     command_name    check_falconstor_cache
#     command_line    $USER1$/snmp_falconstor_cache.sh -H $HOSTADDRESS$ -w $ARG1$ -c $ARG2$
# }
#
#                               services.cfg
# define service {
#     use                     generic-service,srv-pnp
#     hostgroup_name          FS_StorSafe
#     servicegroups           40-ALG-10_cache_cap
#     service_description     40-ALG-20 Cache-Capacity
#     check_command           check_falconstor_cache!95!97
#     check_interval          60
#     notification_interval   90
# }

#################################
#                               #
#        SCRIPT START           #
#                               #
#################################

# Parse arguments
while getopts ":H:w:c:" opt; do
  case ${opt} in
    H )
      falcon_ip=$OPTARG
      ;;
    w )
      warning_threshold=$OPTARG
      ;;
    c )
      critical_threshold=$OPTARG
      ;;
    \? )
      echo "Usage: $(basename $0) [-H FalconStor StorSafe IP-Address] [-w WARNING threshold] [-c CRITICAL threshold]"
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Set variables
# Community string of your FalconStor
falcon_com="falcon"
# Directory of the MIB file
falcon_mib="/usr/share/snmp/mibs/FALCONSTOR-MIB.txt"
# Arrays for MIB-Object to use in the following for-loops
objects_gb=("CacheCapacitytotal" "CacheCapacityUsed" "BackupCacheCapacityAvailable")
objects_perc=("CacheCapacityPercentUsed" "CacheCapacityPercentFree")

# Set variable "counter" to 0 to loop through the first array
counter=0

# Run the snmpwalk command for each object in the array "objects_gb" to output the GB values
for object in "${objects_gb[@]}"; do
    # Get the snmp data and cut it to contain everything after the last colon
    output=$(snmpwalk -v2c -c $falcon_com -m $falcon_mib $falcon_ip $object | awk -F ':' '{print $NF}')
    # Format the output to only contain numbers and decimals
    output_gb=$(echo "$output" | grep -oP '\d+(\.\d+)?')

    # Check if $output_gb is empty - if so, exit with exit code 1 (WARNING)
    [ -z "$output_gb" ] && { echo "WARNING: At least one object returned empty."; exit 1; }

    sleep 1

    counter=$((counter + 1))

    # Save the data in variables
    if [[ $counter -eq 1 ]]; then
      output_tot_gb_info="SERVICE STATUS: OK - Total Cache-Capacity: $output"
      output_tot_gb_perf="total_cache_gb=${output_gb}GB"
    elif [[ $counter -eq 2 ]]; then
      output_used_gb_info="SERVICE STATUS: OK - Used Cache-Capacity: $output"
      output_used_gb_perf="used_cache_gb=${output_gb}GB"
    elif [[ $counter -eq 3 ]]; then
      output_avai_gb_info="SERVICE STATUS: OK - Available Cache-Capacity: $output"
      output_avai_gb_perf="free_cache_gb=${output_gb}GB"
    fi
done

# Set variable "counter" to 0 for the second array
counter=0

# Run the snmpwalk command for each object in the array "objects_perc" to output the percentage values
for object in "${objects_perc[@]}"; do
    # Get the snmp data and cut it to contain everything after the last colon
    output=$(snmpwalk -v2c -c $falcon_com -m $falcon_mib $falcon_ip $object | awk -F ':' '{print $NF}')
    # Format the output to only contain numbers and decimals
    output_perc=$(echo "$output" | grep -oP '\d+(\.\d+)?')

    # Check if $output_perc is empty - if so, exit with exit code 1 (WARNING)
    [ -z "$output_perc" ] && { echo "WARNING: At least one object returned empty."; exit 1; }

    sleep 1

    counter=$((counter + 1))

    # Save the data in variables
    if [[ $counter -eq 1 ]]; then
      # Check if used Cache-Capacity is over critical threshold
      if [[ $output_perc > $critical_threshold ]]; then
        # Output data of used capacity to Nagios
        echo "SERVICE STATUS: CRITICAL - Used Cache-Capacity in percent: $output | used_cache_perc=$output_perc%"
        # Exit script with exit code 2 = CRITICAL
        exit 2
      # Check if used Cache-Capacity is over warning threshold
      elif [[ $output_perc > $warning_threshold ]]; then
        # Output data of used capacity to Nagios
        echo "SERVICE STATUS: WARNING - Used Cache-Capacity in percent: $output | used_cache_perc=$output_perc%"
        # Exit script with exit code 1 = WARNING
        exit 1
      fi
      output_used_perc_info="SERVICE STATUS: OK - Used Cache-Capacity in percent: $output"
      output_used_perc_perf="used_cache_perc=$output_perc%"
    elif [[ $counter -eq 2 ]]; then
      output_avai_perc_info="SERVICE STATUS: OK - Available Cache-Capacity in percent: $output"
      output_avai_perc_perf="free_cache_perc=$output_perc%"
    fi
done

# Output all data to Nagios
echo "$output_used_perc_info\n$output_used_gb_info\n$output_avai_perc_info\n$output_avai_gb_info\n$output_tot_gb_info | $output_used_perc_perf $output_used_gb_perf $output_avai_perc_perf $output_avai_gb_perf $output_tot_gb_perf"
# Exit script with exit code 0 = OK
exit 0