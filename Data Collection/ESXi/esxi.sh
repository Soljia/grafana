#!/bin/bash

#This script gets the stats for an ESXi Servers CPU and Memory
#It gets all CPU Cores via ssh and then passes the count to a while loop meaning no multiple lines per CPU
#Memory is collected via ESXCFG-Info --Hardware

#Modified by /u/imaspecialorder & /u/dantho & /u/DXM765 & /u/just_insane & /u/tylerhammer & /u/soljia

#Config File Location


#Get the Core Count via SNMP (previously SSH)
corecount=$(snmpwalk -m ALL -c public -v 2c $ESXIP 1.3.6.1.2.1.25.3.3.1.2 | wc -l)

#Prepare to start the loop and warn the user
echo "Press [CTRL+C] to stop..."

#Set i to 0
i=0

while :
do
        CPUs=()
        while [ $i -lt $corecount ];
        do
                let i=i+1
                CPUs[$i]="$(snmpget -v 2c -c Public $ESXIP HOST-RESOURCES-MIB::hrProcessorLoad."$i" -Ov)"
                CPUs[$i]="$(echo "${CPUs["$i"]}" | cut -c 10-)"
                echo "CPU"$i": ${CPUs["$i"]}%"
                curl -i -XPOST "http://$INFLUXIP/write?db=$DATABASE" --data-binary "esxi_stats,host=$HOST,type=cpu_usage,cpu_number=$i value=${CPUs[$i]}"
        done
                i=0
	
        #Now we can finally calculate used percentage
	kmem=$(snmpwalk -m ALL -c public -v 2c $ESXIP hrMemorySize | grep -oP '\d+\w+(?=\sKBytes$)')
        used=$(snmpwalk -m ALL -c public -v 2c $HOSTNAME hrSWRunPerfMem | grep -oP '\d+\w+(?=\sKBytes$)' | awk '{s+=$1} END {print s}')
        pcent=$((used / kmem))


        echo "Memory Used: $pcent%"


        curl -i -XPOST "http://$INFLUXIP/write?db=$DATABASE" --data-binary "esxi_stats,host=$HOST,type=memory_usage value=$pcent"

        #Wait for a bit before checking again
        sleep "$INTERVAL"

done
