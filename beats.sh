#!/usr/bin/env bash

set -euxo pipefail

# setup filebeat
docker run \
    --rm \
    --cap-add=NET_ADMIN \
    docker.elastic.co/beats/filebeat:7.7.1 setup -e \
    -E output.elasticsearch.hosts=['10.30.51.28:9200'] \
    -E setup.kibana.host=10.30.51.28:5601

# setup metricbeat
docker run \
    --rm \
    --cap-add=NET_ADMIN \
    docker.elastic.co/beats/metricbeat:7.7.1 setup -e \
    -E output.elasticsearch.hosts=["10.30.51.28:9200"] \
    -E setup.kibana.host=10.30.51.28:5601

# setup packetbeat
docker run \
    --rm \
    --cap-add=NET_ADMIN \
    docker.elastic.co/beats/packetbeat:7.7.1 setup -e \
    -E output.elasticsearch.hosts=["10.30.51.28:9200"] \
    -E setup.kibana.host=10.30.51.28:5601

# run filebeat
docker run \
    --rm \
    --name=filebeat \
    --volume="/var/log/:/var/log/:ro" \
    --volume="$(pwd)/filebeat.docker.yml:/usr/share/filebeat/filebeat.yml:ro" \
    docker.elastic.co/beats/filebeat:7.7.1 filebeat

# run metricbeat
docker run \
    --rm \
    --name=metricbeat \
    --volume="$(pwd)/metricbeat.docker.yml:/usr/share/metricbeat/metricbeat.yml:ro" \
    --volume="/var/run/docker.sock:/var/run/docker.sock:ro" \
    --volume="/sys/fs/cgroup:/hostfs/sys/fs/cgroup:ro" \
    --volume="/proc:/hostfs/proc:ro" \
    --volume="/:/hostfs:ro" \
    docker.elastic.co/beats/metricbeat:7.7.1 metricbeat

# run packetbeat
docker run \
    --rm \
    --name=packetbeat \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    --net=host \
    --volume="$(pwd)/packetbeat.docker.yml:/usr/share/packetbeat/packetbeat.yml:ro" \
    docker.elastic.co/beats/packetbeat:7.7.1
