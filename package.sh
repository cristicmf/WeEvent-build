#!/bin/bash
broker_git_address=
broker_git="https://github.com/WeBankFinTech/WeEvent.git"
broker_branch=
governance_git_address=
governance_git="https://github.com/WeBankFinTech/WeGovernance.git"
governance_branch=
maven=aliyun
version=
top_path=`pwd`

function usage(){
    echo "Usage:"
    echo "     package weevent: ./package.sh --broker git@git.weoa.com:ttip/weevent-broker.git --governance git@git.weoa.com:ttip/weevent-governance.git --maven weoa --version 0.9.0"
    echo "     package broker module: ./package.sh --broker git@git.weoa.com:ttip/weevent-broker.git --maven weoa --version 0.9.0"
    echo "     package governance module: ./package.sh --governance git@git.weoa.com:ttip/weevent-governance.git --maven weoa --version 0.9.0"
    exit 1
}

if [ $# -lt 2 ]; then
    usage;
fi


while [ $# -ge 2 ] ; do
    case "$1" in
    --broker) para="$1 = $2;";broker_git_address="$2";shift 2;;
    --governance) para="$1 = $2;";governance_git_address="$2";shift 2;;
    --maven) para="$1 = $2;";maven="$2";shift 2;;
    --version) para="$1 = $2;";version="$2";shift 2;;
    *) echo "unknown parameter $1." ; exit 1 ; break;;
    esac
done

weevent_out_path=$top_path/weevent-$version
module_out_path=$top_path/modules

broker_git=`echo $broker_git_address | awk -F '[#]' '{print $(NF=1)}'`
broker_branch=`echo $broker_git_address | awk -F '[#]' '{print $(NF=2)}'`
if [ -z $broker_branch ];then 
    broker_branch="master"
fi

governance_git=`echo $governance_git_address | awk -F '[#]' '{print $(NF=1)}'`
governance_branch=`echo $governance_git_address | awk -F '[#]' '{print $(NF=2)}'`
if [ -z $governance_branch ];then    
    governance_branch="master"
fi

echo "param broker_git:"$broker_git
echo "param broker_branch:"$broker_branch
echo "param governance_git:"$governance_git
echo "param governance_branch:"$governance_branch
echo "param maven:"$maven
echo "param version:"$version

function copy_file(){ 
    for fileName in `ls`;
        do
            if [ -f $fileName ]; then
                if [[ $fileName != "package.sh" && $fileName != "weevent-$version.tar.gz" ]];then
                    cp $fileName $weevent_out_path;                    
                fi
            elif test -d $fileName; then
                if [[ $fileName != "weevent-$version" ]];then
                    cp -r $fileName $weevent_out_path; 
                fi					
            else
                echo "$FilePath is a invalid path";
            fi
        done 
}

function remove_modules_tempdir_and_tar(){
    cd $weevent_out_path/modules
    remove_dir $weevent_out_path/modules/broker/temp 
    remove_dir $weevent_out_path/modules/broker/weevent-broker-$version
    if [ -e $weevent_out_path/modules/broker/weevent-broker-$version.tar.gz ];then 
        rm $weevent_out_path/modules/broker/weevent-broker-$version.tar.gz
    fi
    
    remove_dir $weevent_out_path/modules/governance/temp 
    remove_dir $weevent_out_path/modules/governance/weevent-governance-$version
    if [ -e $weevent_out_path/modules/governance/weevent-governance-$version.tar.gz ];then 
        rm $weevent_out_path/modules/governance/weevent-governance-$version.tar.gz
    fi   
}

# if path exists,remove it
function remove_dir(){
    if [ -d $1 ];then
        rm -rf $1
        execute_result "remove path $1"
    fi 
}

# clone broker from git, build
function broker_clone_build(){
    cd $out_path/broker
    mkdir -p temp
    cd temp
    echo "clone broker from git start "
    # branch of $broker_branch
    git clone -b $broker_branch $broker_git;
    execute_result "weevent-broker git address or branch error,clone from git"
    yellow_echo "clone broker from git success  "
    
    if [ -e $out_path/broker/temp/weevent-broker/build.gradle ]; then 
        sed -i "/^version/cversion = \"$version\""  $out_path/broker/temp/weevent-broker/build.gradle
        execute_result "config broker version"
        if [ -n "$maven" ];then
            sed -i 's/aliyun/weoa/g' $out_path/broker/temp/weevent-broker/build.gradle
            execute_result "update maven store"
        fi         
    fi
	
    cd weevent-broker	 
    echo "build weevent-broker start "
    # build
    gradle clean build -x test;
    execute_result "weevent-broker build"
    yellow_echo "build weevent-broker success "       
}

# clone governance from git, build
function governance_clone_build(){
    cd $out_path/governance/
    mkdir -p temp
    cd  temp 
    echo "clone weevent-governance from git start "
    # branch of $governance_branch
    git clone -b $governance_branch $governance_git;
    execute_result "weevent-governance git address or branch error,clone from git"
    yellow_echo "clone weevent-governance from git success  "
	
    if [ -e $out_path/governance/temp/weevent-governance/build.gradle ]; then
        sed -i "/^version/cversion = \"$version\"" $out_path/governance/temp/weevent-governance/build.gradle
        execute_result "config governance version"
        if [ -n "$maven" ];then
            sed -i 's/aliyun/weoa/g' $out_path/governance/temp/weevent-governance/build.gradle
            execute_result "update maven store"
        fi                        
    fi
	
    cd weevent-governance
    echo "build weevent-governance start "
    # build
    gradle clean build -x test;	
    execute_result "weevent-governance build" 	 
    yellow_echo "build weevent-governance success  "	    
}

