#!/usr/bin/env bash

# bash script to start nut ups daemon
# Author: hhool
# Date: 2023-10-16
# Version: 1.0.0
# Usage: sudo bash ups_daemon.sh
# Description: bash script to start nut ups daemon on linux, only support linux one device
#              with manufacturer and product Cyber Power System, Inc. CP1500 AVR UPS
# Note: run this script as root user or sudo user only and run this script as daemon only
#       run this script as daemon only, do not run this script as cron job or systemd service
#       as daemon nohup sudo bash ups_daemon.sh > /dev/null 2>&1 &

# declare an array of manufacturer and product
# array of manufacturer and product
# Cyber Power System, Inc. CP1500 AVR UPS
# Cyber Power System, Inc. CP1500PFCLCDa

declare -a g_array_manufacturer_and_product=(
    "Zspace" "U2600")
    #"Cyber Power System, Inc." "CP1500PFCLCDa")

# global g_bus_number and g_device_number
g_bus_number=""
g_device_number=""

# stop current nut-upsd docker container forcefully
stopCurrentNutUpsdDockerContainer() {
    local containerId=$(docker ps -a | grep nut-upsd | awk '{print $1}')
    if [ -z "$containerId" ]; then
        echo "No container found for nut-upsd" >> /dev/null
    else
        echo "Container found for nut-upsd"
        echo "Container id = $containerId"
        # stop the container
        docker stop "$containerId"
        # remove the container
        docker rm "$containerId" -f
    fi
}

# start nut-upsd docker container
startNutUpsdDockerContainer() {
    g_bus_number=$1
    g_device_number=$2
    local device="/dev/bus/usb/$1/$2"
    echo "startNutUpsdDockerContainer ------------------------"
    echo "Device = $device"
    # start the container
    # run docker in sh
    docker run -d --name=nut-upsd --hostname=nut-upsd --restart=always --network=host --device $device -e UPS_NAME="zspace_ups" -e UPS_DESC="Server - zspace ups U2600" -e UPS_DRIVER="usbhid-ups" -e UPS_PORT="auto" -e API_USER="upsmon" -e API_PASSWORD="123456789ABCDEFGH" -e ADMIN_PASSWORD="123456789ABCDEFGH" -e SHUTDOWN_CMD="echo 'Home has no current. Proceeding to shut down...'" hhool/zspace_nut_ups:v1.0
}

# get lsusb output for the device ouput and find the device with Cyber Power Systems, Inc. as manufacturer
# get Bus and Device number from lsusb output for all devices
startBusAndDeviceNumber() {
    local manufacturer=$1
    local product=$2
    local lsusbOutput=$(lsusb)
    # Bus 001 Device 007: ID 0764:0501 Cyber Power System, Inc. CP1500 AVR UPS
    # get Bus number for the device output
    local busNumber=$(echo "$lsusbOutput" | grep "$manufacturer" | grep "$product" | awk '{print $2}' | awk -F ':' '{print $1}')
    # find deviceNumber first character that is a number and find the character that is not a number from first character
    local deviceNumber=$(echo "$lsusbOutput" | grep "$manufacturer" | grep "$product" | awk '{print $4}' | grep -o '^[0-9]*')
    echo "startBusAndDeviceNumber ------------------------"
    echo "busNumber = $busNumber"
    echo "deviceNumber = $deviceNumber"

    if [ -z "$busNumber" ] || [ -z "$deviceNumber" ]; then
        echo "No device found for $manufacturer $product" >> /dev/null
    else
        echo "Device found for manufacturer = $manufacturer"
        echo "Device found for product = $product"
        echo "Device found for busNumber = $busNumber"
        echo "Device found for deviceNumber = $deviceNumber"
        # start the nut-upsd docker container
        startNutUpsdDockerContainer "$busNumber" "$deviceNumber"
    fi
}

