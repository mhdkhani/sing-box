#!/bin/bash

helpScript() {
    echo "script usage:  [-i: install script] [-h: help] [-c: create new user] [-d: delete user] [-a: active user] [-u: show user]  [-p: change port] [-s: change sni]"
}

getIpAddress(){
  hostname -I
}

install_packages() {
  if ! which qrencode whiptail jq >/dev/null 2>&1; then
    if which apt >/dev/null 2>&1; then
      apt update
      apt install qrencode whiptail jq -y
      return 0
    fi
    if which yum >/dev/null 2>&1; then
      yum makecache
      yum install epel-release -y || true
      yum install qrencode newt jq -y
      return 0
    fi
    echo "OS is not supported!"
    return 1
  fi
}


installScript() {
   
    install_packages

    touch default_port.txt
    echo "1445" > default_port.txt
    touch default_sni.txt
    echo "www.speedtest.net" > default_sni.txt
 

    curl -Lo /root/sb https://github.com/SagerNet/sing-box/releases/download/v1.3.0/sing-box-1.3.0-linux-amd64.tar.gz && tar -xzf /root/sb && cp -f /root/sing-box-*/sing-box /root && rm -r /root/sb /root/sing-box-* && chown root:root /root/sing-box && chmod +x /root/sing-box

   curl -Lo /root/sing-box_config.json https://raw.githubusercontent.com/iSegaro/Sing-Box/main/sing-box_config.json

   curl -Lo /etc/systemd/system/sing-box.service https://raw.githubusercontent.com/iSegaro/Sing-Box/main/sing-box.service && systemctl daemon-reload

   /root/sing-box check -c sing-box_config.json

   systemctl enable --now sing-box && sleep 0.2 && systemctl status sing-box

   
}
newUserScript() {
    ipAddress=$(getIpAddress)
    ip4=(${ipAddress//:/ })
    uid=$(getUuid)
    myPrivateKey=$(getPrivateKey)
    arrIN=(${myPrivateKey//:/ })
    myShortId=$(getShortId)
    defaultPort=`cat default_port.txt`
    defaultSni=`cat default_sni.txt`
    newPort=$(($defaultPort+1))
    gain=$( jq '.inbounds += [{"type" : "vless",tag:"vless-in","listen":"::","listen_port":'$newPort',"sniff":true,"sniff_override_destination":true,"domain_strategy":"ipv4_only","users":[{"uuid":"'$uid'","flow":"xtls-rprx-vision"}],"tls":{"enabled":true,"server_name":"'$defaultSni'","reality":{"enabled":true,"handshake": {"server":"'$defaultSni'","server_port":443},"private_key":"'${arrIN[1]}'","short_id":["'$myShortId'"] } } }] ' sing-box_config.json; )
    echo $gain > sing-box_config.json 
    echo $newPort > default_port.txt
    systemctl restart sing-box
   
    
    mkdir $newPort

    touch $newPort/private_key.txt
    touch $newPort/public_key.txt
    touch $newPort/short_id.txt
    touch $newPort/uuid.txt


    echo  ${arrIN[1]} > $newPort/private_key.txt
    echo  ${arrIN[3]} > $newPort/public_key.txt
    echo  $myShortId > $newPort/short_id.txt
    echo  $uid > $newPort/uuid.txt

    link="vless://$uid@$ip4:$newPort/?type=tcp&encryption=none&flow=xtls-rprx-vision&sni=$defaultSni&fp=chrome&security=reality&pbk=${arrIN[3]}&sid=$myShortId#$newPort"
    echo $link
    echo ""    
    echo "Or you can scan the QR code:"
    echo ""
    qrencode -t ansiutf8 "${link}"    

}

deleteUserScript() {
  replacePort=1
  filename="sing-box_config.json"
  read -p "Enter user port for delete: " port
  search='"listen_port": '$port'';
  replace='"listen_port": '$port$replacePort'';
  if [[ $search != "" && $replace != "" ]]; then
    sed -i "s/$search/$replace/" $filename
  fi
  systemctl restart sing-box
}
activeUserScript() {
  replacePort=1
  filename="sing-box_config.json"
  read -p "Enter user port for active: " port
  search='"listen_port": '$port$replacePort'';
  replace='"listen_port": '$port'';
  if [[ $search != "" && $replace != "" ]]; then
    sed -i "s/$search/$replace/" $filename
  fi
  systemctl restart sing-box
}

function getUuid() {
     ./sing-box generate uuid
}
 
function getPrivateKey() {
   ./sing-box generate reality-keypair
}
function getShortId() {
    ./sing-box generate rand --hex 8
}
function changePort(){
  read -p "Enter default port: " port
  echo $port > default_port.txt
  echo "You entered $port"
}
function changeSni(){
  read -p "Enter default SNI: " sni
  echo $sni > default_sni.txt
  echo "You entered $sni"
}

function showUser(){
  read -p "Enter user port: " port
  ipAddress=$(getIpAddress)
  ip4=(${ipAddress//:/ })
  private_key=`cat $port/private_key.txt`
  public_key=`cat $port/public_key.txt`
  short_id=`cat $port/short_id.txt`
  uid=`cat $port/uuid.txt`
  defaultSni=`cat default_sni.txt`

  link="vless://$uid@$ip4:$port/?type=tcp&encryption=none&flow=xtls-rprx-vision&sni=$defaultSni&fp=chrome&security=reality&pbk=$public_key&sid=$short_id#$port"
  echo $link
  echo ""
  echo "Or you can scan the QR code:"
  echo ""
  qrencode -t ansiutf8 "${link}"

}

while getopts 'ihcdpsau' OPTION; do
  case "$OPTION" in
    i)
      installScript
      ;;
    h)
       helpScript
      ;;
    d)
      deleteUserScript
      ;;
    c)
        newUserScript
      ;;
    p)
       changePort
     ;;
    s)
       changeSni
     ;;
    a)
       activeUserScript
     ;;
     u)
       showUser
     ;;
    ?)
      echo "script usage:  [-i: install script] [-h: help] [-c: create new user] [-d: delete user] [-a: active user] [-u: show user]  [-p: change port] [-s: change sni]" >&2
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"
