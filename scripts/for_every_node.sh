#1/usr/bin/bash

if [[ -z $1 ]]; then
    echo "pass arguments as first argument"
    exit
fi

for node in $(./scripts/print_available_nodes.sh); do
    sbatch -w $node $@
done