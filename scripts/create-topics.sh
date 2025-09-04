#!/bin/sh

# due to https://github.com/redpanda-data/redpanda/issues/6651
# we need to create the topics only if they don't exist
# this script gets the list of topics from the arguments
# and creates them if they don't exist, creation is not invoked if the topics already exist
rpk topic list | awk -v expected="$*" '
BEGIN { 
    n = split(expected, exp_array, " ")
    for (i = 1; i <= n; i++)  expected_topics[exp_array[i]] = 1
} NR > 1 { 
    actual_topics[$1] = 1 
} END {
    for (topic in expected_topics) {
        if (!(topic in actual_topics)) printf "%s ", topic
    }
}' | xargs -r rpk topic create