function execute_result(){
    if [ $? -ne 0 ];then
        echo "$1  fail"
        exit 1
    fi	 	 
}

# chmod $ dos2unix
function set_permission(){
    cd $1	
    find $1 -name "*.sh" -exec chmod +x {} \;  
    find $1 -name "*.sh" -exec dos2unix {} \;
    find $1 -name "*.ini" -exec dos2unix {} \;
    find $1 -name "*.properties" -exec dos2unix {} \;
    cd ..
}

# switch to prod,remove dev properties
function switch_to_prod(){
    if [ -e $out_path/broker/conf/application.properties ]; then	    
        sed -i 's/dev/prod/' $out_path/broker/conf/application.properties
    fi

    if [ -e $out_path/governance/conf/application.yml ]; then	    
        sed -i 's/dev/prod/' $out_path/governance/conf/application.yml		
    fi
	
    if [ -e $out_path/broker/conf/application-dev.properties ]; then	
        rm $out_path/broker/conf/application-dev.properties
    fi

    if [ -e $out_path/governance/conf/application-dev.yml ]; then	    
        rm $out_path/governance/conf/application-dev.yml	
    fi


    if [ -e $out_path/broker/weevent-broker-$version/conf/application.properties ]; then	    
        sed -i 's/dev/prod/' $out_path/broker/weevent-broker-$version/conf/application.properties
    fi

    if [ -e $out_path/governance/weevent-governance-$version/conf/application.yml ]; then	    
        sed -i 's/dev/prod/' $out_path/governance/weevent-governance-$version/conf/application.yml		
    fi
	
    if [ -e $out_path/broker/weevent-broker-$version/conf/application-dev.properties ]; then	
        rm $out_path/broker/weevent-broker-$version/conf/application-dev.properties
    fi

    if [ -e $out_path/governance/weevent-governance-$version/conf/application-dev.yml ]; then	    
        rm $out_path/governance/weevent-governance-$version/conf/application-dev.yml	
    fi
}

function confirm(){
    # confirm
    if [ -d $1 ]; then
        read -p "$out_path already exist, continue? [Y/N]" cmd_input
        if [ "Y" != "$cmd_input" ]; then
            echo "input $cmd_input, install skipped"
            exit 1
        fi
    fi
}

function yellow_echo () {
    local what=$*
    if true;then
        echo -e "\e[1;33m${what} \e[0m"
    fi
}

# package weevent-$version
function package_weevent(){
    local out_path=""
    confirm $weevent_out_path 
    mkdir -p weevent-$version
    execute_result "mkdir weevent-$version"
    copy_file;
    remove_modules_tempdir_and_tar;
    out_path=$weevent_out_path/modules
        
    broker_clone_build $out_path;
    cp -r $out_path/broker/temp/weevent-broker/dist/* $out_path/broker;
    cd $out_path/broker;
    rm -rf temp;
    echo "copy weevent-broker dist over  "
        
    governance_clone_build $out_path;
    cp -r $out_path/governance/temp/weevent-governance/dist/* $out_path/governance;
    cd $out_path/governance;
    rm -rf temp;
    echo "copy weevent-governance dist over  " 
                 
    switch_to_prod $out_path;              
    set_permission $weevent_out_path;
        
    echo "tar weevent-$version start "
    tar -czvf weevent-$version.tar.gz weevent-$version
    rm -rf weevent-$version
    execute_result "remove folder weevent-$version"
}

# package weevent-broker-$version
function package_weevent_broker(){
    local out_path=""
    out_path=$module_out_path 
    confirm $out_path/broker/weevent-broker-$version 
    cd $out_path/broker           
    mkdir -p weevent-broker-$version
    execute_result "mkdir weevent-broker-$version"
           
    broker_clone_build $out_path; 
    
    cp -r $out_path/broker/temp/weevent-broker/dist/* $out_path/broker/weevent-broker-$version;
    cd $out_path/broker;
    rm -rf temp;
    echo "copy weevent-broker dist over  " 
        
    switch_to_prod $out_path;    
    set_permission $out_path/broker/weevent-broker-$version;
    
    echo "tar weevent-broker-$version start "
    tar -czvf weevent-broker-$version.tar.gz weevent-broker-$version
    rm -rf weevent-broker-$version
    execute_result "remove folder weevent-broker-$version"
}

# package weevent-governance-$version
function package_weevent_governance(){
    local out_path=""
    out_path=$module_out_path       
    confirm $out_path/governance/weevent-governance-$version  
    cd $out_path/governance      
    mkdir -p weevent-governance-$version
    execute_result "mkdir weevent-governance-$version"
    
    governance_clone_build $out_path;
    
    cp -r $out_path/governance/temp/weevent-governance/dist/* $out_path/governance/weevent-governance-$version;
    cd $out_path/governance;
    rm -rf temp;
    echo "copy weevent-governance dist over  " 
          
    switch_to_prod $out_path;   
    set_permission $out_path/governance/weevent-governance-$version;
    
    echo "tar weevent-governance-$version start "
    tar -czvf weevent-governance-$version.tar.gz weevent-governance-$version
    rm -rf weevent-governance-$version
    execute_result "remove folder weevent-governance-$version"
}

function main(){ 
    if [ -z "$version" ];then
        echo "package version is null"
        exit 1
    fi    
           
    # package
    if [ -n "$broker_git_address" ];then 
        if [ -n "$governance_git_address" ];then
            package_weevent
        else
            package_weevent_broker
        fi          
    else 
        if [ -n "$governance_git_address" ];then
            package_weevent_governance
        else
            echo "git address null"
            usage 
        fi       
    fi  
    
    yellow_echo "package success "
}

main $1 $2 $3 $4 $5 $6