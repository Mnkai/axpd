#! /bin/bash
hex2dec(){
	echo 'ibase=16; obase=A; '"$1" | bc
}
checkbit(){
	[ $(( $1 & $(( 1 << $2 )) )) != 0 ]
}
rmmod -f battery
modprobe i2c-dev 
modprobe test_power

i=2
while [ "$i" -lt 13 ]
do
	if find /sys/devices/platform | grep -q 80860F41:04/i2c-$i/ 
	then
		export ADDR=$i
	fi
	i=`expr $i + 1 `
done

while true
do
	rmmod battery 2>/dev/null
	echo off > /sys/module/test_power/parameters/ac_online
	echo LION > /sys/module/test_power/parameters/battery_technology
	source_status_reg=$(i2cget -f -y $ADDR 0x34 0x00)
	charger_status_reg=$(i2cget -f -y $ADDR 0x34 0x01)
	if checkbit $source_status_reg 4
	then
		echo on > /sys/module/test_power/parameters/usb_online
		if checkbit $charger_status_reg 6
		then
			echo charging > /sys/module/test_power/parameters/battery_status
		else
			echo not-charging > /sys/module/test_power/parameters/battery_status
		fi
	else
		echo off > /sys/module/test_power/parameters/usb_online
		echo discharging > /sys/module/test_power/parameters/battery_status
	fi
	hex=$(i2cget -f -y $ADDR 0x34 0xb9 | cut -c 3- | tr a-z A-Z)
	capacity=$(expr $(hex2dec $hex) - 128)
	if [ $capacity -ge 0 ]
	then
		echo $capacity | tee /sys/module/test_power/parameters/battery_capacity
	fi
	sleep 10
done

