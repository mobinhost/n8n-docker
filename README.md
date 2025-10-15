# n8n Docker Installer with Nginx & Let's Encrypt

[![Bash](https://img.shields.io/badge/Bash-Yes-green.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Yes-blue.svg)](https://www.docker.com/)

A **bash script** to automatically install or uninstall **n8n** using Docker with **Nginx reverse proxy** and **Let's Encrypt SSL**. Works even in restricted regions (like Iran) by temporarily modifying DNS during installation.

---

## Features

* Install **n8n** on Docker with persistent storage.
* Automatically install missing dependencies:

  * Docker
  * Docker Compose
  * Nginx
  * Certbot (Let's Encrypt)
* Configure **Nginx reverse proxy** with HTTPS.
* Apply temporary DNS for restricted Docker Hub access, then restore original DNS.
* Interactive input for **domain** and **email**.
* Supports **install** and **uninstall** modes.
* Correct permissions set automatically to avoid `EACCES` errors.

---

## Requirements

* Ubuntu/Debian-based Linux system (tested on Ubuntu 22.04 / Debian 12)
* Root privileges (`sudo`)
* Domain pointing to server IP (for Let's Encrypt)
* Open ports:

  * `80` (HTTP)
  * `443` (HTTPS)
  * `5678` (n8n container, internal)

---

## Quick Installation (from GitHub)

* Download installer from GitHub
```bash
mkdir -p /opt/n8n/
sudo curl -fsSL https://raw.githubusercontent.com/mobinhost/n8n-docker/main/n8n_docker_installer.sh -o /opt/n8n/n8n_docker_installer.sh
```

* Make it executable
```bash
sudo chmod +x /opt/n8n/n8n_docker_installer.sh
```

* Run installer
```bash
sudo /opt/n8n/n8n_docker_installer.sh
```

During installation, you will be prompted for:

* **n8n domain name** (e.g., `n8n.example.com`)
* **Email address** for Let's Encrypt SSL

The script will:

1. Install missing dependencies.
2. Apply temporary DNS to bypass Docker restrictions.
3. Set up `n8n` container with Docker.
4. Configure Nginx reverse proxy with HTTPS.
5. Obtain SSL certificate from Let's Encrypt.
6. Set correct permissions on persistent data directory (`/opt/n8n/data`) to avoid permission errors.

---

### Uninstallation

To completely remove n8n and all related files:

```bash
sudo /opt/n8n/n8n_docker_installer.sh uninstall
```

This will:

* Stop and remove the n8n container
* Remove `/opt/n8n` directory
* Remove Nginx configuration

---

## Directory Structure

After installation:

```
/opt/n8n/
├─ docker-compose.yml       # Docker Compose file for n8n
├─ data/                    # Persistent n8n data with proper permissions
```

* The `docker-compose.yml` is auto-generated.
* The `data/` folder stores all n8n workflows, credentials, and config.

---

## Notes

* Ensure your domain DNS is pointing to the server **before running** the script.
* The n8n container binds to `0.0.0.0:5678`, allowing Nginx to proxy HTTPS traffic.
* Default n8n credentials:

  * Username: `admin`
  * Password: `changeme`
* Change the password after first login.
* Temporary DNS changes are only applied during installation and are restored afterward.

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.
