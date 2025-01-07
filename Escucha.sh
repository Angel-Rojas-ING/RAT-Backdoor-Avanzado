#!/bin/bash

# Variables globales
DEFAULT_PORT=8080
FIREWALLS=("ufw" "firewalld" "iptables")
NC_COMMAND="nc"

# Función para instalar un paquete según la distribución
install_package() {
    local package="$1"
    if [[ -f /etc/debian_version ]]; then
        sudo apt update && sudo apt install -y "$package" || return 1
    elif [[ -f /etc/redhat-release ]]; then
        sudo dnf install -y "$package" || sudo yum install -y "$package" || return 1
    elif [[ -f /etc/arch-release ]]; then
        sudo pacman -Sy --noconfirm "$package" || return 1
    else
        printf "Error: No se reconoce la distribución.\n" >&2
        return 1
    fi
}

# Función para detectar el firewall disponible
detect_firewall() {
    for firewall in "${FIREWALLS[@]}"; do
        if command -v "$firewall" &>/dev/null; then
            printf "%s\n" "$firewall"
            return 0
        fi
    done
    printf "No se detectó ningún firewall, se intentará instalar.\n" >&2
    return 1
}

# Función para configurar y abrir el puerto
configure_firewall() {
    local firewall="$1"
    local port="$2"

    case "$firewall" in
        ufw)
            sudo ufw allow "$port/tcp" || return 1
            sudo ufw enable || return 1
            ;;
        firewalld)
            sudo firewall-cmd --permanent --add-port="$port/tcp" || return 1
            sudo firewall-cmd --reload || return 1
            ;;
        iptables)
            sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT || return 1
            sudo iptables-save > /etc/iptables/rules.v4 || return 1
            ;;
        *)
            printf "Error: Firewall no reconocido.\n" >&2
            return 1
            ;;
    esac
}

# Función para instalar netcat si no está disponible
install_netcat() {
    if ! command -v "$NC_COMMAND" &>/dev/null; then
        printf "Netcat no encontrado. Instalando...\n"
        install_package "$NC_COMMAND" || return 1
    fi
}

# Función para escuchar peticiones en el puerto
listen_on_port() {
    local port="$1"
    printf "Escuchando en el puerto %s...\n" "$port"
    "$NC_COMMAND" -l -p "$port"
}

# Función principal
main() {
    local port firewall
    printf "Ingrese el puerto a abrir (predeterminado: %s): " "$DEFAULT_PORT"
    read -r port
    port=${port:-$DEFAULT_PORT}

    # Detectar o instalar firewall
    if ! firewall=$(detect_firewall); then
        install_package "ufw" && firewall="ufw"
    fi

    if [[ -z "$firewall" ]]; then
        printf "Error: No se pudo instalar ni detectar un firewall.\n" >&2
        exit 1
    fi
    printf "Firewall detectado: %s\n" "$firewall"

    # Configurar el puerto en el firewall
    if ! configure_firewall "$firewall" "$port"; then
        printf "Error: No se pudo configurar el firewall.\n" >&2
        exit 1
    fi

    # Instalar netcat si es necesario
    if ! install_netcat; then
        printf "Error: No se pudo instalar Netcat.\n" >&2
        exit 1
    fi

    # Escuchar en el puerto
    listen_on_port "$port"
}

main "$@"
