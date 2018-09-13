#!/bin/bash
set -e

# Configure Zookeeper
cat << EOF > /usr/local/zookeeper/conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
initLimit=5
syncLimit=2
server.1=${zookeeper_01}:2888:3888
server.2=${zookeeper_02}:2888:3888
server.3=${zookeeper_03}:2888:3888
EOF

# Start Zookeeper
supervisorctl reload

