#!/usr/bin/env bash
db_username=root
db_password=root
user=ec2-user
ipDump=ip-172-31-31-246.ec2.internal
ips=ip-172-31-31-246.ec2.internal,ip-172-31-49-11.ec2.internal,ip-172-31-48-114.ec2.internal
#mongo -u $db_username -p $db_password admin --eval "printjson(rs.status())" --quiet

dump_data() {
    ipDump=$1
    user=$2
    db_username=$3
    db_password=$4

    ssh -i ./key.pem $user@$ipDump "mongodump -u $db_username -p $db_password --authenticationDatabase admin --oplog"
}

# ***************** TODO ********************
upgradeToWT() {
    host_name=$1
    user=$2
    db_username=$3
    db_password=$4

    storageEngine=$(ssh -i ./key.pem $user@$last_host "mongo -u $db_username -p $db_password admin --eval 'db.serverStatus().storageEngine.name' --quiet")
    if [ "$storageEngine" = "mmapv1" ]; then
        dbPath=$(ssh -i ./key.pem $user@$last_host "mongo -u $db_username -p $db_password admin --eval 'db.serverCmdLineOpts().parsed.storage.dbPath' --quiet")
        ssh -i ./key.pem $user@$last_host "service mongod stop"
        ssh -i ./key.pem $user@$last_host "rm -rf $dbPath"
        ssh -i ./key.pem $user@$last_host "service mongod start"
    fi

}
# ***************** END TODO ********************

upgrade_mongo() {
    host_name=$1
    user=$2
    target_version=$3
    db_username=$4
    db_password=$5
    echo "host in upgrade_mongo: $host"
    declare -A previous_version=( ["2.6"]="2.4" ["3.0"]="2.6" ["3.2"]="3.0" ["3.4"]="3.2" ["3.6"]="3.4" )
    current_version=$(ssh -i ./key.pem $user@$host_name 'mongod --version | grep "db version" | cut  -c13-15')
    if [ "$target_version" = "$current_version" ]; then
        echo "Not Upgrading current version: $current_version target version: $target_version"
    elif [ "${previous_version[${target_version}]}" = "$current_version" ]; then
        echo "Upgrading mongo $current_version to $target_version"
        ssh -i ./key.pem $user@$host_name 'sudo bash -s' < upgrade_host.sh $target_version $host_name $db_username $db_password
    elif [ "${previous_version[${target_version}]}" \< "$current_version" ]; then
        echo "Already on $current_version, cannot upgrade to $target_version"
    else
        echo "Not Upgrading (exiting) current version: $current_version target version: $target_version"
        exit 1
    fi

}

dump_data $ipDump $user $db_username $db_password


#for target_version in 2.6 3.0 3.2 3.4 3.6; do
#for target_version in 3.0 3.2 3.4 3.6; do
for target_version in 2.6 3.0 3.2 3.4 3.6; do
    last_host=""
    for host in $(echo $ips | sed "s/,/ /g"); do
        echo "host in for loop $host"
        upgrade_mongo $host $user $target_version $db_username $db_password
           last_host=$host
    done
    if [ $target_version \> 3.2 ]; then
#        primary_host=$(ssh -i ./key.pem $user@$last_host "mongo -u $db_username -p $db_password admin --eval 'db.isMaster().primary.split(\':\')[0]' --quiet")
        primary_host=$(ssh -i ./key.pem $user@$last_host "mongo -u $db_username -p $db_password admin --eval 'db.isMaster().primary' --quiet")
        echo " Primary for feature compatibility: $primary_host"
        IFS=':' read -r -a array <<< $primary_host
        echo " Primary for feature compatibility: ${array[0]}"
#       read qqq
        ssh -i ./key.pem $user@${array[0]} "mongo -u $db_username -p $db_password admin --eval 'db.adminCommand( { setFeatureCompatibilityVersion: \"$target_version\" } );' --quiet"
        ssh -i ./key.pem $user@${array[0]} "mongo -u $db_username -p $db_password admin --eval 'db.adminCommand( {authSchemaUpgrade: 1 } );' --quiet"
        echo " set feature compatibility: $target_version"
    fi
done

