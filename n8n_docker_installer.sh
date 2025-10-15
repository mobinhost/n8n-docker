#!/bin/bash
# ==========================================================
# n8n Docker Installer/Uninstaller with Nginx + Let's Encrypt
# ==========================================================

# --- Colors ---
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# --- Constants ---
TEMP_DNS1="87.107.110.109"
TEMP_DNS2="87.107.110.110"
INSTALL_DIR="/opt/n8n"
DATA_PATH="$INSTALL_DIR/data"
DOCKER_COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
NGINX_CONF="/etc/nginx/sites-available/n8n.conf"

# --- Root Check ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${RESET}"
  exit 1
fi

# --- Mode Check ---
if [[ "$1" == "uninstall" ]]; then
  echo -e "${YELLOW}Uninstalling n8n Docker setup...${RESET}"

  if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    cd "$INSTALL_DIR" && docker compose down
  fi

  rm -rf "$INSTALL_DIR"
  rm -f "$NGINX_CONF"
  rm -f "/etc/nginx/sites-enabled/n8n.conf"
  systemctl reload nginx >/dev/null 2>&1

  echo -e "${GREEN}n8n and related configuration removed successfully.${RESET}"
  exit 0
fi

# --- Interactive Input ---
echo -e "${BLUE}Enter your n8n domain name (e.g., n8n.example.com):${RESET}"
read -r N8N_DOMAIN
if [ -z "$N8N_DOMAIN" ]; then
  echo -e "${RED}Domain cannot be empty.${RESET}"
  exit 1
fi

echo -e "${BLUE}Enter your email address for Let's Encrypt:${RESET}"
read -r EMAIL
if [ -z "$EMAIL" ]; then
  echo -e "${RED}Email cannot be empty.${RESET}"
  exit 1
fi

# --- Save Current DNS ---
echo -e "${BLUE}Saving current DNS configuration...${RESET}"
cp /etc/resolv.conf /etc/resolv.conf.bak

# --- Apply temporary DNS ---
echo -e "${YELLOW}Applying temporary DNS to bypass Docker restrictions...${RESET}"
{
  echo "nameserver $TEMP_DNS1"
  echo "nameserver $TEMP_DNS2"
} > /etc/resolv.conf

restore_dns() {
  echo -e "${YELLOW}Restoring original DNS...${RESET}"
  if [ -f /etc/resolv.conf.bak ]; then
    mv /etc/resolv.conf.bak /etc/resolv.conf
  fi
}

# --- Install Docker ---
if ! command -v docker &> /dev/null; then
  echo -e "${BLUE}Installing Docker...${RESET}"
  curl -fsSL https://get.docker.com | bash
else
  echo -e "${GREEN}Docker already installed.${RESET}"
fi

systemctl enable docker >/dev/null 2>&1
systemctl start docker >/dev/null 2>&1

# --- Install Docker Compose ---
if ! command -v docker compose &> /dev/null; then
  echo -e "${BLUE}Installing Docker Compose plugin...${RESET}"
  apt-get update -y >/dev/null 2>&1
  apt-get install -y docker-compose-plugin >/dev/null 2>&1 || \
  apt-get install -y docker-compose >/dev/null 2>&1
else
  echo -e "${GREEN}Docker Compose already installed.${RESET}"
fi

# --- Install Nginx and Certbot ---
for pkg in nginx certbot python3-certbot-nginx; do
  if ! dpkg -l | grep -qw "$pkg"; then
    echo -e "${BLUE}Installing $pkg...${RESET}"
    apt-get install -y "$pkg" >/dev/null 2>&1
  else
    echo -e "${GREEN}$pkg already installed.${RESET}"
  fi
done

systemctl enable nginx >/dev/null 2>&1
systemctl start nginx >/dev/null 2>&1

# --- Restore DNS after installations ---
restore_dns

# --- Create directories and set permissions ---
mkdir -p "$DATA_PATH"
echo -e "${BLUE}Setting proper permissions for n8n data...${RESET}"
chown -R 1000:1000 "$DATA_PATH"
chmod -R 700 "$DATA_PATH"

# --- Create docker-compose.yml ---
echo -e "${BLUE}Creating docker-compose.yml...${RESET}"
cat > "$DOCKER_COMPOSE_FILE" <<EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme
      - N8N_PROTOCOL=http
      - N8N_PORT=5678
      - N8N_HOST=0.0.0.0
      - NODE_ENV=production
      - N8N_EDITOR_BASE_URL=https://$N8N_DOMAIN/
      - WEBHOOK_URL=https://$N8N_DOMAIN/
    volumes:
      - $DATA_PATH:/home/node/.n8n
EOF

# --- Start Docker container ---
echo -e "${BLUE}Starting n8n container...${RESET}"
docker compose up -d

sleep 5
if docker ps | grep -q "n8nio/n8n"; then
  echo -e "${GREEN}n8n container is running.${RESET}"
else
  echo -e "${RED}Failed to start n8n container. Check logs with:${RESET}"
  echo "docker compose logs -f"
  exit 1
fi

# --- Configure Nginx reverse proxy ---
echo -e "${BLUE}Configuring Nginx reverse proxy...${RESET}"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $N8N_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/n8n.conf
nginx -t && systemctl reload nginx

# --- Obtain SSL certificate ---
echo -e "${BLUE}Requesting Let's Encrypt SSL certificate...${RESET}"
certbot --nginx -d "$N8N_DOMAIN" --non-interactive --agree-tos -m "$EMAIL" >/dev/null 2>&1

if [ $? -eq 0 ]; then
  echo -e "${GREEN}SSL certificate installed successfully.${RESET}"
else
  echo -e "${RED}Let's Encrypt failed. Check your DNS or domain configuration.${RESET}"
fi

# --- Completion ---
echo -e "${GREEN}Installation complete!${RESET}"
echo "---------------------------------------------------"
echo -e "Access n8n at: ${BLUE}https://$N8N_DOMAIN${RESET}"
echo -e "Username: ${YELLOW}admin${RESET}"
echo -e "Password: ${YELLOW}changeme${RESET}"
echo "To uninstall, run: sudo ./n8n_docker_installer.sh uninstall"
echo "---------------------------------------------------"
