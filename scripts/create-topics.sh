#!/bin/sh

# due to https://github.com/redpanda-data/redpanda/issues/6651
# we need to create the topics only if they don't exist
# this script gets the list of topics from the arguments
# and creates them if they don't exist, creation is not invoked if the topics already exist
#
# A topic may be suffixed with a partition count: "my_topic:6" creates it
# with 6 partitions (default: 1).
existing=$(rpk topic list | awk 'NR > 1 { print $1 }')

for spec in "$@"; do
    topic=${spec%%:*}
    partitions=${spec#*:}
    [ "$partitions" = "$spec" ] && partitions=1

    if ! echo "$existing" | grep -qx "$topic"; then
        rpk topic create "$topic" --partitions "$partitions"
    fi
done
