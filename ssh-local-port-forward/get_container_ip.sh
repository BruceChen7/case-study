#!/usr/bin/env bash
function get_container_ip() {
    sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $1
}

get_container_ip $1
