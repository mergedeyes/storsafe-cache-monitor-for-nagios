#!/bin/bash

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
# 1. Upload the MIB file of your FalconStor StorSafe (you can find them on your FalconStor StorSafe server in $ISHOME/etc/snmp/mibs) to your Nagios server and place it into /usr/share/snmp/mibs.
# 2. Enable SNMP on your FalconStor StorSafe server and set your community string. You can find directions on the internet.
# 3. Upload this script to your Nagios server, place it in your script folder e.g. /usr/local/nagios/libexec and make it executable with "chmod +x snmp_falconstor_cache.sh".
# 4. Modify the variables "falcon_com" and "falcon_mib" to match your configuration.
# 5. Test the script by executing it on your Nagios server.
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

#############################################################    SCRIPT START    #############################################################
# Set variables for SNMP community string and MIB file path
falcon_com="falcon"
falcon_mib="/usr/share/snmp/mibs/FALCONSTOR-MIB.txt"

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
      echo -e "Usage: $(basename $0) [-H FalconStor StorSafe IP-Address] [-c CHECK TYPE ('UsedCache', 'AvailCache', 'TotalCache', 'ALLCache', 'LocalCluster')]\n       -c UsedCache/AvailCache/ALLCache [-W WARNING threshold] [-C CRITICAL threshold]"
      exit 1
      ;;
    # Print error message and exit if option requires an argument but not provided
    : )
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Set check_type MIB objects and default thresholds if needed
# Check if -W and -C are set if required
if [ "$check_type" = "UsedCache" ] || [ "$check_type" = "AvailCache" ] || [ "$check_type" = "ALLCache" ]; then
  if [ -z "$warning_threshold" ] || [ -z "$critical_threshold" ]; then
    echo "Usage: $(basename $0) -c $check_type requires -W and -C options." >&2
    exit 1
  fi
    if [ "$check_type" = "UsedCache" ]; then
      objects_num=(   "CacheCapacityPercentUsed"
                      "CacheCapacityUsed")
      elif [ "$check_type" = "ALLCache" ]; then
        objects_num=(   "CacheCapacityPercentUsed"
                        "CacheCapacityUsed"
                        "CacheCapacityPercentFree"
                        "BackupCacheCapacityAvailable"
                        "CacheCapacitytotal")
      elif [ "$check_type" = "AvailCache" ]; then
        objects_num=(   "CacheCapacityPercentFree"
                        "BackupCacheCapacityAvailable")
    fi
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

# Initialize "counter" variable to loop through the arrays
counter=0

# To later check if array for str needs to be output or not
check_if_str_was_set=""

#############################################################    LOOP THROUGH ARRAYS    #############################################################
# Loop through each object in the "objects_str" array, if check_format is str and get snmp data, cut it to contain everything after the last colon without the first space
if [ "$check_format" = "str" ]; then
  check_if_str_was_set=1
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
  # Reset counter
  counter=0
  check_format=num
fi

# Loop through each object in the "objects_num" array, if check_format is num and get snmp data, cut it to contain everything after the last colon without the first space and to only decimals
if [ "$check_format" = "num" ]; then
  for object in "${objects_num[@]}"; do
    output=$(snmpwalk -v2c -c $falcon_com -m $falcon_mib $falcon_ip $object | awk -F':' '{sub(/^ /, "", $NF); print $NF}')
    output_num=$(echo "$output" | grep -oP '\d+(\.\d+)?')
    # Check if $output_num is empty - if so, exit with exit code 1 (WARNING)
    [ -z "$output_num" ] && { echo "WARNING: At least one object returned empty."; exit 1; }
    # Save the results in an array
    output_array_num[$counter]="$output_num"
    output_array_num_perf[$counter]="$output_num"
    output_perf_object[$counter]="$object"
    counter=$((counter + 1))
  done
fi

# Set default exit code
exit_code=0

#############################################################    FORMAT OUTPUT    #############################################################
#############################################################    UsedCache && AvailCache    #############################################################
# Output data to nagios according to the check_type
if [ "$check_type" = "ALLCache" ] || [ "$check_type" = "UsedCache" ]; then
  # Check if the values are above warning or critical thresholds for Used Cache-Capacity and reuse arrays/make arrays ready for output, set exit codes
  if [ $(echo "${output_array_num[0]} > $critical_threshold" | bc -l) -eq 1 ]; then
    output_array_num[1]="SERVICE STATUS: CRITICAL - Used Cache-Capacity: ${output_array_num[1]}GB\n"
    output_array_num[0]="SERVICE STATUS: CRITICAL - Used Cache-Capacity: ${output_array_num[0]}%\n"
    exit_code=2
  elif [ $(echo "${output_array_num[0]} > $warning_threshold" | bc -l) -eq 1 ]; then
    output_array_num[1]="SERVICE STATUS: WARNING - Used Cache-Capacity: ${output_array_num[1]}GB\n"
    output_array_num[0]="SERVICE STATUS: WARNING - Used Cache-Capacity: ${output_array_num[0]}%\n"
    exit_code=1
  else
    output_array_num[1]="SERVICE STATUS: OK - Used Cache-Capacity: ${output_array_num[1]}GB\n"
    output_array_num[0]="SERVICE STATUS: OK - Used Cache-Capacity: ${output_array_num[0]}%\n"
  fi
