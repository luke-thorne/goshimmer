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
      stagger           = "30s"
    }

    network {
        mode = "host"

        // Leader
        port "analysis_api" {}
        port "analysis_dashboard" {}
        port "api" {}
        port "autopeering" {}
        port "dashboard" {}
        port "fpc" {}
        port "gossip" {}
        port "profiling" {}
        port "prometheus" {}
        port "txstream" {}
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
            "--autopeering.entryNodes=",
            "--config=$${CONFIG_PATH}",
            "--database.directory=$${DB_PATH}",
            "--mana.enableResearchVectors=false",
            "--mana.snapshotResetTime=true",
            "--messageLayer.snapshot.file=$${SNAPSHOT_PATH}",
            "--messageLayer.snapshot.genesisNode=",
            "--metrics.global=true",
            "--metrics.local=true",
            "--metrics.manaResearch=false",
            "--autopeering.seed=base58:8q491c3YWjbPwLmF2WD95YmCgh61j2kenCKHfGfByoWi",
            "--node.disablePlugins=clock,portcheck,metrics",
            "--node.enablePlugins=analysis-server,analysis-dashboard,prometheus,spammer,activity,snapshot,txstream",
            "--prometheus.processMetrics=false",
            "--statement.writeManaThreshold=1.0",
            "--statement.writeStatement=true",
            "--webapi.exportPath=$${NOMAD_TASK_DIR}/tmp/",
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
    "port": "{{ env "NOMAD_PORT_autopeering" }}"
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
      "instanceID": 111,
      "threshold": 3,
      "distributedPubKey": "",
      "committeeMembers": [
        "EYsaGXnUVA9aTYL9FwYEvoQ8d1HCJveQVL7vogu6pqCP"
      ]
    }
  },
  "fpc": {
    "drngInstanceID": 111,
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_fpc" }}"
  },
  "gossip": {
    "port": "{{ env "NOMAD_PORT_gossip" }}"
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
    "manaUpdateInterval": "5s"
  },
  "prometheus": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_prometheus" }}"
  },
  "profiling": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_profiling" }}"
  },
  "txstream": {
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
  },
  "txstream": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_txstream" }}"
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
        cpu = 3072
      }
    }
  }

  group "faucet" {
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
      stagger           = "30s"
    }

    network {
        mode = "host"

        port "analysis_api" {}
        port "analysis_dashboard" {}
        port "api" {}
        port "autopeering" {}
        port "dashboard" {}
        port "fpc" {}
        port "gossip" {}
        port "profiling" {}
        port "prometheus" {}
        port "txstream" {}
    }


    task "node" {
      driver = "docker"

      config {
        network_mode = "host"
        image = "${artifact.image}:${artifact.tag}"
        command =  "goshimmer"
        ports = [
            "api",
            "autopeering",
            "fpc",
            "gossip",
            "prometheus",
            "txstream",
        ]
        args  = [
            "--config=$${CONFIG_PATH}",
            "--database.directory=$${DB_PATH}",
            "--messageLayer.snapshot.file=$${SNAPSHOT_PATH}",
            "--messageLayer.startSynced=true",
            "--messageLayer.snapshot.genesisNode=",
            "--mana.snapshotResetTime=true",
            "--faucet.seed=7R1itJx5hVuo9w9hjg5cwKFmek4HMSoBDgJZN8hKGxih",
            "--autopeering.seed=base58:3YX6e7AL28hHihZewKdq6CMkEYVsTJBLgRiprUNiNq5E",
            "--node.disablePlugins=clock,portcheck,metrics",
            "--node.enablePlugins=bootstrap,prometheus,faucet,activity,txstream",
            "--webapi.exportPath=$${NOMAD_TASK_DIR}/tmp/",
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
      "serverAddress": "{{ range service "goshimmer-leader-node" }}{{ if in .Tags "analysis_api" }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}"
    },
    "server": {
      "bindAddress": "0.0.0.0:1888"
    },
    "dashboard": {
      "bindAddress": "0.0.0.0:9000",
      "dev": false
    }
  },
  "autoPeering": {
    "entryNodes": [
      "EYsaGXnUVA9aTYL9FwYEvoQ8d1HCJveQVL7vogu6pqCP@{{ range service "goshimmer-leader-node" }}{{ if in .Tags "autopeering" }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}"
    ],
    "port": "{{ env "NOMAD_PORT_autopeering" }}"
  },
  "dashboard": {
    "bindAddress": "0.0.0.0:8081",
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
      "instanceID": 111,
      "threshold": 3,
      "distributedPubKey": "",
      "committeeMembers": [
        "EYsaGXnUVA9aTYL9FwYEvoQ8d1HCJveQVL7vogu6pqCP"
      ]
    }
  },
  "fpc": {
    "drngInstanceID": 111,
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_fpc" }}"
  },
  "gossip": {
    "port": "{{ env "NOMAD_PORT_gossip" }}"
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
    "manaUpdateInterval": "5s"
  },
  "prometheus": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_prometheus" }}"
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
  },
  "txstream": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_txstream" }}"
  }
}
EOF
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
        tags = ["fpc"]

        port = "fpc"
      }

      service {
        tags = ["gossip"]

        port = "gossip"
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
        DB_PATH = "$${NOMAD_TASK_DIR}/goshimmerdb"
        CONFIG_PATH = "$${NOMAD_TASK_DIR}/config.json"
        SNAPSHOT_PATH = "$${NOMAD_TASK_DIR}/snapshot.bin"
      }

      resources {
        memory = 4096
        cpu = 3072
      }
    }
  }

  group "replica" {
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
      stagger           = "30s"
    }

    network {
        mode = "host"

        port "analysis_api" {}
        port "analysis_dashboard" {}
        port "api" {}
        port "autopeering" {}
        port "dashboard" {}
        port "fpc" {}
        port "gossip" {}
        port "profiling" {}
        port "prometheus" {}
        port "txstream" {}
    }

    task "node" {
      driver = "docker"

      config {
        network_mode = "host"
        image = "${artifact.image}:${artifact.tag}"
        command =  "goshimmer"
        ports = [
            "api",
            "autopeering",
            "fpc",
            "gossip",
            "prometheus",
            "txstream",
        ]
        args  = [
            "--config=$${CONFIG_PATH}",
            "--database.directory=$${DB_PATH}",
            "--messageLayer.snapshot.file=$${SNAPSHOT_PATH}",
            "--messageLayer.snapshot.genesisNode=",
            "--mana.snapshotResetTime=true",
            "--node.disablePlugins=clock,portcheck,metrics",
            "--node.enablePlugins=bootstrap,prometheus,activity,txstream",
            "--statement.writeStatement=true",
            "--statement.writeManaThreshold=1.0",
            "--webapi.exportPath=$${NOMAD_TASK_DIR}/tmp/"
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
      "serverAddress": "{{ range service "goshimmer-leader-node" }}{{ if in .Tags "analysis_api" }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}"
    },
    "server": {
      "bindAddress": "0.0.0.0:1888"
    },
    "dashboard": {
      "bindAddress": "0.0.0.0:9000",
      "dev": false
    }
  },
  "autoPeering": {
    "entryNodes": [
      "EYsaGXnUVA9aTYL9FwYEvoQ8d1HCJveQVL7vogu6pqCP@{{ range service "goshimmer-leader-node" }}{{ if in .Tags "autopeering" }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}"
    ],
    "port": "{{ env "NOMAD_PORT_autopeering" }}"
  },
  "dashboard": {
    "bindAddress": "0.0.0.0:8081",
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
      "instanceID": 111,
      "threshold": 3,
      "distributedPubKey": "",
      "committeeMembers": [
        "EYsaGXnUVA9aTYL9FwYEvoQ8d1HCJveQVL7vogu6pqCP"
      ]
    }
  },
  "fpc": {
    "drngInstanceID": 111,
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_fpc" }}"
  },
  "gossip": {
    "port": "{{ env "NOMAD_PORT_gossip" }}"
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
    "manaUpdateInterval": "5s"
  },
  "prometheus": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_prometheus" }}"
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
  },
  "txstream": {
    "bindAddress": "0.0.0.0:{{ env "NOMAD_PORT_txstream" }}"
  }
}
EOF
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
        tags = ["fpc"]

        port = "fpc"
      }

      service {
        tags = ["gossip"]

        port = "gossip"
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
        DB_PATH = "$${NOMAD_ALLOC_DIR}/goshimmerdb"
        CONFIG_PATH = "$${NOMAD_TASK_DIR}/config.json"
        SNAPSHOT_PATH = "$${NOMAD_TASK_DIR}/snapshot.bin"
      }

      resources {
        memory = 4096
        cpu = 3072
      }
    }
  }

  group "monitoring" {
    network {
        mode = "host"

        port "grafana" {
          to = "3000"
        }
        port "prometheus" {}
    }

    task "grafana" {
      driver = "docker"
      user = "104"

      config {
        // network_mode = "host"
        image = "grafana/grafana:latest"
        ports = [
          "grafana",
        ]
      }
      
      template {
        data = <<EOH
        apiVersion: 1

        providers:
          # <string> an unique provider name. Required
          - name: 'Goshimmer Local Metrics'
            # <int> Org id. Default to 1
            orgId: 1
            # <string> name of the dashboard folder.
            folder: ''
            # <string> folder UID. will be automatically generated if not specified
            folderUid: ''
            # <string> provider type. Default to 'file'
            type: file
            # <bool> disable dashboard deletion
            disableDeletion: false
            # <bool> enable dashboard editing
            editable: true
            # <int> how often Grafana will scan for changed dashboards
            updateIntervalSeconds: 10
            # <bool> allow updating provisioned dashboards from the UI
            allowUiUpdates: true
            options:
              # <string, required> path to dashboard files on disk. Required when using the 'file' type
              path: {{ env "$${NOMAD_TASK_DIR}" }}/grafana/dashboards
        EOH

        destination = "$${NOMAD_TASK_DIR}/provisioning/dashboards/dashboards.yml"
      }
      
      template {
        data = <<EOH
        # config file version
        apiVersion: 1

        # list of datasources to insert/update depending
        # what's available in the database
        datasources:
          # <string, required> name of the datasource. Required
          - name: Prometheus
            # <string, required> datasource type. Required
            type: prometheus
            # <string, required> access mode. proxy or direct (Server or Browser in the UI). Required
            access: direct
            # <int> org id. will default to orgId 1 if not specified
            orgId: 1
            # <string> custom UID which can be used to reference this datasource in other parts of the configuration, if not specified will be generated automatically
            uid:
            # <string> url
            url: http://{{ env "$${NOMAD_ADDR_prometheus}" }}
            # <string> Deprecated, use secureJsonData.password
            password:
            # <string> database user, if used
            user:
            # <string> database name, if used
            database:
            # <bool> enable/disable basic auth
            basicAuth:
            # <string> basic auth username
            basicAuthUser:
            # <string> Deprecated, use secureJsonData.basicAuthPassword
            basicAuthPassword:
            # <bool> enable/disable with credentials headers
            withCredentials:
            # <bool> mark as default datasource. Max one per org
            isDefault:
            # <map> fields that will be converted to json and stored in jsonData
            jsonData:
              graphiteVersion: '1.1'
              tlsAuth: false
              tlsAuthWithCACert: false
              timeInterval: '1s'
            # <string> json object of data that will be encrypted.
            # secureJsonData:
              # tlsCACert: '...'
              # tlsClientCert: '...'
              # tlsClientKey: '...'
              # <string> database password, if used
              # password:
              # <string> basic auth password
              # basicAuthPassword:
            version: 1
            # <bool> allow users to edit datasources from the UI.
            editable: true
        EOH

        destination = "$${NOMAD_TASK_DIR}/provisioning/datasources/datasources.yml"
      }

      artifact {
        source      = "https://github.com/iotaledger/goshimmer/raw/develop/tools/docker-network/grafana/dashboards/debugging_dashboard.json"
        destination = "$${NOMAD_TASK_DIR}/grafana/dashboards/"
      }

      artifact {
        source      = "https://github.com/iotaledger/goshimmer/raw/develop/tools/docker-network/grafana/dashboards/global_dashboard.json"
        destination = "$${NOMAD_TASK_DIR}/grafana/dashboards/"
      }

      artifact {
        source      = "https://github.com/iotaledger/goshimmer/raw/develop/tools/docker-network/grafana/dashboards/local_dashboard.json"
        destination = "$${NOMAD_TASK_DIR}/grafana/dashboards/"
      }

      artifact {
        source      = "https://github.com/iotaledger/goshimmer/raw/develop/tools/docker-network/grafana/dashboards/mana_research_dashboard.json"
        destination = "$${NOMAD_TASK_DIR}/grafana/dashboards/"
      }

      env {
        GF_PATHS_PROVISIONING = "$${NOMAD_TASK_DIR}/provisioning"
      }

      resources {
        memory = 64
        cpu = 64
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        // network_mode = "host"
        image = "prom/prometheus:latest"
        command = "--config.file=$${NOMAD_TASK_DIR}/provisioning/prometheus.yml"
        args = [
          "--web.listen-address=0.0.0.0:$${NOMAD_PORT_prometheus}",
        ]
        ports = [
          "prometheus",
        ]
      }
      
      template {
        data = <<EOH
        scrape_configs:
            - job_name: goshimmer
              scrape_interval: 5s
              static_configs:
              - targets:
                - {{ env "$${NOMAD_ADDR_leader_prometheus}" }}
                - {{ env "$${NOMAD_ADDR_faucet_prometheus}" }}
                - {{ env "$${NOMAD_ADDR_replica_prometheus}" }}
        EOH

        destination = "$${NOMAD_TASK_DIR}/provisioning/prometheus.yml"
      }

      env {
        GF_PATHS_PROVISIONING = "$${NOMAD_TASK_DIR}/provisioning"
      }

      resources {
        memory = 64
        cpu = 64
      }
    }
  }
}