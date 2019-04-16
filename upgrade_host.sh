#!/usr/bin/env bash

version=$1
hostx=$2
db_username=$3
db_password=$4

create_yum_repo_file() {
    version=$1
    rm -rf /etc/yum.repos.d/mongo*
    echo "[mongodb-org-$version]" > /etc/yum.repos.d/mongodb-org.repo
    echo "name=MongoDB $version Repository" >> /etc/yum.repos.d/mongodb-org.repo
    if [ "$version" = "2.6" ]
    then
        echo "baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64/" >> /etc/yum.repos.d/mongodb-org.repo
    elif [ "$version" = "3.0" ]
    then
        echo "baseurl=https://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/3.0/x86_64/" >> /etc/yum.repos.d/mongodb-org.repo
    elif [ "$version" = "3.2" ]
    then
        echo "baseurl=https://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/3.2/x86_64/" >> /etc/yum.repos.d/mongodb-org.repo
    elif [ "$version" = "3.4" ]
    then
        echo "baseurl=https://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/3.4/x86_64/" >> /etc/yum.repos.d/mongodb-org.repo
    elif [ "$version" = "3.6" ]
    then
        echo "baseurl=https://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/3.6/x86_64/" >> /etc/yum.repos.d/mongodb-org.repo
    fi
    echo "gpgcheck=0" >> /etc/yum.repos.d/mongodb-org.repo
    echo "enabled=1" >> /etc/yum.repos.d/mongodb-org.repo
}

create_yum_repo_file $version

echo ""
read qqq
service mongod stop
yum upgrade -y mongodb-org
systemctl daemon-reload
service mongod start

notReady=true
while $notReady; do
    echo "host $hostx for version $version"
    state=$(mongo -u $db_username -p $db_password admin --eval "x=rs.status();for (i = 0; i < x.members.length; i++) { pos =  x.members[i].name.indexOf('$hostx'); if(pos != -1){print(x.members[i].stateStr); break;}}" --quiet)
    echo "state $state"
    if [ "$state" = "SECONDARY" ] || [ "$state" = "PRIMARY" ]; then
        notReady=false
        echo "state $state $version"
    else
        sleep 2
    fi

done

