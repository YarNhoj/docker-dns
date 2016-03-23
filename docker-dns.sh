#!/usr/bin/env bash
# docker-dns.sh
# DNS Listener for docker
# John R. Ray <jray@shadow-soft.com>
#

CID=
CIP=
DOCKER_HOSTS_FILE=/tmp/docker_hosts

getContainerInfo() {

  # Do a docker inspect of container to get IP and FQDN
  CIP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$1" 2> /dev/null)
  CHN=$(docker inspect --format '{{ .Config.Hostname }}.{{ .Config.Domainname }}' "$1" 2> /dev/null)

}

updateDNS() {

  # If host already exists do some sed to dnsmaq addn hosts
  # Otherwise add the host
  if grep ${CHN} ${DOCKER_HOSTS_FILE} > /dev/null 2>&1; then
    echo "Host name found...Changing"
    sed -i "s/.*${CHN}.*/${CIP} ${CHN}/g" ${DOCKER_HOSTS_FILE}
  else
    echo "New Host Detected...Updating"
    echo "${CIP} ${CHN}" >> ${DOCKER_HOSTS_FILE}
  fi

  # Restart DNSmasq
  pkill -x -HUP dnsmasq

}
main() {

  # Seed the Initial Docker Hosts File
  [[ -f ${DOCKER_HOSTS_FILE} ]] && rm -f ${DOCKER_HOSTS_FILE}
  for ID in `docker ps -q`; do
    getContainerInfo ${ID}
    echo "${CIP} ${CHN}" >> ${DOCKER_HOSTS_FILE}
    pkill -x -HUP dnsmasq
  done

# Curl the Docker Events endpoint to watch events
curl -s -N --unix-socket /var/run/docker.sock http:/events 2>&1 | while read event; do
  CID=$(echo $event | awk -F: '/start/ {print $3}' | cut -d '"' -f2)
  [[ -z ${CID} ]] || getContainerInfo ${CID}
  logIt "Updating DNS"; updateDNS
done
}

## Source Check
[[ "${BASH_SOURCE}" == "$0" ]] && main "$@"

