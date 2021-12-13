job "goshimmer" {
  datacenters = ["hcloud"]

  priority  = 90

  group "leader" {
    ephemeral_disk {
      migrate = true
      sticky = true
    }

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = true
      canary            = 1
      stagger           = "2m"
    }

    network {
        mode = "host"

        port "analysis_api" {
          host_network = "private"
        }
        port "analysis_dashboard" {
          host_network = "private"
        }
        port "api" {
          host_network = "private"
        }
        port "autopeering" {
          host_network = "private"
        }
        port "dashboard" {
          host_network = "private"
        }
        port "fpc" {
          host_network = "private"
        }
        port "gossip" {
          host_network = "private"
        }
        port "profiling" {
          host_network = "private"
        }
        port "prometheus" {
          host_network = "private"
        }
        port "txstream" {
          host_network = "private"
        }
    }

    task "node" {
      driver = "docker"
      leader = true

      config {
        network_mode = "host"
        image = "${artifact.image}:${artifact.tag}"
        ports = [
            "analysis_api",
            "analysis_dashboard",
            "api",
            "autopeering",
            "dashboard",
            "fpc",
            "gossip",
            "profiling",
            "prometheus",
            "txstream",
        ]
        args  = [
            "--autoPeering.entryNodes=",
            "--config=$${CONFIG_PATH}",
            "--database.directory=$${DB_PATH}",
            "--mana.enableResearchVectors=false",
            "--mana.snapshotResetTime=true",
            "--messageLayer.snapshot.file=$${SNAPSHOT_PATH}",
            "--messageLayer.snapshot.genesisNode=",
            "--messageLayer.startSynced=true",
            "--metrics.global=true",
            "--metrics.local=true",
            "--metrics.manaResearch=false",
            "--node.seed=base58:8q491c3YWjbPwLmF2WD95YmCgh61j2kenCKHfGfByoWi",
            "--node.disablePlugins=clock,portcheck",
            "--faucet.seed=7R1itJx5hVuo9w9hjg5cwKFmek4HMSoBDgJZN8hKGxih",
            "--node.enablePlugins=analysisServer,analysisDashboard,prometheus,spammer,activity,snapshot,txStream,faucet",
            "--prometheus.processMetrics=false",
            "--statement.writeManaThreshold=1.0",
            "--statement.writeStatement=true",
            "--webAPI.exportPath=$${NOMAD_TASK_DIR}/tmp/",
        ]

        auth {
          username = "${auth.username}"
          password = "${auth.password}"
          server_address = "${auth.server_address}"
        }
      }

      artifact {
        source      = "https://github.com/iotaledger/goshimmer/raw/develop/tools/integration-tests/assets/7R1itJx5hVuo9w9hjg5cwKFmek4HMSoBDgJZN8hKGxih.bin"
        destination = "$${NOMAD_TASK_DIR}/snapshot.bin"
        mode        = "file"
      }
      
      template {
        destination = "$${NOMAD_TASK_DIR}/config.json"
        data = <<EOF
{
  "analysis": {
    "client": {
      "serverAddress": "{{ env "NOMAD_ADDR_analysis_api" }}"
    },
    "server": {
      "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_analysis_api" }}"
    },
    "dashboard": {
      "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_analysis_dashboard" }}",
      "dev": false
    }
  },
  "autoPeering": {
    "entryNodes": [],
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_autopeering" }}"
  },
  "dashboard": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_dashboard" }}",
    "dev": false,
    "basicAuth": {
      "enabled": false,
      "username": "goshimmer",
      "password": "goshimmer"
    }
  },
  "database": {
    "directory": "mainnetdb"
  },
  "drng": {
    "custom": {
      "instanceID": 1,
      "threshold": 3,
      "distributedPubKey": "",
      "committeeMembers": [
        "EYsaGXnUVA9aTYL9FwYEvoQ8d1HCJveQVL7vogu6pqCP"
      ]
    }
  },
  "fpc": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_fpc" }}"
  },
  "gossip": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_gossip" }}"
  },
  "logger": {
    "level": "debug",
    "disableCaller": false,
    "disableStacktrace": false,
    "encoding": "console",
    "outputPaths": [
      "stdout"
    ],
    "disableEvents": true
  },
  "metrics": {
    "local": true,
    "global": false
  },
  "prometheus": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_prometheus" }}"
  },
  "profiling": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_profiling" }}"
  },
  "txStream": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_txstream" }}"
  },
  "network": {
    "bindAddress": "0.0.0.0",
    "externalAddress": "auto"
  },
  "node": {
    "disablePlugins": "portcheck",
    "enablePlugins": []
  },
  "pow": {
    "difficulty": 2,
    "numThreads": 1,
    "timeout": "10s",
    "parentsRefreshInterval": "300ms"
  },
  "webAPI": {
    "basicAuth": {
      "enabled": false,
      "username": "goshimmer",
      "password": "goshimmer"
    },
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_api" }}"
  },
  "faucet": {
    "powDifficulty": 12
  }
}
EOF
      }

      service {
        tags = ["analysis_api"]

        port = "analysis_api"
      }

      service {
        tags = ["analysis_dashboard"]

        port = "analysis_dashboard"
      }

      service {
        tags = ["api"]

        port = "api"

        check {
          type     = "http"
          port     = "api"
          path     = "/healthz"
          interval = "2s"
          timeout  = "2s"
        }
      }

      service {
        tags = ["autopeering"]

        port = "autopeering"
      }

      service {
        tags = ["dashboard"]

        port = "dashboard"
      }

      service {
        tags = ["fpc"]

        port = "fpc"
      }

      service {
        tags = ["gossip"]

        port = "gossip"
      }

      service {
        tags = ["profiling"]

        port = "profiling"
      }

      service {
        tags = ["prometheus"]

        port = "prometheus"
      }

      service {
        tags = ["txstream"]

        port = "txstream"
      }
      

      env {
        # this will be available as the MOUNT_PATH environment
        # variable in the task
        DB_PATH = "$${NOMAD_TASK_DIR}/goshimmerdb"
        CONFIG_PATH = "$${NOMAD_TASK_DIR}/config.json"
        SNAPSHOT_PATH = "$${NOMAD_TASK_DIR}/snapshot.bin"
      }

      resources {
        memory = 4096
        cpu = 4096
      }
    }
  }

}