job "goshimmer" {
  datacenters = ["hcloud"]

  priority  = 90

  // TODO: Add distinct faucet, master, and replica tasks and monitoring group for grafana + prometheus
  // TODO: Run Nomad as root on clients to allow for iptables stuff
  group "testnet" {
    ephemeral_disk {
      migrate = true
      sticky = true
    }

    update {
      max_parallel      = 1
      health_check      = "task_states"
      min_healthy_time  = "15s"
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
        port "leader_prometheus" {}
        port "txstream" {}
        
        // Faucet
        port "faucet_api" {}
        port "faucet_autopeering" {}
        port "faucet_fpc" {}
        port "faucet_gossip" {}
        port "faucet_prometheus" {}
        port "faucet_txstream" {}
        
        // Replica
        port "replica_api" {}
        port "replica_autopeering" {}
        port "replica_fpc" {}
        port "replica_gossip" {}
        port "replica_prometheus" {}
        port "replica_txstream" {}
        
        // Grafana
        port "grafana" {
          to = "3000"
        }
        port "prometheus" {}
        
        // drand
        port "drand_leader" {}
        port "drand_client" {}
        port "drand_follower" {}
    }

    task "leader" {
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
            "leader_prometheus",
            "txstream",
        ]
        // command =  "/goshimmer"
        args  = [
            "--analysis.client.serverAddress=$${NOMAD_ADDR_analysis_api}",
            "--analysis.dashboard.bindAddress=0.0.0.0:$${NOMAD_PORT_analysis_dashboard}",
            "--analysis.server.bindAddress=0.0.0.0:$${NOMAD_PORT_analysis_api}",
            "--autopeering.port=$${NOMAD_PORT_autopeering}",
            "--dashboard.bindAddress=0.0.0.0:$${NOMAD_PORT_dashboard}",
            "--fpc.bindAddress=0.0.0.0:$${NOMAD_PORT_fpc}",
            "--gossip.port=$${NOMAD_PORT_gossip}",
            "--profiling.bindAddress=0.0.0.0:$${NOMAD_PORT_profiling}",
            "--prometheus.bindAddress=0.0.0.0:$${NOMAD_PORT_leader_prometheus}",
            "--txstream.bindAddress=0.0.0.0:$${NOMAD_PORT_txstream}",
            "--webapi.bindAddress=0.0.0.0:$${NOMAD_PORT_api}",
            "--autopeering.entryNodes=",
            "--config=$CONFIG_PATH",
            "--database.directory=$${DB_PATH}",
            "--mana.enableResearchVectors=false",
            "--mana.snapshotResetTime=true",
            "--messageLayer.snapshot.file=$${SNAPSHOT_PATH}",
            "--messageLayer.snapshot.genesisNode=",
            "--metrics.global=true",
            "--metrics.local=true",
            "--metrics.manaResearch=false",
            "--autopeering.seed=base58:8q491c3YWjbPwLmF2WD95YmCgh61j2kenCKHfGfByoWi",
            "--node.disablePlugins=clock,portcheck",
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
      
      artifact {
        source      = "https://github.com/iotaledger/goshimmer/raw/develop/tools/docker-network/config.docker.json"
        destination = "$${NOMAD_TASK_DIR}/config.json"
        mode        = "file"
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
          path     = "healthz"
          interval = "10s"
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
        tags = ["leader_prometheus"]

        port = "leader_prometheus"
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
        memory = 512
        cpu = 2500
      }
    }

    task "faucet" {
      driver = "docker"

      config {
        network_mode = "host"
        image = "${artifact.image}:${artifact.tag}"
        command =  "goshimmer"
        ports = [
            "faucet_api",
            "faucet_autopeering",
            "faucet_fpc",
            "faucet_gossip",
            "faucet_prometheus",
            "faucet_txstream",
        ]
        args  = [
            "--analysis.client.serverAddress=$${NOMAD_ADDR_analysis_api}",
            "--autopeering.port=$${NOMAD_PORT_faucet_autopeering}",
            "--fpc.bindAddress=0.0.0.0:$${NOMAD_PORT_faucet_fpc}",
            "--gossip.port=$${NOMAD_PORT_faucet_gossip}",
            "--prometheus.bindAddress=0.0.0.0:$${NOMAD_PORT_faucet_prometheus}",
            "--webapi.bindAddress=0.0.0.0:$${NOMAD_PORT_faucet_api}",
            "--txstream.bindAddress=0.0.0.0:$${NOMAD_PORT_faucet_txstream}",
            "--autopeering.entryNodes=EYsaGXnUVA9aTYL9FwYEvoQ8d1HCJveQVL7vogu6pqCP@$${NOMAD_ADDR_autopeering}",
            "--config=$CONFIG_PATH",
            "--database.directory=$${DB_PATH}",
            "--messageLayer.snapshot.file=$${SNAPSHOT_PATH}",
            "--messageLayer.startSynced=true",
            "--messageLayer.snapshot.genesisNode=",
            "--mana.snapshotResetTime=true",
            "--faucet.seed=7R1itJx5hVuo9w9hjg5cwKFmek4HMSoBDgJZN8hKGxih",
            "--autopeering.seed=base58:3YX6e7AL28hHihZewKdq6CMkEYVsTJBLgRiprUNiNq5E",
            "--node.disablePlugins=clock,portcheck",
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
      
      artifact {
        source      = "https://github.com/iotaledger/goshimmer/raw/develop/tools/docker-network/config.docker.json"
        destination = "$${NOMAD_TASK_DIR}/config.json"
        mode        = "file"
      }

      service {
        tags = ["api"]

        port = "faucet_api"

        check {
          type     = "http"
          port     = "faucet_api"
          path     = "healthz"
          interval = "10s"
          timeout  = "2s"
        }
      }

      service {
        tags = ["autopeering"]

        port = "faucet_autopeering"
      }

      service {
        tags = ["fpc"]

        port = "faucet_fpc"
      }

      service {
        tags = ["gossip"]

        port = "faucet_gossip"
      }

      service {
        tags = ["prometheus"]

        port = "faucet_prometheus"
      }
      
      service {
        tags = ["txstream"]

        port = "faucet_txstream"
      }

      env {
        DB_PATH = "$${NOMAD_TASK_DIR}/goshimmerdb"
        CONFIG_PATH = "$${NOMAD_TASK_DIR}/config.json"
        SNAPSHOT_PATH = "$${NOMAD_TASK_DIR}/snapshot.bin"
      }

      resources {
        memory = 512
        cpu = 2500
      }
    }

    task "replica" {
      driver = "docker"

      config {
        network_mode = "host"
        image = "${artifact.image}:${artifact.tag}"
        command =  "goshimmer"
        ports = [
            "replica_api",
            "replica_autopeering",
            "replica_fpc",
            "replica_gossip",
            "replica_prometheus",
            "replica_txstream",
        ]
        args  = [
            "--analysis.client.serverAddress=$${NOMAD_ADDR_analysis_api}",
            "--autopeering.port=$${NOMAD_PORT_replica_autopeering}",
            "--fpc.bindAddress=0.0.0.0:$${NOMAD_PORT_replica_fpc}",
            "--gossip.port=$${NOMAD_PORT_replica_gossip}",
            "--webapi.bindAddress=0.0.0.0:$${NOMAD_PORT_replica_api}",
            "--prometheus.bindAddress=0.0.0.0:$${NOMAD_PORT_replica_prometheus}",
            "--txstream.bindAddress=0.0.0.0:$${NOMAD_PORT_replica_txstream}",
            "--autopeering.entryNodes=EYsaGXnUVA9aTYL9FwYEvoQ8d1HCJveQVL7vogu6pqCP@$${NOMAD_ADDR_autopeering}",
            "--config=$CONFIG_PATH",
            "--database.directory=$${DB_PATH}",
            "--messageLayer.snapshot.file=$${SNAPSHOT_PATH}",
            "--messageLayer.snapshot.genesisNode=",
            "--mana.snapshotResetTime=true",
            "--node.disablePlugins=clock,portcheck",
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
      
      artifact {
        source      = "https://github.com/iotaledger/goshimmer/raw/develop/tools/docker-network/config.docker.json"
        destination = "$${NOMAD_TASK_DIR}/config.json"
        mode        = "file"
      }

      service {
        tags = ["api"]

        port = "replica_api"

        check {
          type     = "http"
          port     = "api"
          path     = "healthz"
          interval = "10s"
          timeout  = "2s"
        }
      }

      service {
        tags = ["autopeering"]

        port = "replica_autopeering"
      }

      service {
        tags = ["fpc"]

        port = "replica_fpc"
      }

      service {
        tags = ["gossip"]

        port = "replica_gossip"
      }

      service {
        tags = ["prometheus"]

        port = "replica_prometheus"
      }

      service {
        tags = ["txstream"]

        port = "replica_txstream"
      }

      env {
        DB_PATH = "$${NOMAD_ALLOC_DIR}/goshimmerdb"
        CONFIG_PATH = "$${NOMAD_TASK_DIR}/config.json"
        SNAPSHOT_PATH = "$${NOMAD_TASK_DIR}/snapshot.bin"
      }

      resources {
        memory = 512
        cpu = 2500
      }
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