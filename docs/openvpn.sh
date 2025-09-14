#!/bin/bash

# OpenVPN 설치 및 설정 스크립트
set -e

# 변수 설정
DOMAIN="${1:-openvpn.example.com}"
CLIENT_NAME="${2:-client1}"
PROTO="${3:-tcp}"

echo "=== OpenVPN 설치 시작 ==="
echo "도메인: $DOMAIN"
echo "클라이언트명: $CLIENT_NAME"
echo "프로토콜: $PROTO"

# OpenVPN 설치
sudo yum update -y
sudo yum install -y openvpn
openvpn --version

# 디렉토리 생성
sudo mkdir -p /etc/openvpn/server
sudo mkdir -p /etc/openvpn/client
sudo mkdir -p /etc/openvpn/easy-rsa
sudo mkdir -p /var/log/openvpn

echo "=== Easy-RSA 다운로드 및 설치 ==="
cd /etc/openvpn/
sudo wget https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.4/EasyRSA-3.2.4.tgz
sudo tar xzf EasyRSA-3.2.4.tgz
sudo mv EasyRSA-3.2.4 easy-rsa
sudo rm EasyRSA-3.2.4.tgz

echo "=== PKI 및 인증서 생성 ==="
cd easy-rsa

# PKI 초기화
sudo ./easyrsa init-pki

# CA 생성 (비밀번호 없이)
sudo ./easyrsa build-ca nopass <<EOF
OpenVPN-CA
EOF

# 서버 인증서 요청 생성
sudo ./easyrsa gen-req server nopass <<EOF
server
EOF

# 서버 인증서 서명
sudo ./easyrsa sign-req server server <<EOF
yes
EOF

# Diffie Hellman 파라미터 생성 (시간 오래 걸림)
echo "DH 파라미터 생성 중... (시간이 오래 걸릴 수 있습니다)"
sudo ./easyrsa gen-dh

# TLS-Auth 키 생성
sudo openvpn --genkey --secret ta.key

echo "=== 서버 설정 파일 생성 ==="
if [ "$PROTO" = "udp" ]; then
    sudo tee /etc/openvpn/server/server.conf > /dev/null <<EOF
port 1194
proto udp
dev tun
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-auth /etc/openvpn/server/ta.key 0
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
user nobody
group nobody
persist-key
persist-tun
status openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
tun-mtu 1500
mssfix 1460
fragment 1300
EOF
else
    sudo tee /etc/openvpn/server/server.conf > /dev/null <<EOF
port 1194
proto tcp
dev tun
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-auth /etc/openvpn/server/ta.key 0
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "route 172.0.0.0 255.255.0.0"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
user nobody
group nobody
persist-key
persist-tun
status openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
explicit-exit-notify 1
tun-mtu 1200
mssfix 1160
EOF
fi

echo "=== 인증서 파일 복사 ==="
sudo cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/server/
sudo cp /etc/openvpn/easy-rsa/pki/issued/server.crt /etc/openvpn/server/
sudo cp /etc/openvpn/easy-rsa/pki/private/server.key /etc/openvpn/server/
sudo cp /etc/openvpn/easy-rsa/pki/dh.pem /etc/openvpn/server/
sudo cp /etc/openvpn/easy-rsa/ta.key /etc/openvpn/server/

echo "=== 파일 권한 설정 ==="
cd /etc/openvpn/server
sudo chmod 600 server.key 
sudo chmod 600 ta.key 
sudo chmod 644 ca.crt 
sudo chmod 644 server.crt 
sudo chmod 644 dh.pem 

echo "=== IP 포워딩 활성화 ==="
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "=== OpenVPN 서비스 시작 ==="
sudo systemctl start openvpn-server@server
sudo systemctl enable openvpn-server@server

echo "=== 클라이언트 인증서 생성 ==="
cd /etc/openvpn/easy-rsa

# 클라이언트 인증서 생성
sudo ./easyrsa gen-req $CLIENT_NAME nopass <<EOF
$CLIENT_NAME
EOF

sudo ./easyrsa sign-req client $CLIENT_NAME <<EOF
yes
EOF

