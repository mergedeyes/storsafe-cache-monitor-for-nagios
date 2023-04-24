#!/bin/bash

# Nagios check script for FalconStor StorSafe Cache Capacity
# File name: snmp_falconstor_cache.sh
# Version: 1.1.4
# Author: Jan Motulla - DE
# GitHub: https://github.com/mergedeyes/storsafe-cache-monitor-for-nagios
# Contact: github@mergedcloud.de

# Usage:
#                               Arguments:
#                   -H [HOST IP-ADDRESS]
#                   -w [WARNING THRESHOLD PERCENTAGE]
#                   -c [CRITICAL THRESHOLD PERCENTAGE]
#
# 1. Upload the MIB file of your FalconStor StorSafe (you can find them on your FalconStor StorSafe server in $ISHOME/etc/snmp/mibs) to your Nagios machine and place it into /usr/share/snmp/mibs.
# 2. Enable SNMP on your FalconStor StorSafe and set your community string. You can find directions on the internet.
# 3. Upload this script to your Nagios machine and place it in your script folder e.g. /usr/local/nagios/libexec and make it executable with "chmod +x snmp_falconstor_cache.sh".
# 4. Modify the variables "falcon_com" and "falcon_mib" to match your configuration.
# 5. Test the script by executing it on your Nagios machine.
# 6. Implement the script.
#
# Examples for commands.cfg and services.cfg:
#
#                               commands.cfg
# define command {
#     command_name    check_falconstor_cache
#     command_line    $USER1$/snmp_falconstor_cache.sh -H $HOSTADDRESS$ -c $ARG1$ -W $ARG2$ -C $ARG3$
# }
#
#                               services.cfg
# define service {
#     use                     generic-service,srv-pnp
#     hostgroup_name          FS_StorSafe
#     servicegroups           40-ALG-10_cache_cap
#     service_description     40-ALG-20 Cache-Capacity
#     check_command           check_falconstor_cache!ALL!95!97
#     check_interval          60
#     notification_interval   90
# }

#################################
#                               #
#        SCRIPT START           #
#                               #
#################################

# Parse command-line arguments
while getopts ":H:W:C:c:" opt; do
  case ${opt} in
    H )
      falcon_ip=$OPTARG
      ;;
    W )
      warning_threshold=$OPTARG
      ;;
    C )
      critical_threshold=$OPTARG
      ;;
    c )
      check_type=$OPTARG
      ;;
    # Print usage message and exit if invalid option is provided
    \? )
      echo -e "Usage: $(basename $0) [-H FalconStor StorSafe IP-Address] [-c CHECK TYPE ('UsedCache', 'AvailCache', 'TotalCache', 'ALL')]\n       -c UsedCache/ALL [-W WARNING threshold] [-C CRITICAL threshold]"
      exit 1
      ;;
    # Print error message and exit if option requires an argument but not provided
    : )
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Set default thresholds if check_type is AvailCache or TotalCache
if [ "$check_type" = "UsedCache" ] || [ "$check_type" = "ALL" ]; then
  if [ -z "$warning_threshold" ] || [ -z "$critical_threshold" ]; then
    echo "Usage: $(basename $0) -c UsedCache/ALL requires -W and -C options." >&2
    exit 1
  fi
elif [ "$check_type" = "AvailCache" ] || [ "$check_type" = "TotalCache" ]; then
  warning_threshold=100
  critical_threshold=100
fi

# Set variables for SNMP community string, MIB file path and MIB-Object arrays
falcon_com="falcon"
falcon_mib="/usr/share/snmp/mibs/FALCONSTOR-MIB.txt"
objects_gb=("CacheCapacitytotal" "CacheCapacityUsed" "BackupCacheCapacityAvailable")
objects_perc=("CacheCapacityPercentUsed" "CacheCapacityPercentFree")

# Set variable "counter" to 0 for the second array
counter=0

