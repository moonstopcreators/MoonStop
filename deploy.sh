#!/bin/bash

set -e

SILICON=0
GCLOUD=`which gcloud`

function install_homebrew {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

function brew_install {
    local PREFIX=''
    if [[ $SILICON == 1 ]]; then
        PREFIX="arch -arm64 "
    fi
    $PREFIX brew install $@
}

function find_or_install_google_cloud_sdk_cli {
    if [[ ${GCLOUD} ]]; then
        return
    fi
    local BINARY_PATH="${HOME}/google-cloud-sdk/bin/gcloud"
    if [[ -f ${BINARY_PATH} ]]; then
        GCLOUD=${BINARY_PATH}
        return
    fi
    local DOWNLOAD_URL="http://dl.google.com/dl/cloudsdk/channels/rapid/downloads"
    local DOWNLOAD_DIR="${HOME}/Downloads"
    local INSTALL_DIR="${HOME}/google-cloud-sdk"
    [[ `which wget` ]] || brew_install wget
    # https://cloud.google.com/sdk/docs/install
    if [[ $SILICON == 1 ]]; then
        local TAR_FILENAME='google-cloud-cli-383.0.1-darwin-arm.tar.gz'
    else
        local TAR_FILENAME='google-cloud-cli-383.0.1-darwin-x86_64.tar.gz'
    fi
    local SOURCE=${DOWNLOAD_URL}/${TAR_FILENAME}
    local TARGET=${DOWNLOAD_DIR}/${TAR_FILENAME}
    wget ${SOURCE} -O ${TARGET}
    rm -rf ${INSTALL_DIR} && tar -xf ${TARGET} -C ${HOME}/
    local PATH_CONFIG_LINE="export PATH=\$PATH:${INSTALL_DIR}/bin"
    BASHRC=${HOME}/.bashrc
    touch ${BASHRC}
    [[ `cat ${BASHRC} | grep "${PATH_CONFIG_LINE}"` ]] || echo ${PATH_CONFIG_LINE} >> ${BASHRC}
    source ${BASHRC}
    GCLOUD=${INSTALL_DIR}/bin/gcloud
}

if [[ $OSTYPE == *darwin* ]]; then
    [[ `sysctl -a | grep machdep.cpu.brand_string` == *M1* ]] && SILICON=1
    [[ `which brew` ]] || install_homebrew
    [[ `which jq` ]] || brew_install jq
    find_or_install_google_cloud_sdk_cli
else
    exit
fi

CONFIG=moonstop

CONFIGS=`gcloud config configurations list --format=json | jq -r .[].name`
[[ $CONFIGS == *${CONFIG}* ]] || gcloud config configurations create $CONFIG
gcloud config configurations activate $CONFIG

ACCOUNT=moonstop.creators@gmail.com

ACCOUNTS=`gcloud auth list --format=json | jq -r '.[] | "\(.account):\(.status)"'`
[[ $ACCOUNTS == *${ACCOUNT}:ACTIVE* ]] || gcloud auth login

PROJECT=moonstop
gcloud config set core/project $PROJECT
gcloud config set run/region us-central1
gcloud config set run/platform managed

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

SERVICE="moonstop-backend"
IMAGE="gcr.io/${PROJECT}/${SERVICE}"
STAGING_DIR="${THIS_DIR}"/.moonstop-backend

rm -rf "$STAGING_DIR" && mkdir "$STAGING_DIR"

rsync -r --exclude-from ${THIS_DIR}/backend/.cloudrunignore ${THIS_DIR}/backend/ ${STAGING_DIR}/

cd "$STAGING_DIR"

gcloud builds submit --tag $IMAGE

gcloud run deploy $SERVICE --image $IMAGE --port $8080 --allow-unauthenticated

URL=`gcloud run services describe ${SERVICE} --format 'value(status.url)'`

echo $URL

