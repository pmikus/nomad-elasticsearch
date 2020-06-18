job "es-cluster" {
  type = "service"
  datacenters = ["yul1"]
  update {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "180s"
  }
  meta {
    ES_CLUSTER_NAME = "${NOMAD_REGION}-${NOMAD_JOB_NAME}"
  }
  group "es-cluster-master" {
    count = 1
    constraint {
      attribute = "${node.class}"
      value = "monitor"
    }
    task "es-cluster-master" {
      driver = "docker"
      user = "root"
      kill_timeout = "600s"
      kill_signal = "SIGTERM"
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:7.7.1"
        command = "elasticsearch"
        args = [
          "-Ebootstrap.memory_lock=true",                          # lock all JVM memory on startup
          "-Ecluster.name=${NOMAD_META_ES_CLUSTER_NAME}",          # name of the cluster - this must match between master and data nodes
          "-Ecluster.initial_master_nodes=${NOMAD_GROUP_NAME}[${NOMAD_ALLOC_INDEX}]",
          "-Ehttp.port=${NOMAD_PORT_rest}",                        # HTTP port (originally port 9200) to listen on inside the container
          "-Ehttp.publish_port=${NOMAD_HOST_PORT_rest}",           # HTTP port (originally port 9200) on the host instance
          "-Enetwork.host=0.0.0.0",                                # IP to listen on for all traffic
          "-Enetwork.publish_host=0.0.0.0",                        # IP to broadcast to other elastic search nodes (this is a host IP, not container)
          "-Enode.data=true",                                      # node is allowed to store data
          "-Enode.master=true",                                    # node is allowed to be elected master
          "-Enode.name=${NOMAD_ALLOC_NAME}",                       # node name is defauled to the allocation name
          "-Epath.logs=/alloc/logs/",                              # log data to allocation directory
          "-Etransport.publish_port=${NOMAD_HOST_PORT_transport}", # Transport port (originally port 9300) on the host instance
          "-Etransport.port=${NOMAD_PORT_transport}",              # Transport port (originally port 9300) inside the container
          "-Expack.license.self_generated.type=basic",             # use x-packs basic license (free)
        ]
        ulimit {
          memlock = "-1"
          nofile = "65536"
          nproc = "8192"
        }
        mounts = [
          {
            type = "volume"
            target = "/usr/share/elasticsearch/data/"
            source = "es-cluster-master-vol"
            readonly = false
          }
        ]
      }
      service {
        name = "${NOMAD_JOB_NAME}-discovery"
        port = "transport"
        check {
          name = "transport-tcp"
          port = "transport"
          type = "tcp"
          interval = "5s"
          timeout = "4s"
        }
      }
      service {
        name = "${NOMAD_JOB_NAME}"
        port = "rest"
        tags = ["dd-elastic"]
        check {
          name = "rest-tcp"
          port = "rest"
          type = "tcp"
          interval = "5s"
          timeout = "4s"
        }
        check {
          name = "rest-http"
          type = "http"
          port = "rest"
          path = "/"
          interval = "5s"
          timeout = "4s"
        }
      }
      resources {
        cpu = 1024
        memory = 8192
        network {
          mbits = 25
          port "rest" {
            static = 9200
          }
          port "transport" {
            static = 9300
          }
        }
      }
    }
  }
  group "es-cluster-data" {
    count = 1
    constraint {
      attribute = "${node.class}"
      value = "monitor"
    }
    ephemeral_disk {
      size = "50000"
      sticky = true
      migrate = false
    }
    task "es-cluster-data" {
      driver = "docker"
      user = "root"
      kill_timeout = "600s"
      kill_signal = "SIGTERM"
      env {
        ES_JAVA_OPTS = "-Xms1g -Xmx1g"
      }
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:7.7.1"
        command = "elasticsearch"
        args = [
          "-Ebootstrap.memory_lock=true",                          # lock all JVM memory on startup
          "-Ecluster.name=${NOMAD_META_ES_CLUSTER_NAME}",          # name of the cluster - this must match between master and data nodes
          "-Ecluster.initial_master_nodes=${NOMAD_GROUP_NAME}[${NOMAD_ALLOC_INDEX}]",
          "-Ehttp.port=${NOMAD_PORT_rest}",                        # HTTP port (originally port 9200) to listen on inside the container
          "-Ehttp.publish_port=${NOMAD_HOST_PORT_rest}",           # HTTP port (originally port 9200) on the host instance
          "-Enetwork.host=0.0.0.0",                                # IP to listen on for all traffic
          "-Enetwork.publish_host=0.0.0.0",                        # IP to broadcast to other elastic search nodes (this is a host IP, not container)
          "-Enode.data=true",                                      # node is allowed to store data
          "-Enode.master=false",                                   # node is not allowed to be elected master
          "-Enode.name=${NOMAD_ALLOC_NAME}",                       # node name is defauled to the allocation name
          "-Epath.data=/alloc/data/",
          "-Epath.logs=/alloc/logs/",                              # log data to allocation directory
          "-Etransport.publish_port=${NOMAD_HOST_PORT_transport}", # Transport port (originally port 9300) on the host instance
          "-Etransport.port=${NOMAD_PORT_transport}",              # Transport port (originally port 9300) inside the container
          "-Expack.license.self_generated.type=basic",             # use x-packs basic license (free)
        ]
        ulimit {
          memlock = "-1"
          nofile = "65536"
          nproc = "8192"
        }
      }
      service {
        name = "${NOMAD_JOB_NAME}"
        port = "rest"
        tags = ["dd-elastic"]
        check {
          name = "rest-tcp"
          port = "rest"
          type = "tcp"
          interval = "5s"
          timeout = "4s"
        }
        check {
          name = "rest-http"
          type = "http"
          port = "rest"
          path = "/"
          interval = "5s"
          timeout = "4s"
        }
      }
      resources {
        cpu = 1024
        memory = 8192
        network {
          mbits = 25
          port "rest" {}
          port "transport" {}
        }
      }
    }
  }

  group "es-cluster-kibana" {
    count = 1
    constraint {
      attribute = "${node.class}"
      value = "monitor"
    }
    update {
      max_parallel = 1
      health_check = "checks"
      min_healthy_time = "10s"
    }
    task "es-cluster-kibana" {
      driver = "docker"
      kill_timeout = "60s"
      kill_signal = "SIGTERM"
      config {
        image = "docker.elastic.co/kibana/kibana:7.7.1"
        command = "kibana"
        args = [
          "--elasticsearch.hosts=http://${NOMAD_IP_http}:9200",
          "--server.host=0.0.0.0",
          "--server.name=${NOMAD_JOB_NAME}",
          "--server.port=${NOMAD_PORT_http}",
          "--xpack.apm.ui.enabled=false",
          "--xpack.graph.enabled=false",
          "--xpack.grokdebugger.enabled=false",
          "--xpack.maps.enabled=false",
          "--xpack.ml.enabled=false",
          "--xpack.searchprofiler.enabled=false"
        ]
        ulimit {
          memlock = "-1"
          nofile = "65536"
          nproc = "8192"
        }
      }
      service {
        name = "${NOMAD_JOB_NAME}-kibana"
        port = "http"
        check {
          name = "http-tcp"
          port = "http"
          type = "tcp"
          interval = "5s"
          timeout = "4s"
        }
        check {
          name = "http-http"
          type = "http"
          port = "http"
          path = "/"
          interval = "5s"
          timeout = "4s"
        }
      }
      resources {
        cpu = 1024
        memory = 2048
        network {
          mbits = 5
          port "http" {
            static = 5601
          }
        }
      }
    }
  }
}
