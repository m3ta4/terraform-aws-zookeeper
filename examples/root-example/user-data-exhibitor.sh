#!/bin/bash
set -e

# Create Exhibitor Properties
mkdir -p /etc/exhibitor
cat << EOF > /etc/exhibitor/exhibitor.properties
auto-manage-instances-apply-all-at-once=0
auto-manage-instances=1
java-environment=ZOO_LOG_DIR="/var/log/zookeeper" SERVER_JVMFLAGS="-Xms2048m -Xmx2048m -verbose:gc -XX:+PrintHeapAtGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -XX:+PrintTenuringDistribution -XX:+PrintGCApplicationStoppedTime -Xloggc:$ZOO_LOG_DIR/zookeeper_gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=9 -XX:GCLogFileSize=20M"
log4j-properties=INFO,ROLLINGFILE
zoo-cfg-extra=syncLimit\=2&tickTime\=2000&initLimit\=5&autopurge.snapRetainCount\=3&autopurge.purgeInterval\=1
zookeeper-data-directory=/var/lib/zookeeper
zookeeper-install-directory=/usr/local/zookeeper
EOF

chown -R zookeeper /etc/exhibitor

# Update the Exhibitor Systemd Unit
cat << EOF > /etc/systemd/system/exhibitor.service
# exhibitor service for systemd (CentOS 7.0+)
[Unit]
Description=Exhibitor Zookeeper Supervisor
After=network.target

[Service]
ExecStart=/usr/bin/java -jar /opt/exhibitor/exhibitor-1.6.0.jar -c s3 --s3config ${bucket}:${key} --defaultconfig /etc/exhibitor/exhibitor.properties
LimitNOFILE=8192
MountFlags=private
RestartSec=5s
Restart=on-failure
SyslogIdentifier=exhibitor
Type=simple

[Install]
WantedBy=multi-user.target
EOF

chmod 664 /etc/systemd/system/exhibitor.service

systemctl daemon-reload
systemctl restart exhibitor.service
