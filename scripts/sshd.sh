#!/bin/bash

# 修改ssh port
vi /etc/ssh/sshd_config

PORT 711

service sshd restart
