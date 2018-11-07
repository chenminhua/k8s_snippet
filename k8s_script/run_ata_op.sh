#!/bin/bash
az group create --name ata-op --location southeastasia

az network vnet create -g ata-op -n opvnet --address-prefix 10.0.0.0/24
az network vnet subnet create -g ata-op --vnet-name opvnet -n opsubnet --address-prefix 10.0.0.0/24

az network public-ip create -g ata-op -n ata-op-ip1 --allocation-method Static
az network public-ip create -g ata-op -n ata-op-ip2 --allocation-method Static
az network public-ip create -g ata-op -n ata-op-ip3 --allocation-method Static

az network nic create -g ata-op --vnet-name opvnet -n ata-op1-nic --subnet opsubnet --private-ip-address 10.0.0.10 --public-ip-address ata-op-ip1
az network nic create -g ata-op --vnet-name opvnet -n ata-op2-nic --subnet opsubnet --private-ip-address 10.0.0.20 --public-ip-address ata-op-ip2
az network nic create -g ata-op --vnet-name opvnet -n ata-op3-nic --subnet opsubnet --private-ip-address 10.0.0.30 --public-ip-address ata-op-ip3

az vm create -g ata-op -n ata-op1 --image CentOS --nics ata-op1-nic --admin-username azure --ssh-key-value ~/.ssh/ata.pub
az vm create -g ata-op -n ata-op2 --image CentOS --nics ata-op2-nic --admin-username azure --ssh-key-value ~/.ssh/ata.pub
az vm create -g ata-op -n ata-op3 --image CentOS --nics ata-op3-nic --admin-username azure --ssh-key-value ~/.ssh/ata.pub
