#! /usr/bin/env bash

banner='\
██╗  ██╗ █████╗ ██████╗  ██████╗  ██████╗ ██████╗     ██╗███╗   ██╗    ████████╗██╗  ██╗███████╗     ██████╗██╗      ██████╗ ██╗   ██╗██████╗\
██║  ██║██╔══██╗██╔══██╗██╔═══██╗██╔═══██╗██╔══██╗    ██║████╗  ██║    ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗\
███████║███████║██║  ██║██║   ██║██║   ██║██████╔╝    ██║██╔██╗ ██║       ██║   ███████║█████╗      ██║     ██║     ██║   ██║██║   ██║██║  ██║\
██╔══██║██╔══██║██║  ██║██║   ██║██║   ██║██╔═══╝     ██║██║╚██╗██║       ██║   ██╔══██║██╔══╝      ██║     ██║     ██║   ██║██║   ██║██║  ██║\
██║  ██║██║  ██║██████╔╝╚██████╔╝╚██████╔╝██║         ██║██║ ╚████║       ██║   ██║  ██║███████╗    ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝\
╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝  ╚═════╝ ╚═╝         ╚═╝╚═╝  ╚═══╝       ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝' 

############################################
# Creates an az virtualenv and installs it #
############################################
azvenv () {
    python3 -m venv .az
    ./.az/bin/python -m pip install --upgrade pip &>> ./.log
    ./.az/bin/python -m pip install azure-cli &>> ./.log
}

#################################################
# Creates an ansible virtualenv and installs it #
#################################################
ansiblevenv () {
    python3 -m venv .ansible
    ./.ansible/bin/python -m pip install --upgrade pip &>> ./.log
    ./.ansible/bin/python -m pip install ansible &>> ./.log
}

#################################
# Installs ansible azcollection #
#################################
azcollectionInstall () {
    ./.ansible/bin/ansible-galaxy collection install azure.azcollection &>> ./.log
    ./.ansible/bin/pip install -r "./.ansible/lib/python*/site-packages/ansible_collections/azure/azcollection/requirements-azure.txt" &>> ./.log
}


###################
# Azure CLI login #
###################
azlogin () {
    if ! ./.az/bin/az account show &>> ./.log; then
        if  ! ./.az/bin/az login &>> ./.log; then
            echo '##[ERROR]## Azure CLI login failed ! ##'
            exit 1
        else
            echo '##[INFO]## Azure CLI login successful ! ##'
        fi
    fi
    if ! ./.az/bin/az account set --subscription "Azure for Students" &>> ./.log; then
        echo '##[ERROR]## You don'\''t have a valid Azure for Students subscription ! ##'
        exit 1
    else
        echo '##[INFO]## Found a valid subscription ! ##'
    fi
    #shellcheck disable=SC2155
    export AZURE_TENANT="$(./.az/bin/az account list --query "[?name == 'Azure for Students']" | jq -r '.[0]."tenantId"')"
    #shellcheck disable=SC2155
    export AZURE_SUBSCRIPTION_ID="$(./.az/bin/az account list --query "[?name == 'Azure for Students']" | jq -r '.[0]."id"'  )"
}

######################################
# Creates an Azure service principal #
######################################
azCreateSP () {
    if [ ! -f "./.spcreds" ]; then
        spSecret="$(./.az/bin/az ad sp create-for-rbac --display-name hitc --role b24988ac-6180-42a0-ab88-20f7382dd24c --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID" | jq -r '."password"')"
        spClientID="$(./.az/bin/az ad sp list --show-mine --query "[?displayName == 'hitc']" | jq -r '.[0]."appId"')"
        if [ -z "${spSecret}" ] || [ -z "${spClientID}" ]; then
            echo "##[ERROR]## Service Principal creation failed ! ##"
            exit 1
        else
            # Yeah, this is ugly. I know !
            echo -e export AZURE_SECRET="${spSecret}""\n"export AZURE_CLIENT_ID="${spClientID}" > ./.spcreds
        fi
    fi
    #shellcheck disable=SC1091
    if ! source ./.spcreds; then
        echo "##[ERROR]## Yeah, I messed up. I don't know how but I did. ##"
        exit 1
    fi
}

###########################################
# Setting necessary environment variables #
###########################################
setEnvVariables () {
    export ANSIBLE_HOST_KEY_CHECKING=false
    export ANSIBLE_AZURE_VM_RESOURCE_GROUPS=HadoopRG
}

