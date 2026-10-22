*This project has been created as part of the 42 curriculum by jlabrous.*

# Inception

## Description
This system administration project builds a small WordPress infrastructure inside a dedicated Linux virtual machine using Docker Compose. It implements the mandatory part of the Inception subject, version 5.3; no bonus services are included.

NGINX is the only external entry point, publishing port 443 with TLS 1.2/1.3. It forwards PHP requests to WordPress/PHP-FPM on port 9000. WordPress connects to MariaDB on port 3306 through an explicit Docker bridge network. Each service has its own Dockerfile and container. All images are built from `debian:12-slim`, without prebuilt application images or the `latest` tag.

```text
Browser -> 443/TLS -> NGINX -> 9000/FastCGI -> WordPress/PHP-FPM -> 3306/SQL -> MariaDB
                      |                           |                           |
                      +-- wordpress_data (ro) ----+                     mariadb_data
```

## Instructions
Use a dedicated Linux VM with Docker Engine, Docker Compose v2 supporting `up --wait`, Make, Python 3, curl and OpenSSL. Commands run at the repository root:

```sh
make setup
# Edit srcs/.env: use your real 42 login, LOGIN.42.fr and /home/LOGIN/data.
# Configure Docker's data-root on the VM as explained in DEV_DOC.md.
# Add VM_IP LOGIN.42.fr to the client computer's hosts file.
make config
make build
make up
make test
```

The sample login `jlabrous` must be confirmed or replaced before evaluation, including in this README's first line. `make setup` creates random local secrets without replacing existing values. No secret is committed. Open `https://LOGIN.42.fr` for the site and `/wp-admin/` for administration. The self-signed certificate requires explicit trust in the test environment.

`make stop` and `make start` stop and resume containers. `make down` removes containers and the network while preserving volumes. `make logs` and `make ps` report service logs and health. The integration test temporarily stops and recreates the stack to verify persistence.

See [USER_DOC.md](USER_DOC.md) for operation, [DEV_DOC.md](DEV_DOC.md) for VM provisioning, backup and development, and [VALIDATION.md](VALIDATION.md) for checks and remaining limitations.

## Project description and design choices
- **Virtual machines vs Docker:** the required VM provides an isolated Linux kernel and host environment. Containers isolate processes while sharing that kernel; they are not virtual machines.
- **Secrets vs environment variables:** `srcs/.env` holds non-sensitive settings. Compose mounts passwords as files under `/run/secrets`, granting access only to services that need them. Local secret files are not an encrypted vault and require private backups.
- **Docker network vs host network:** an explicit bridge provides service-name DNS and isolated internal ports. Host networking would share the host's network namespace and is not used.
- **Docker volumes vs bind mounts:** native named volumes are managed by Docker. Bind mounts map arbitrary host directories into containers and are prohibited for the two persistent stores. No volume `driver_opts` are used. Docker Engine's `data-root` is configured to `/home/LOGIN/data` on the dedicated VM, placing the volume contents under `/home/LOGIN/data/volumes/{mariadb_data,wordpress_data}/_data`.

Build sources are under `srcs/requirements`: NGINX configuration and TLS generation, PHP-FPM configuration and WordPress installation, MariaDB configuration and database initialization. Shared setup/preflight tools are under `srcs/tools` and integration tests under `srcs/tests`. Secrets remain in the ignored root `secrets/` directory, following the subject's example.

Debian 12 is the previous stable major release as of this audit (Debian 13 is stable). Debian packages provide NGINX, MariaDB and PHP 8.2. WordPress 7.1.3 and WP-CLI 2.12.0 are explicitly versioned; WordPress files are checked against official checksums. Debian package versions follow security updates at rebuild time, so builds are not byte-for-byte reproducible.

Entrypoints preserve existing databases and `wp-config.php`, use bounded startup waits, and finish with `exec` so the real service becomes PID 1. MariaDB grants WordPress a dedicated SQL account; WordPress receives no root database secret. The WordPress owner login cannot contain “admin”, and a separate subscriber account is created.

## Resources
- [Docker Compose services](https://docs.docker.com/reference/compose-file/services/)
- [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker daemon configuration and data-root](https://docs.docker.com/engine/daemon/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Debian releases](https://www.debian.org/releases/)
- [NGINX HTTPS configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [WP-CLI installation command](https://developer.wordpress.org/cli/commands/core/install/)
- [WordPress release archive](https://en-gb.wordpress.org/download/releases/)
- [MariaDB database initialization](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db)

**AI use:** Codex was used to audit the initially empty repository, implement Dockerfiles, Compose, configuration, entrypoints, setup tools, tests and documentation, and perform static checks. After the exact subject PDF was provided, Codex compared it with the repository and corrected storage and documentation requirements. The learner must understand every file and verify the stack on their VM. Build and runtime validation remain pending because this session cannot access the Docker daemon; this is documented explicitly rather than reported as a passing test.
