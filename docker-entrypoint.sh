#!/bin/sh

MYUSER="pyload"
MYGID="10005"
MYUID="10005"
OS=""

DectectOS(){
  if [ -e /etc/alpine-release ]; then
    OS="alpine"
  elif [ -e /etc/os-release ]; then
    if /bin/grep -q "NAME=\"Ubuntu\"" /etc/os-release ; then
      OS="ubuntu"
    fi
  fi
}

AutoUpgrade(){
  if [ "${OS}" == "alpine" ]; then
    /sbin/apk --no-cache upgrade
    /bin/rm -rf /var/cache/apk/*
  elif [ "${OS}" == "ubuntu" ]; then
    export DEBIAN_FRONTEND=noninteractive
    /usr/bin/apt-get update
    /usr/bin/apt-get -y --no-install-recommends dist-upgrade
    /usr/bin/apt-get -y autoclean
    /usr/bin/apt-get -y clean
    /usr/bin/apt-get -y autoremove
    /bin/rm -rf /var/lib/apt/lists/*
  fi
}

ConfigureSsmtp () {
  # Customizing sstmp
  if [ -f /etc/ssmtp/ssmtp.conf ];then
    # Configure relay
    if [ -n "${DOCKRELAY}" ]; then
      /bin/sed -i "s|mailhub=mail|mailhub=${DOCKRELAY}|i" /etc/ssmtp/ssmtp.conf
    fi
    # Configure root
    if [ -n "${DOCKMAIL}" ]; then
      /bin/sed -i "s|root=postmaster|root=${DOCKMAIL}|i" /etc/ssmtp/ssmtp.conf
    fi
    # Configure domain
    if [ -n "${DOCKMAILDOMAIN}" ]; then
      /bin/sed -i "s|#rewriteDomain=.*|rewriteDomain=${DOCKMAILDOMAIN}|i" /etc/ssmtp/ssmtp.conf
    fi
  fi
}

ConfigureUser () {
  # Managing user
  if [ -n "${DOCKUID}" ]; then
    MYUID="${DOCKUID}"
  fi
  # Managing group
  if [ -n "${DOCKGID}" ]; then
    MYGID="${DOCKGID}"
  fi
  local OLDHOME
  local OLDGID
  local OLDUID
  if /bin/grep -q "${MYUSER}" /etc/passwd; then
    OLDUID=$(/usr/bin/id -u "${MYUSER}")
    OLDGID=$(/usr/bin/id -g "${MYUSER}")
    if [ "${DOCKUID}" != "${OLDUID}" ]; then
      OLDHOME=$(/bin/grep "$MYUSER" /etc/passwd | /usr/bin/awk -F: '{print $6}')
      /usr/sbin/deluser "${MYUSER}"
      /usr/bin/logger "Deleted user ${MYUSER}"
    fi
    if /bin/grep -q "${MYUSER}" /etc/group; then
      local OLDGID=$(/usr/bin/id -g "${MYUSER}")
      if [ "${DOCKGID}" != "${OLDGID}" ]; then
        /usr/sbin/delgroup "${MYUSER}"
        /usr/bin/logger "Deleted group ${MYUSER}"
      fi
    fi
  fi
  if ! /bin/grep -q "${MYUSER}" /etc/group; then
    /usr/sbin/addgroup -S -g "${MYGID}" "${MYUSER}"
  fi
  if ! /bin/grep -q "${MYUSER}" /etc/passwd; then
    /usr/sbin/adduser -S -D -H -s /sbin/nologin -G "${MYUSER}" -h "${OLDHOME}" -u "${MYUID}" "${MYUSER}"
  fi
  if [ -n "${OLDUID}" ] && [ "${DOCKUID}" != "${OLDUID}" ]; then
    /usr/bin/find / -user "${OLDUID}" -exec /bin/chown ${MYUSER} {} \;
  fi
  if [ -n "${OLDGID}" ] && [ "${DOCKGID}" != "${OLDGID}" ]; then
    /usr/bin/find / -group "${OLDGID}" -exec /bin/chgrp ${MYUSER} {} \;
  fi
}

DectectOS
AutoUpgrade
ConfigureUser
ConfigureSsmtp

if [ "$1" = 'pyload' ]; then
    if [ -d /config ]; then
      /bin/chown -R "${MYUSER}":"${MYUSER}" /config
      /bin/chmod 0775 /config
    fi
    if [ -e /config/pyload.pid ]; then
      /bin/rm /config/pyload.pid
    fi
    for J in package_finished download_finished; do 
      if [ ! -d /config/scripts/${J} ]; then
        /bin/mkdir -p /config/scripts/${J}
        /bin/chown -R "${MYUSER}":"${MYUSER}" /config/scripts/${J}
        /bin/chmod 0775 /config/scripts/${J}
      fi
    done
    if [ ! -f /config/scripts/package_finished/mail-notification.sh ]; then
      cat << EOF2 > /config/scripts/package_finished/mail-notification.sh
#!/bin/sh
exec /usr/bin/mail -s "Pyload: Package Finished" root <<EOF
\${2} was finished at \$(date +"%H:%M") on \$(date +"%d.%m.%y"). ...forwarding it now to the extraction queue.
EOF
sleep 2
exit 0
EOF2
      /bin/chown -R "${MYUSER}":"${MYUSER}" /config/scripts/package_finished/mail-notification.sh
      /bin/chmod 0775 /config/scripts/package_finished/mail-notification.sh
    fi
    if [ ! -f /config/scripts/download_finished/mail-notification.sh ]; then
      cat << EOF2 > /config/scripts/download_finished/mail-notification.sh
#!/bin/sh
exec /usr/bin/mail -s "Pyload: Download Finished" root <<EOF
\${2} was finished at \$(date +"%H:%M") on \$(date +"%d.%m.%y"). ...forwarding it now to the extraction queue.
EOF
sleep 2
exit 0
EOF2
      /bin/chown -R "${MYUSER}":"${MYUSER}" /config/scripts/download_finished/mail-notification.sh
      /bin/chmod 0775 /config/scripts/download_finished/mail-notification.sh
    fi
    exec /sbin/su-exec "${MYUSER}" /usr/bin/python /opt/pyload/pyLoadCore.py --configdir=/config 
fi

exec "$@"
