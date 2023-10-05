#!/bin/bash

while true; do
    docker cp $1:/tmp/trace .
    sleep $2
done