echo "=== 클라이언트 파일 복사 ==="
sudo cp /etc/openvpn/server/ca.crt /etc/openvpn/client/
sudo cp /etc/openvpn/easy-rsa/pki/issued/$CLIENT_NAME.crt /etc/openvpn/client/
sudo cp /etc/openvpn/easy-rsa/pki/private/$CLIENT_NAME.key /etc/openvpn/client/
sudo cp /etc/openvpn/server/ta.key /etc/openvpn/client/

echo "=== 클라이언트 설정 파일 생성 ==="
if [ "$PROTO" = "udp" ]; then
    sudo tee /etc/openvpn/client/$CLIENT_NAME.ovpn > /dev/null <<EOF
client
dev tun
proto udp
remote $DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert $CLIENT_NAME.crt
key $CLIENT_NAME.key
tls-auth ta.key 1
verb 3
tun-mtu 1500
mssfix 1460
EOF
else
    sudo tee /etc/openvpn/client/$CLIENT_NAME.ovpn > /dev/null <<EOF
client
dev tun
proto tcp
remote $DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert $CLIENT_NAME.crt
key $CLIENT_NAME.key
tls-auth ta.key 1
verb 3
tun-mtu 1200
mssfix 1160
EOF
fi

echo "=== 인라인 클라이언트 설정 파일 생성 ==="
if [ "$PROTO" = "udp" ]; then
    sudo tee /tmp/$CLIENT_NAME-inline.ovpn > /dev/null <<EOF
client
dev tun
proto udp
remote $DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
verb 3
tun-mtu 1500
mssfix 1460
<ca>
EOF
else
    sudo tee /tmp/$CLIENT_NAME-inline.ovpn > /dev/null <<EOF
client
dev tun
proto tcp
remote $DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
verb 3
tun-mtu 1200
mssfix 1160
<ca>
EOF
fi

# CA 인증서 추가
sudo cat /etc/openvpn/client/ca.crt >> /tmp/$CLIENT_NAME-inline.ovpn

echo "</ca>" | sudo tee -a /tmp/$CLIENT_NAME-inline.ovpn
echo "<cert>" | sudo tee -a /tmp/$CLIENT_NAME-inline.ovpn

# 클라이언트 인증서 추가
sudo cat /etc/openvpn/client/$CLIENT_NAME.crt >> /tmp/$CLIENT_NAME-inline.ovpn

echo "</cert>" | sudo tee -a /tmp/$CLIENT_NAME-inline.ovpn
echo "<key>" | sudo tee -a /tmp/$CLIENT_NAME-inline.ovpn

# 클라이언트 키 추가
sudo cat /etc/openvpn/client/$CLIENT_NAME.key >> /tmp/$CLIENT_NAME-inline.ovpn

echo "</key>" | sudo tee -a /tmp/$CLIENT_NAME-inline.ovpn
echo "<tls-auth>" | sudo tee -a /tmp/$CLIENT_NAME-inline.ovpn

# TLS Auth 키 추가
sudo cat /etc/openvpn/client/ta.key >> /tmp/$CLIENT_NAME-inline.ovpn

echo "</tls-auth>" | sudo tee -a /tmp/$CLIENT_NAME-inline.ovpn
echo "key-direction 1" | sudo tee -a /tmp/$CLIENT_NAME-inline.ovpn

echo "=== 설치 완료 ==="
echo "서비스 상태 확인:"
sudo systemctl status openvpn-server@server

echo ""
if [ "$PROTO" = "udp" ]; then
    echo "포트 리스닝 확인:"
    sudo netstat -ulnp | grep 1194
else
    echo "포트 리스닝 확인:"
    sudo netstat -tlnp | grep 1194
fi

echo ""
echo "클라이언트 설정 파일 위치:"
echo "- 일반: /etc/openvpn/client/$CLIENT_NAME.ovpn"
echo "- 인라인: /tmp/$CLIENT_NAME-inline.ovpn"
echo ""
echo "로그 확인: sudo tail -f /var/log/openvpn/openvpn.log"