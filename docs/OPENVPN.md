# OpenVPN 설치

```sh
sudo yum update -y
sudo yum install openvpn
openvpn --version

# OpenVPN 서버 설정 디렉토리 생성
sudo mkdir -p /etc/openvpn/server
sudo mkdir -p /etc/openvpn/client
sudo mkdir -p /etc/openvpn/easy-rsa

# 로그 디렉토리
sudo mkdir -p /var/log/openvpn

cd /etc/openvpn/
sudo wget https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.4/EasyRSA-3.2.4.tgz
sudo tar xzf EasyRSA-3.2.4.tgz
sudo mv EasyRSA-3.2.4 easy-rsa
sudo rm EasyRSA-3.2.4.tgz

## 1. PKI 초기화
cd easy-rsa
sudo ./easyrsa init-pki

## 2. CA 생성
sudo ./easyrsa build-ca nopass

## 3. 서버 인증서 요청 생성
sudo ./easyrsa build-ca nopass

## 4. 요청 생성
sudo ./easyrsa gen-req server nopass 
>> server

## 5. 서버 인증서 서명
sudo ./easyrsa sign-req server server

## 6. Diffle Hellman 파라미터 생성 (오래 걸림...)
sudo ./easyrsa gen-dh

## 7. TLS-Auth 생성
sudo openvpn --genkey --secret ta.key

## ... 파일 조회
sudo ls -la pki/ca.crt
sudo ls -la pki/issued/server.crt  
sudo ls -la pki/private/server.key
sudo ls -la pki/dh.pem
sudo ls -la ta.key

## [server] 설정 디렉토리 생성
sudo mkdir -p /etc/openvpn/server
sudo vi /etc/openvpn/server/server.conf

>> EOF
port 1194
proto tcp
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem
tls-auth /etc/openvpn/easy-rsa/ta.key 0
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
explicit-exit-notify 1
EOF

## 인증서 복사
sudo cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/server/

# 서버 인증서 복사
sudo cp /etc/openvpn/easy-rsa/pki/issued/server.crt /etc/openvpn/server/

# 서버 개인키 복사
sudo cp /etc/openvpn/easy-rsa/pki/private/server.key /etc/openvpn/server/

# DH 파라미터 복사
sudo cp /etc/openvpn/easy-rsa/pki/dh.pem /etc/openvpn/server/

# TLS-Auth 키 복사
sudo cp /etc/openvpn/easy-rsa/ta.key /etc/openvpn/server/

## 권한 설정
### /etc/openvpn/server
sudo chmod 600 server.key 
sudo chmod 600 ta.key 
sudo chmod 644 ca.crt 
sudo chmod 644 server.crt 
sudo chmod 644 dh.pem 

sudo mkdir -p /var/log/openvpn

## 서버 설정 수정
sudo vi /etc/openvpn/server/server.conf

>> EOF (overwrite)
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-auth /etc/openvpn/server/ta.key 0
EOF

## IP 포워딩 활성화
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

## openvpn 시작
sudo systemctl start openvpn-server@server

# 부팅 시 자동 시작 설정
sudo systemctl enable openvpn-server@server

# 상태 확인
sudo systemctl status openvpn-server@server

## 클라이언트 설정 파일
cd /etc/openvpn/easy-rsa

# 클라이언트 인증서 생성 (client1이라는 이름으로)
sudo ./easyrsa gen-req client1 nopass
sudo ./easyrsa sign-req client client1

sudo vi /etc/openvpn/client/client1.ovpn

>> EOF
client
dev tun
proto tcp
remote [domain] 80
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert client1.crt
key client1.key
tls-auth ta.key 1
verb 3
EOF

## 파일 복사
sudo cp /etc/openvpn/server/ca.crt /etc/openvpn/client/
sudo cp /etc/openvpn/easy-rsa/pki/issued/client1.crt /etc/openvpn/client/
sudo cp /etc/openvpn/easy-rsa/pki/private/client1.key /etc/openvpn/client/
sudo cp /etc/openvpn/server/ta.key /etc/openvpn/client/

## client 실행
sudo systemctl status openvpn-server@server

# 포트 리스닝 확인
sudo netstat -tlnp | grep 1194

# 로그 확인
sudo tail -f /var/log/openvpn/openvpn.log

```

## OpenVPN Connect 구성

```sh
## Client OVPN 생성
# 인라인 설정 파일 생성 (모든 인증서를 하나의 파일에 포함)
sudo cat > /tmp/client1-inline.ovpn << 'EOF'
client
dev tun
proto tcp
remote openvpn.leedonggyu.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
verb 3
<ca>
EOF

# CA 인증서 추가
sudo cat /etc/openvpn/client/ca.crt >> /tmp/client1-inline.ovpn

echo "</ca>" | sudo tee -a /tmp/client1-inline.ovpn
echo "<cert>" | sudo tee -a /tmp/client1-inline.ovpn

# 클라이언트 인증서 추가
sudo cat /etc/openvpn/client/client1.crt >> /tmp/client1-inline.ovpn

echo "</cert>" | sudo tee -a /tmp/client1-inline.ovpn
echo "<key>" | sudo tee -a /tmp/client1-inline.ovpn

# 클라이언트 키 추가
sudo cat /etc/openvpn/client/client1.key >> /tmp/client1-inline.ovpn

echo "</key>" | sudo tee -a /tmp/client1-inline.ovpn
echo "<tls-auth>" | sudo tee -a /tmp/client1-inline.ovpn

# TLS Auth 키 추가
sudo cat /etc/openvpn/client/ta.key >> /tmp/client1-inline.ovpn

echo "</tls-auth>" | sudo tee -a /tmp/client1-inline.ovpn
echo "key-direction 1" | sudo tee -a /tmp/client1-inline.ovpn

>> /tmp/client1-inline.ovpn
```

## OpenVPN 연결하니까 인터넷이 안됨...

- <b>현재설정은 OpenVPN 서버가 모든 트래픽을 OpenVPN 서버로 보내는 구성</b> + OpenVPN 서버 자체에는 그 트래픽을 인터넷으로 내보내는 설정이 없음...
- OpenVPN 트래픽 준비가 안됨...

```sh
## 현재 모든 설정 (모든 트래픽이 VPN 으로 통신)
push "redirect-gateway def1 bypass-dhcp" 

## 서버 설정 수정
sudo vi /etc/openvpn/server/server.conf

## aws vpc 만 vpn으로 라우팅
push "route 172.0.0.0 255.255.0.0"

```


## 참고

- <a href="https://openvpn.net/community-docs/installing-openvpn.html">Installing OpenVPN</a>
- <a href="https://github.com/OpenVPN/openvpn/releases"> OPEN VPN Release Version </a>