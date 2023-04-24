#!/bin/bash
set -x  
# Nagios check script for FalconStor StorSafe Cache Capacity
# File name: snmp_falconstor_cache.sh
# Version: 2.0.0
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
#     check_command           check_falconstor_cache!ALLCache!95!97
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
      echo -e "Usage: $(basename $0) [-H FalconStor StorSafe IP-Address] [-c CHECK TYPE ('UsedCache', 'AvailCache', 'TotalCache', 'ALLCache', 'LocalCluster')]\n       -c UsedCache/ALLCache [-W WARNING threshold] [-C CRITICAL threshold]"
      exit 1
      ;;
    # Print error message and exit if option requires an argument but not provided
    : )
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Set default thresholds if needed and check_type MIB objects
if [ "$check_type" = "UsedCache" ] || [ "$check_type" = "ALLCache" ]; then
  if [ -z "$warning_threshold" ] || [ -z "$critical_threshold" ]; then
    echo "Usage: $(basename $0) -c UsedCache/ALLCache requires -W and -C options." >&2
    exit 1
  fi
    if [ "$check_type" = "UsedCache" ]; then
      objects_num=(   "CacheCapacityUsed" 
                      "CacheCapacityPercentUsed")
    elif [ "$check_type" = "ALLCache" ]; then
      objects_num=(   "CacheCapacityUsed" 
                      "CacheCapacityPercentUsed"
                      "BackupCacheCapacityAvailable" 
                      "CacheCapacityPercentFree"
                      "CacheCapacitytotal")
    fi
    check_format="num"
elif [ "$check_type" = "AvailCache" ]; then
  objects_num=(   "BackupCacheCapacityAvailable" 
                  "CacheCapacityPercentFree")
  check_format="num"
elif [ "$check_type" = "TotalCache" ]; then
  objects_num=(    "CacheCapacitytotal")
  check_format="num"
elif [ "$check_type" = "LocalCluster" ]; then
  objects_str="falcSIRClusterName"
  objects_num=(   "falcSIRClusterDataDiskTotal" 
                  "falcSIRClusterDataDiskAvailable" 
                  "falcSIRClusterDataDiskAvailablePercentage" 
                  "falcSIRClusterIndexDiskTotal" 
                  "falcSIRClusterIndexDiskAvailable"
                  "falcSIRClusterIndexDiskAvailablePercentage"
                  "falcSIRClusterRepositoryObjectUsed"
                  "falcSIRClusterRepositoryObjectAvailablePercentage"
                  "falcSIRClusterFolderDiskTotal"
                  "falcSIRClusterFolderDiskAvailablePercentage")
  check_format="str"
fi

# Set variables for SNMP community string, MIB file path and MIB-Object arrays
falcon_com="falcon"
falcon_mib="/usr/share/snmp/mibs/FALCONSTOR-MIB.txt"

# Initialize "counter" variable to loop through the arrays
counter=0

# Loop through each object in the "objects_str" array, if check_format is str and get snmp data, cut it to contain everything after the last colon without the first space
if [ "$check_format" = "str" ]; then
  # Initialize results array
  output_array_str=()
  for object in "${objects_str[@]}"; do
    output=$(snmpwalk -v2c -c $falcon_com -m $falcon_mib $falcon_ip $object | awk -F':' '{sub(/^ /, "", $NF); print $NF}')
    # Check if $output is empty - if so, exit with exit code 1 (WARNING)
    [ -z "$output" ] && { echo "WARNING: At least one object returned empty."; exit 1; }
    # Save the results in the array
    output_array_str[$counter]=$output
    counter=$((counter + 1))
  done
  check_format=num
fi

# Loop through each object in the "objects_num" array, if check_format is num and get snmp data, cut it to contain everything after the last colon without the first space and to only decimals
if [ "$check_format" = "num" ]; then
  # Initialize results array
  output_array_num=()
  for object in "${objects_num[@]}"; do
    output=$(snmpwalk -v2c -c $falcon_com -m $falcon_mib $falcon_ip $object | awk -F':' '{sub(/^ /, "", $NF); print $NF}')
    output_num=$(echo "$output" | grep -oP '\d+(\.\d+)?')
    # Check if $output_num is empty - if so, exit with exit code 1 (WARNING)
    [ -z "$output_num" ] && { echo "WARNING: At least one object returned empty."; exit 1; }
    # Save the results in the array
    output_array_num[$counter]=$output_num
    counter=$((counter + 1))
  done
fi

# Output data to nagios according to the check_type
if [ "$check_type" = "UsedCache" ] || [ "$check_type" = "ALLCache" ]; then
  # Check if the values are above warning or critical thresholds for Used Cache-Capacity and make arrays ready for output
  if [ $(echo "${output_array_num[1]} > $critical_threshold" | bc -l) -eq 1 ]; then
    output_array_num[0]="SERVICE STATUS: CRITICAL - Used Cache-Capacity: ${output_array_num[0]}GB"
    output_array_num[1]="SERVICE STATUS: CRITICAL - Used Cache-Capacity: ${output_array_num[1]}%"
  elif [ $(echo "${output_array_num[1]} > $warning_threshold" | bc -l) -eq 1 ]; then
    output_array_num[0]="SERVICE STATUS: WARNING - Used Cache-Capacity: ${output_array_num[0]}GB"
    output_array_num[1]="SERVICE STATUS: WARNING - Used Cache-Capacity: ${output_array_num[1]}%"
  else
    output_array_num[0]="SERVICE STATUS: OK - Used Cache-Capacity: ${output_array_num[0]}GB"
    output_array_num[1]="SERVICE STATUS: OK - Used Cache-Capacity: ${output_array_num[1]}%"
  fi
fi
if [ "$check_type" = "ALLCache" ] || [ "$check_type" = "AvailCache" ]; then
  if [ "$check_type" = "AvailCache" ]; then
    # Change the array indice-variables to get the right data
    array_index_0=0
    array_index_1=1
    critical_threshold="100-$critical_threshold"
    warning_threshold="100-$warning_threshold"
  elif [ "$check_type" = "ALLCache" ]; then
    array_index_0=2
    array_index_1=3
  fi
  used_prc=$(bc <<< "100-${output_array_num[$array_index_1]}")
  # Check if the values are above warning or critical thresholds for Available Cache-Capacity and make arrays ready for output
  if [ $(echo "$used_prc > $critical_threshold" | bc -l) -eq 1 ]; then
    output_array_num[$array_index_0]="SERVICE STATUS: CRITICAL - Available Cache-Capacity: ${output_array_num[$array_index_0]}GB"
    output_array_num[$array_index_1]="SERVICE STATUS: CRITICAL - Available Cache-Capacity: ${output_array_num[$array_index_1]}%"
  elif [[ $(echo "$used_prc > $warning_threshold" | bc -l) -eq 1 ]]; then
    output_array_num[$array_index_0]="SERVICE STATUS: WARNING - Available Cache-Capacity: ${output_array_num[$array_index_0]}GB"
    output_array_num[$array_index_1]="SERVICE STATUS: WARNING - Available Cache-Capacity: ${output_array_num[$array_index_1]}%"
  else
    output_array_num[$array_index_0]="SERVICE STATUS: OK - Available Cache-Capacity: ${output_array_num[$array_index_0]}GB"
    output_array_num[$array_index_1]="SERVICE STATUS: OK - Available Cache-Capacity: ${output_array_num[$array_index_1]}%"
  fi
fi

echo ${output_array_str[@]}
echo ${output_array_num[@]}