# enumerate through the array of manufacturers and products
# and start the bus and device number for each device
startDeviceWithManufacuresAndProducts() {
    local array_manufacturer_and_product=("${g_array_manufacturer_and_product[@]}")
    # get the length of the array
    local arrayLength=${#array_manufacturer_and_product[@]}
    # loop through the array
    for (( i=0; i<${arrayLength}; i+=2 ));
    do
        startBusAndDeviceNumber "${array_manufacturer_and_product[$i]}" "${array_manufacturer_and_product[$i+1]}"
    done
}

# check system is linux
checkSystemIsLinux() {
    local system=$(uname -s)
    if [ "$system" != "Linux" ]; then
        echo "System is not Linux"
        exit 1
    fi
}

# check system is root
checkSystemIsRoot() {
    local user=$(whoami)
    if [ "$user" != "root" ]; then
        echo "User is not root"
        exit 1
    fi
}

# stop current webnut docker container forcefully
stopCurrentWebnutDockerContainer() {
    local containerId=$(docker ps -a | grep webnut | awk '{print $1}')
    if [ -z "$containerId" ]; then
        echo "No container found for webnut" >> /dev/null
    else
        echo "Container found for webnut"
        echo "Container id = $containerId"
        # stop the container
        docker stop "$containerId"
        # remove the container
        docker rm "$containerId" -f
    fi
}

# start webnut docker container
startWebnutDockerContainer() {
    # start the container
    # run docker in sh
    docker run -d --name=webnut --hostname=webnut --restart=always --network=host -e UPS_HOST="127.0.0.1" -e UPS_PORT="3493" -e UPS_USER="upsmon" -e UPS_PASSWORD="123456789ABCDEFGH" teknologist/webnut:latest
}

# check docker container with name is running or not
checkDockerContainerIsRunning() {
    local containerName=$1
    local containerId=$(docker ps -a | grep "$containerName" | awk '{print $1}')
    if [ -z "$containerId" ]; then
        echo "No container found for $containerName" >> /dev/null
        return 1
    else
        echo "Container found for $containerName"
        echo "Container id = $containerId"
        # check if container is running or not
        local containerStatus=$(docker inspect -f '{{.State.Running}}' "$containerId")
        if [ "$containerStatus" == "true" ]; then
            echo "Container $containerName is running"
            return 0
        else
            echo "Container $containerName is not running"
            return 1
        fi
    fi
}

# time check every 30 seconds for the nut-upsd docker container and webnut docker container
# is running or not, if not running then start the docker container nut-upsd and webnut again
run_daemon() {
    local array_manufacturer_and_product=("${g_array_manufacturer_and_product[@]}")
    # get the length of the array
    local arrayLength=${#array_manufacturer_and_product[@]}
    # loop through the array
    for (( i=0; i<${arrayLength}; i+=2 ));
    do
        local manufacturer="${array_manufacturer_and_product[$i]}"
        local product="${array_manufacturer_and_product[$i+1]}"
        # check nut-upsd docker container is running or not
        checkDockerContainerIsRunning "nut-upsd"
        # check if nut-upsd docker container is running or not
        if [ $? -eq 0 ]; then
            echo "nut-upsd docker container is running"
        else
            echo "nut-upsd docker container is not running"
            # stop current nut-upsd docker container forcefully
            stopCurrentNutUpsdDockerContainer
            # start the device with manufacturer and product
            startDeviceWithManufacuresAndProducts
        fi

        # check webnut docker container is running or not
        checkDockerContainerIsRunning "webnut"
        # check if webnut docker container is running or not
        if [ $? -eq 0 ]; then
            echo "webnut docker container is running"
        else
            echo "webnut docker container is not running"
            # stop current webnut docker container forcefully
            stopCurrentWebnutDockerContainer
            # start webnut docker container
            startWebnutDockerContainer
        fi

        # get Bus and Device number from lsusb output for all devices
        local lsusbOutput=$(lsusb)
        local busNumber=$(echo "$lsusbOutput" | grep "$manufacturer" | grep "$product" | awk '{print $2}' | awk -F ':' '{print $1}')
        local deviceNumber=$(echo "$lsusbOutput" | grep "$manufacturer" | grep "$product" | awk '{print $4}' | grep -o '^[0-9]*')
        if [ -n "$g_bus_number" ] && [ -n "$g_device_number" ]; then
            if [ "$g_bus_number" == "$busNumber" ] && [ "$g_device_number" == "$deviceNumber" ]; then
                echo "g_bus_number = $g_bus_number"
                echo "g_device_number = $g_device_number"
                echo "busNumber = $busNumber"
                echo "deviceNumber = $deviceNumber"
                echo "g_bus_number and g_device_number is same as busNumber and deviceNumber"
            else
                echo "g_bus_number = $g_bus_number"
                echo "g_device_number = $g_device_number"
                echo "busNumber = $busNumber"
                echo "deviceNumber = $deviceNumber"
                echo "g_bus_number and g_device_number is not same as busNumber and deviceNumber"
                # stop current nut-upsd docker container forcefully
                stopCurrentNutUpsdDockerContainer
                # start the device with manufacturer and product
                startDeviceWithManufacuresAndProducts
            fi
        else
            echo "g_bus_number = $g_bus_number"
            echo "g_device_number = $g_device_number"
            echo "busNumber = $busNumber"
            echo "deviceNumber = $deviceNumber"
            echo "g_bus_number and g_device_number is empty"
            # stop current nut-upsd docker container forcefully
            stopCurrentNutUpsdDockerContainer
            # start the device with manufacturer and product
            startDeviceWithManufacuresAndProducts
        fi

        # sleep for 30 seconds
        sleep 30
    done
}


# check system is linux
checkSystemIsLinux
# check system is root
checkSystemIsRoot
# run daemon
run_daemon
# end of script
