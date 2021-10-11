# The name of your project. A project typically maps 1:1 to a VCS repository.
# This name must be unique for your Waypoint server. If you're running in
# local mode, this must be unique to your machine.
project = "goshimmer"

# Labels can be specified for organizational purposes.
labels = { "team" = "iscp" }

variable "ghcr" {
    type = object({
        username = string
        password = string
        server_address = string
    })
}

# An application to deploy.
app "testnet" {
    # Build specifies how an application should be deployed. In this case,
    # we'll build using a Dockerfile and keeping it in a local registry.
    build {
        use "docker" {
            disable_entrypoint = true
            buildkit   = true
            build_args = {
                IMAGE_TAG = "1.17-buster"
                BUILD_TAGS = "rocksdb,builtin_static"
                DOWNLOAD_SNAPSHOT = 0
            }
        }

        registry {
            use "docker" {
                image = "ghcr.io/luke-thorne/goshimmer"
                tag = gitrefpretty()
                encoded_auth = base64encode(jsonencode(var.ghcr))
            }
        }
    }

    # Deploy to Nomad
    deploy {
        use "nomad-jobspec" {
            // Templated to perhaps bring in the artifact from a previous
            // build/registry, entrypoint env vars, etc.
            jobspec = templatefile("${path.app}/goshimmer.nomad.tpl", { 
                artifact = artifact
                gitrefhash = gitrefhash()
                auth = var.ghcr
            })
        }
    }
}
