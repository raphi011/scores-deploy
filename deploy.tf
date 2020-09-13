provider "docker" {
	version = "2.6.0"
}

resource "docker_network" "private_network" {
  name = "scores"
}

resource "docker_container" "api" {
	name = "api"
	image = "raphi011/scores-api:latest"
	restart = "always"
	command = [
      "-mode",
      "production",
      "-connection",
      "postgres://postgres:test@${docker_container.db.name}?sslmode=disable",
      "-provider",
      "postgres",
      "-backendurl",
      "https://scores.network"
	]

	log_driver = "loki"
	
	log_opts = {
	  "loki-url" = "http://localhost:3100/loki/api/v1/push"
	  "loki-external-labels" = "service=api"
	}

	networks_advanced {
	  name = "scores"
	}
}

resource "docker_container" "web" {
	name = "web"
	image = "raphi011/scores-web:latest"
	restart = "always"
	
	networks_advanced {
	  name = "scores"
	}
}

resource "docker_container" "edge" {
	name = "edge"
	image = "envoyproxy/envoy:v1.15.0"
	restart = "always"

	ports {
		internal = "80"
		external = "80"
	}

	ports {
		internal = "443"
		external = "443"
	}

	networks_advanced {
	  name = "scores"
	}
}

resource "docker_container" "db" {
	name = "db"
	image = "postgres:latest"
	restart = "always"

	volumes {
		volume_name = "scores-db-data"
		container_path = "/var/lib/postgresql/data"
	}

	networks_advanced {
	  name = "scores"
	}

	healthcheck {
      test = ["CMD-SHELL", "pg_isready -U postgres"]
      interval = "10s"
      timeout = "5s"
      retries = "5"
    #   start_period = "10s
	}
}

resource "docker_container" "grafana" {
	name = "grafana"
	image = "grafana/grafana:latest"

	networks_advanced {
	  name = "scores"
	}
}

resource "docker_container" "loki" {
	name = "loki"
	image = "grafana/loki:latest"

	networks_advanced {
	  name = "scores"
	}

	ports {
		ip = "127.0.0.1"
		internal = "3100"
		external = "3100"
	}
}
