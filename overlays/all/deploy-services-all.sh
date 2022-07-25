#!/bin/bash

set -exuo pipefail

source ${BASH_SOURCE%/*}/../setup.sh


prepareNamespaces
oc apply -k ${BASH_SOURCE%/*}/ -n ${TOOLS_NAMESPACE}
deployApicastOperator
deployRHSSO
