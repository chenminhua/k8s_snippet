#!/bin/bash
# 此脚本用于在azure上创建一台虚拟机
az group create --name test --location southeastasia

az network vnet create -g test -n testvnet --address-prefix 10.0.1.0/24
az network vnet subnet create -g test --vnet-name testvnet -n testsubnet --address-prefix 10.0.1.0/24

az network public-ip create -g test -n test-ip1 --allocation-method Static

az network nic create -g test --vnet-name testvnet -n test1-nic --subnet testsubnet --private-ip-address 10.0.1.10 --public-ip-address test-ip1

az vm create -g test -n tv1 --size Standard_B2ms --image CentOS --nics test1-nic --admin-username azure --ssh-key-value ~/.ssh/ata.pub
