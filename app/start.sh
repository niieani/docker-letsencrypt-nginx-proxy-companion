#!/bin/bash

# SIGTERM-handler
term_handler() {
    [[ -n "$docker_gen_pid" ]] && kill $docker_gen_pid
    [[ -n "$letsencrypt_service_pid" ]] && kill $letsencrypt_service_pid
    [[ -n "$reload_service_pid" ]] && kill $reload_service_pid

    source /app/functions.sh
    remove_all_location_configurations

    exit 143; # 128 + 15 -- SIGTERM
}

trap 'term_handler' INT QUIT KILL TERM

if [[ "$RELOAD_ONLY" != "true" ]]; then
    /app/letsencrypt_service &
    letsencrypt_service_pid=$!
fi

/app/reload_service &
reload_service_pid=$!

docker-gen -watch -only-exposed -notify '/app/update_certs' -wait 15s:60s /app/letsencrypt_service_data.tmpl /app/letsencrypt_service_data &
docker_gen_pid=$!

# wait "indefinitely"
while [[ -e /proc/$docker_gen_pid ]]; do
    wait $docker_gen_pid # Wait for any signals or end of execution of docker-gen
done

# Stop container properly
term_handler
