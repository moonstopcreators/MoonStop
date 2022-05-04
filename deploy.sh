#!/bin/bash

set -e

SILICON=0
GOOGLE_CLOUD_SDK_CLI_BINARY=`which gcloud`
GOOGLE_CLOUD_PROJECT=moonstop
MOONSTOP_BACKEND_SERVICE="moonstop-backend"


if [[ $OSTYPE != *darwin* ]]; then
    echo ERROR: deploy.sh only works on Mac OS
    exit
fi

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

function brew {
    [[ $SILICON == 1 ]] && PREFIX='arch -arm64 ' || PREFIX=''
    ${PREFIX} brew $@
}

function gcloud {
    ${GOOGLE_CLOUD_SDK_CLI_BINARY} $@
}

function install_homebrew {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

function install_google_cloud_sdk_cli {
    # https://cloud.google.com/sdk/docs/install
    [[ $SILICON == 1 ]] && ARCH="arm" || ARCH="x86_64"
    local TAR_FILENAME="google-cloud-cli-383.0.1-darwin-${ARCH}.tar.gz"
    local SOURCE_URL="http://dl.google.com/dl/cloudsdk/channels/rapid/downloads"
    local TARGET="${HOME}/Downloads/${TAR_FILENAME}"
    [[ `which wget` ]] || brew install wget
    wget ${SOURCE_URL}/${TAR_FILENAME} -O ${TARGET}
    local INSTALL_DIR="${HOME}/google-cloud-sdk"
    tar -xf ${TARGET} -C ${HOME}/
    local PATH_CONFIG_LINE="export PATH=\$PATH:${INSTALL_DIR}/bin"
    GOOGLE_CLOUD_SDK_CLI_BINARY=${INSTALL_DIR}/bin/gcloud
    local BASHRC=${HOME}/.bashrc
    touch ${BASHRC}
    [[ `cat ${BASHRC} | grep "${PATH_CONFIG_LINE}"` ]] || echo ${PATH_CONFIG_LINE} >> ${BASHRC}
    source ${BASHRC}
}

function find_or_install_google_cloud_sdk_cli {
    if [[ ${GOOGLE_CLOUD_SDK_CLI_BINARY} ]]; then return; fi
    local BINARY_PATH="${HOME}/google-cloud-sdk/bin/gcloud"
    if [[ -f ${BINARY_PATH} ]]; then
        GOOGLE_CLOUD_SDK_CLI_BINARY=${BINARY_PATH}
        return
    fi
    install_google_cloud_sdk_cli
}

function configure_google_cloud_sdk_cli {
    local ACCOUNT=moonstop.creators@gmail.com
    local CONFIGS=`gcloud config configurations list --format=json | jq -r .[].name`
    [[ $CONFIGS == *${GOOGLE_CLOUD_PROJECT}* ]] || gcloud config configurations create ${GOOGLE_CLOUD_PROJECT}
    gcloud config configurations activate ${GOOGLE_CLOUD_PROJECT}
    local ACCOUNTS=`gcloud auth list --format=json | jq -r '.[] | "\(.account):\(.status)"'`
    [[ $ACCOUNTS == *${ACCOUNT}:ACTIVE* ]] || gcloud auth login
    gcloud config set core/project ${GOOGLE_CLOUD_PROJECT}
    gcloud config set run/region us-central1
    gcloud config set run/platform managed
}

function init {
    [[ `sysctl -a | grep machdep.cpu.brand_string` == *M1* ]] && SILICON=1
    [[ `which brew` ]] || install_homebrew
    [[ `which jq` ]] || brew install jq
    find_or_install_google_cloud_sdk_cli
    configure_google_cloud_sdk_cli
}

function deploy_backend {
    local SOURCE=${THIS_DIR}/backend
    local IMAGE="gcr.io/${GOOGLE_CLOUD_PROJECT}/${MOONSTOP_BACKEND_SERVICE}"
    local STAGING_DIR=${THIS_DIR}/.${MOONSTOP_BACKEND_SERVICE}
    rm -rf ${STAGING_DIR} && mkdir ${STAGING_DIR}
    rsync -r --exclude-from ${SOURCE}/.cloudrunignore ${SOURCE}/ ${STAGING_DIR}/
    cd ${STAGING_DIR}
    gcloud builds submit --tag ${IMAGE}
    gcloud run deploy ${MOONSTOP_BACKEND_SERVICE} --image ${IMAGE} --port $8080 --allow-unauthenticated
    cd ${THIS_DIR}
}

function main {
    init
    deploy_backend
    MOONSTOP_BACKEND_URL=`gcloud run services describe ${MOONSTOP_BACKEND_SERVICE} --format 'value(status.url)'`
    echo MoonStop Backend URL: ${MOONSTOP_BACKEND_URL}
}

main