############################################
# Verifies SSH keys existence and validity #
############################################
verifyssh(){
    retVal=0
    if [ ! -e "./.ssh/connectionKey" ] || [ ! -e "./.ssh/connectionKey.pub" ]; then
        retVal=1
    else
        if ! diff <( ssh-keygen -y -e -f ./.ssh/connectionKey ) <( ssh-keygen -y -e -f ./.ssh/connectionKey.pub ) &>> ./.log; then  # Long Live StackOverflow !
            retVal=1
        fi

    fi
    if [ ! -e "./.ssh/intranodeKey" ] || [ ! -e "./.ssh/intranodeKey.pub" ]; then
        retVal=$((retVal+2)) 
    else
        if ! diff <( ssh-keygen -y -e -f "./.ssh/intranodeKey" ) <( ssh-keygen -y -e -f "./.ssh/intranodeKey.pub" ) &>> ./.log; then
            retVal=$((retVal+2)) 
        fi
    fi
    return "${retVal}"
}
####################################
# Creating necessary ssh key pairs #
####################################
genssh () {
    mkdir -p .ssh
    verifyssh
    val="$?"
    if [ "${val}" -ne 0 ]; then
        if [ "${val}" -ne 3 ]; then
            if [ "${val}" -ne 2 ]; then
                rm -f ./.ssh/connectionKey /.ssh/connectionKey.pub
                ssh-keygen -t rsa -b 4096 -f ./.ssh/connectionKey -q -N ""
            else
                rm -f ./.ssh/intranodeKey /.ssh/intranodeKey.pub
                ssh-keygen -t rsa -b 4096 -f ./.ssh/intranodeKey -q -N ""

            fi
        else
                rm -f ./.ssh/connectionKey /.ssh/connectionKey.pub
                ssh-keygen -t rsa -b 4096 -f ./.ssh/connectionKey -q -N ""
                rm -f ./.ssh/intranodeKey /.ssh/intranodeKey.pub
                ssh-keygen -t rsa -b 4096 -f ./.ssh/intranodeKey -q -N ""
        fi
    fi
}

########################################
# Cleanup in case of user interruption #
########################################
cleanup () {
    pass
}

main() {
#TODO: Check if the script is run from outside its parent directory
echo '##[INFO]## Checking necessary pacakges: ##'
# Check for necessary pacakges 
if ! command -v python3 &>> ./.log; then
    echo "##[WARNING]## You should install Python3 first ! ##" 
    return 1
fi  
if ! command -v jq &>> ./.log; then
    echo "##[WARNING]## You should install Python3 first ! ##" 
    return 1
fi 
if ! python3 -c 'import venv,ensurepip'  !  &>> ./.log; then
    echo "##[WARNING]## You should install Python3 first ! ##"
    return 1
fi
echo '##[INFO]## You'\''re good ! ##'
# Check for az and ansible existence else install them
if ! ansiblevenv ; then
    #shellcheck disable=SC2016
    echo '##[ERROR]## Your probably have some network issues. run `rm -rf .ansible` then rerun the script. ##'
    exit 1
fi
echo '##[INFO]## Ansible installed. ##'

if ! azvenv ; then
    #shellcheck disable=SC2016
    echo '##[ERROR]##  Your probably have some network issues. run `rm -rf .az` then rerun the script. ##'
    exit 1
fi
echo '##[INFO]## Installed Azure CLI. ##'

echo '##[INFO]## Installing necessary Ansible collections : ##'
azcollectionInstall
azlogin
azCreateSP

echo '##[INFO]## Doing some magic. ##'
genssh
setEnvVariables

echo '##[INFO]## LESSSGOOOO ! ##'
./.ansible/bin/ansible-playbook ./deployment/deployment.yaml -e "connection_key=\"$(< ./.ssh/connectionKey.pub)\"" -e "intranode_key=\"$(< ./.ssh/intranodeKey.pub)\"" -e "number_of_slaves=2"
./.ansible/bin/ansible-playbook ./deployment/configuration.yaml -i ./deployment/inventories/vm.azure_rm.yaml --private-key="./.ssh/connectionKey"
# This is hacky I know
echo '##[INFO]## Use these commands to connect: ##'
./.ansible/bin/ansible-playbook control/connectiondetails.yaml -i deployment/inventories/vm.azure_rm.yaml --private-key .ssh/connectionKey

}

echo "${banner}"
main