fi
if [ "$check_type" = "ALLCache" ] || [ "$check_type" = "AvailCache" ]; then
  if [ "$check_type" = "AvailCache" ]; then
    # Set the array indice-variables to get the right data for different check_type
    array_index_0=1
    array_index_1=0
    # Recalculate correct threshold values
    critical_threshold_avail=$(echo "100-$critical_threshold" | bc -l)
    warning_threshold_avail=$(echo "100-$warning_threshold" | bc -l)
  elif [ "$check_type" = "ALLCache" ]; then
    array_index_0=3
    array_index_1=2
    critical_threshold_avail=$critical_threshold
    warning_threshold_avail=$warning_threshold
  fi
  used_prc=$(bc <<< "100-${output_array_num[$array_index_1]}")
  # Check if the values are above warning or critical thresholds for Available Cache-Capacity and reuse arrays/make arrays ready for output, set exit codes
  if [ $(echo "$used_prc > $critical_threshold_avail" | bc -l) -eq 1 ]; then
    output_array_num[$array_index_0]="SERVICE STATUS: CRITICAL - Available Cache-Capacity: ${output_array_num[$array_index_0]}GB\n"
    output_array_num[$array_index_1]="SERVICE STATUS: CRITICAL - Available Cache-Capacity: ${output_array_num[$array_index_1]}%\n"
    exit_code=2
  elif [[ $(echo "$used_prc > $warning_threshold_avail" | bc -l) -eq 1 ]]; then
    output_array_num[$array_index_0]="SERVICE STATUS: WARNING - Available Cache-Capacity: ${output_array_num[$array_index_0]}GB\n"
    output_array_num[$array_index_1]="SERVICE STATUS: WARNING - Available Cache-Capacity: ${output_array_num[$array_index_1]}%\n"
    exit_code=1
  else
    output_array_num[$array_index_0]="SERVICE STATUS: OK - Available Cache-Capacity: ${output_array_num[$array_index_0]}GB\n"
    output_array_num[$array_index_1]="SERVICE STATUS: OK - Available Cache-Capacity: ${output_array_num[$array_index_1]}%\n"
  fi
fi
if [ "$check_type" = "TotalCache" ]; then
  output_array_num[0]="SERVICE STATUS: OK - Total Cache-Capacity: ${output_array_num[0]}GB\n"
fi
if [ "$check_type" = "ALLCache" ]; then
  output_array_num[4]="SERVICE STATUS: OK - Total Cache-Capacity: ${output_array_num[4]}GB\n"
fi
if [ "$check_type" = "LocalCluster" ]; then
  output_array_str[0]="Deduplication cluster name: ${output_array_str[0]}\n"
  output_array_num[0]="Total repository data storage: ${output_array_num[0]}MB\n"
  output_array_num[1]="Repository data storage available: ${output_array_num[1]}MB\n"
  output_array_num[2]="Percentage of total repository data storage that is available: ${output_array_num[2]}%\n"
  output_array_num[3]="Total index storage: ${output_array_num[3]}MB\n"
  output_array_num[4]="Index storage available: ${output_array_num[4]}MB\n"
  output_array_num[5]="Percentage of total index storage that is available: ${output_array_num[5]}%\n"
  output_array_num[6]="Percentage of index cache capacity that is used: ${output_array_num[6]}%\n"
  output_array_num[7]="Percentage of index cache capacity that is available: ${output_array_num[7]}%\n"
  output_array_num[8]="Total folder space: ${output_array_num[8]}MB\n"
  output_array_num[9]="Percentage of total folder space that is available: ${output_array_num[9]}%\n"

fi

# Save performance data of all objects in a variable "output_perf" for each check_type
output_perf=" |"
output_perf_object_index=0
if [ "$check_type" = "LocalCluster" ]; then
  for output in "${output_array_num_perf[@]}"; do
    if [ $(echo "$output <= 100" | bc -l) -eq 1 ]; then
      output="${output}%"
      elif [ $(echo "$output > 100" | bc -l) -eq 1 ]; then
        output="${output}MB"
    fi
    output_perf="$output_perf ${output_perf_object[$output_perf_object_index]}=$output"
    output_perf_object_index=$((output_perf_object_index + 1))
  done
  elif [ "$check_type" = "UsedCache" ]; then
    output_perf="$output_perf used_cache_perc=${output_array_num_perf[0]}%;$warning_threshold;$critical_threshold used_cache_gb=${output_array_num_perf[1]}GB"
  elif [ "$check_type" = "AvailCache" ]; then
    output_perf="$output_perf free_cache_perc=${output_array_num_perf[0]}%;$warning_threshold;$critical_threshold free_cache_gb=${output_array_num_perf[1]}GB"
  elif [ "$check_type" = "TotalCache" ]; then
    output_perf="$output_perf total_cache_gb=${output_array_num_perf[0]}GB"
  elif [ "$check_type" = "ALLCache" ]; then
    output_perf="$output_perf used_cache_perc=${output_array_num_perf[0]}%;$warning_threshold;$critical_threshold used_cache_gb=${output_array_num_perf[1]}GB free_cache_perc=${output_array_num_perf[2]}%;$(echo "100-${warning_threshold}" | bc -l);$(echo "100-${critical_threshold}" | bc -l) free_cache_gb=${output_array_num_perf[3]}GB total_cache_gb=${output_array_num_perf[4]}GB"
fi

# Output Status Information Text and Performance Data
if [ -z $check_if_str_was_set ]; then
  echo -e ${output_array_num[@]} ${output_perf}
  exit $exit_code
  else
  echo -e ${output_array_str[@]} ${output_array_num[@]} ${output_perf}
  exit $exit_code
fi