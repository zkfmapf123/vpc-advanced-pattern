#!/bin/bash

INBOUND_IP1="10.0.3.60"  # Blue VPC Inbound Endpoint IP 1
INBOUND_IP2="10.0.4.101"  # Blue VPC Inbound Endpoint IP 2

# 기존 resolv.conf 백업
cp /etc/resolv.conf /etc/resolv.conf.backup

# 새로운 DNS 설정
cat > /etc/resolv.conf << EOF
nameserver $INBOUND_IP1
nameserver $INBOUND_IP2
search ec2.internal
EOF

# 변경사항이 DHCP로 덮어쓰여지지 않도록 보호
chattr +i /etc/resolv.conf

# SSM 에이전트 재시작
systemctl restart amazon-ssm-agent

# 로그 남기기
echo "DNS configuration changed to use Route53 Resolver at $(date)" >> /var/log/dns-change.log
echo "Inbound IPs: $INBOUND_IP1, $INBOUND_IP2" >> /var/log/dns-change.log