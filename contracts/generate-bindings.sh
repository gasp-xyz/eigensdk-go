#!/bin/bash

set -o errexit -o nounset -o pipefail

# cd to the directory of this script so that this can be run from anywhere
script_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd -P
)

# build abigen-with-interfaces docker image if it doesn't exist
if [[ "$(docker images -q abigen-with-interfaces 2>/dev/null)" == "" ]]; then
    docker build -t abigen-with-interfaces -f abigen-with-interfaces.Dockerfile $script_path
fi

# TODO: refactor this function.. it got really ugly with the dockerizing of abigen
function create_binding {
    contract_dir=$1
    contract=$2
    binding_dir=$3
    echo $contract
    mkdir -p $binding_dir/${contract}
    contract_json="$contract_dir/out/${contract}.sol/${contract}.json"
    solc_abi=$(cat ${contract_json} | jq -r '.abi')
    solc_bin=$(cat ${contract_json} | jq -r '.bytecode.object')

    mkdir -p data
    echo ${solc_abi} >data/tmp.abi
    echo ${solc_bin} >data/tmp.bin

    rm -f $binding_dir/${contract}/binding.go
    docker run -v $(realpath $binding_dir):/home/binding_dir -v .:/home/repo abigen-with-interfaces --bin=/home/repo/data/tmp.bin --abi=/home/repo/data/tmp.abi --pkg=contract${contract} --out=/home/binding_dir/${contract}/binding.go
    rm -rf data/tmp.abi data/tmp.bin
}

rm -rf bindings/*
forge clean
forge build

avs_service_contracts="BLSApkRegistry DelegationManager EigenPod EigenPodManager IAVSDirectory IBLSSignatureChecker IERC20 IndexRegistry IRewardsCoordinator ISlasher IStrategy OperatorStateRetriever RegistryCoordinator ServiceManagerBase StakeRegistry StrategyManager"
for contract in $avs_service_contracts; do
    sleep 1 # this is a hack to fix the issue with abigen randomly failing for some contracts
    create_binding ./lib/eigenlayer-middleware/ $contract ./bindings
done

service_contracts="ContractsRegistry MockAvsServiceManager"
for contract in $service_contracts; do
    sleep 1 # this is a hack to fix the issue with abigen randomly failing for some contracts
    create_binding . $contract ./bindings
done

rm -rf data