# Loop through each object in the "objects_perc" array to get the percentage values
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

        # Check if the values are above warning or critical thresholds for Used Cache-Capacity
        if [[ $(echo "$output_perc > $critical_threshold" | bc -l) -eq 1 ]]; then
            output_used_perc_info="SERVICE STATUS: CRITICAL - Used Cache-Capacity: $output"
        elif [[ $(echo "$output_perc > $warning_threshold" | bc -l) -eq 1 ]]; then
            output_used_perc_info="SERVICE STATUS: WARNING - Used Cache-Capacity: $output"
        else
            output_used_perc_info="SERVICE STATUS: OK - Used Cache-Capacity: $output"
        fi

        output_used_perc_perf="used_cache_perc=$output_perc%"
        # Save the output of $output_perc before it gets overwritten
        output_perc_save=$output_perc

    elif [[ $counter -eq 2 ]]; then

        # Check if the values are above warning or critical thresholds for Available Cache-Capacity
        if [[ $(echo "$output_perc_save > $critical_threshold" | bc -l) -eq 1 ]]; then
            output_avai_perc_info="SERVICE STATUS: CRITICAL - Available Cache-Capacity: $output"
        elif [[ $(echo "$output_perc_save > $warning_threshold" | bc -l) -eq 1 ]]; then
            output_avai_perc_info="SERVICE STATUS: WARNING - Available Cache-Capacity: $output"
        else
            output_avai_perc_info="SERVICE STATUS: OK - Available Cache-Capacity: $output"
        fi
        
        output_avai_perc_perf="free_cache_perc=$output_perc%"
    fi
done

# Initialize "counter" variable to 0 to loop through the first array
counter=0

# Loop through each object in the "objects_gb" array to get the GB values
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

        # Check if the values are above warning or critical thresholds for Used Cache-Capacity in GB
        if [[ $(echo "$output_perc_save > $critical_threshold" | bc -l) -eq 1 ]]; then
          output_used_gb_info="SERVICE STATUS: CRITICAL - Used Cache-Capacity: $output"
        elif [[ $(echo "$output_perc_save > $warning_threshold" | bc -l) -eq 1 ]]; then
          output_used_gb_info="SERVICE STATUS: WARNING - Used Cache-Capacity: $output"
        else
         output_used_gb_info="SERVICE STATUS: OK - Used Cache-Capacity: $output"
        fi
        
      output_used_gb_perf="used_cache_gb=${output_gb}GB"
    elif [[ $counter -eq 3 ]]; then

        # Check if the values are above warning or critical thresholds for Available Cache-Capacity in GB
        if [[ $(echo "$output_perc_save > $critical_threshold" | bc -l) -eq 1 ]]; then
            output_avai_gb_info="SERVICE STATUS: CRITICAL - Available-Cache-Capacity: $output"
        elif [[ $(echo "$output_perc_save > $warning_threshold" | bc -l) -eq 1 ]]; then
            output_avai_gb_info="SERVICE STATUS: WARNING - Available-Cache-Capacity: $output"
        else
            output_avai_gb_info="SERVICE STATUS: OK - Available-Cache-Capacity: $output"
        fi

      output_avai_gb_perf="free_cache_gb=${output_gb}GB"
    fi
done

# Output data to Nagios based on check type
if [[ $check_type == "UsedCache" ]]; then
    used_cache_perc=$(echo "$output_used_perc_info" | grep -oP '\d+(\.\d+)?')

    if (( $(echo "$used_cache_perc > $critical_threshold" | bc -l) )); then
        echo "$output_used_perc_info\n$output_used_gb_info | used_cache_perc=$used_cache_perc% $output_used_gb_perf"
        exit 2
    elif (( $(echo "$used_cache_perc > $warning_threshold" | bc -l) )); then
        echo "$output_used_perc_info\n$output_used_gb_info | used_cache_perc=$used_cache_perc% $output_used_gb_perf"
        exit 1
    else
        echo "$output_used_perc_info\nSERVICE STATUS: OK - Used Cache-Capacity: $output_used_gb_info | $output_used_perc_perf $output_used_gb_perf"
    fi

elif [[ $check_type == "AvailCache" ]]; then
    echo "$output_avai_perc_info\n$output_avai_gb_info | $output_avai_perc_perf $output_avai_gb_perf"
elif [[ $check_type == "TotalCache" ]]; then
    echo "$output_tot_gb_info | $output_tot_gb_perf"
elif [[ $check_type == "ALL" ]]; then
    echo "$output_used_perc_info\n$output_used_gb_info\n$output_avai_perc_info\n$output_avai_gb_info\n$output_tot_gb_info | $output_used_perc_perf $output_used_gb_perf $output_avai_perc_perf $output_avai_gb_perf $output_tot_gb_perf"

    if [[ $output_perc_save > $critical_threshold ]]; then
      exit 2
    elif [[ $output_perc_save > $warning_threshold ]]; then
      exit 1
    fi

fi

# Exit script with exit code 0 = OK
exit 0
