#!/bin/bash

# Variables globales
DEBIAN_PKG="ufw"
RHT_PKG="firewalld"
ARCH_PKG="ufw"
NC_PKG="netcat"
DEFAULT_PORT=8080

# Función para detectar la distribución del sistema
detect_distro() {
    local os_info
    if ! os_info=$(cat /etc/os-release 2>/dev/null); then
        printf "Error: No se puede determinar la distribución del sistema.\n" >&2
        return 1
    fi

    if [[ $os_info =~ ID_LIKE=debian ]] || [[ $os_info =~ ID=debian ]]; then
        printf "debian\n"
    elif [[ $os_info =~ ID_LIKE=fedora ]] || [[ $os_info =~ ID=rhel ]]; then
        printf "rht\n"
    elif [[ $os_info =~ ID=arch ]]; then
        printf "arch\n"
    else
        printf "Error: Distribución no soportada.\n" >&2
        return 1
    fi
}

# Función para instalar un paquete
install_package() {
    local distro="$1"
    local package="$2"

    case "$distro" in
        debian)
            if ! dpkg -l | grep -qw "$package"; then
                sudo apt update && sudo apt install -y "$package" || return 1
            fi
            ;;
        rht)
            if ! rpm -q "$package" &>/dev/null; then
                sudo dnf install -y "$package" || return 1
            fi
            ;;
        arch)
            if ! pacman -Qi "$package" &>/dev/null; then
                sudo pacman -Sy --noconfirm "$package" || return 1
            fi
            ;;
        *)
            printf "Error: Distribución desconocida.\n" >&2
            return 1
            ;;
    esac
}

# Función para configurar y abrir el puerto en el firewall
configure_firewall() {
    local distro="$1"
    local port="$2"

    case "$distro" in
        debian|arch)
            sudo ufw allow "$port/tcp" || return 1
            sudo ufw enable || return 1
            ;;
        rht)
            sudo firewall-cmd --permanent --add-port="$port/tcp" || return 1
            sudo firewall-cmd --reload || return 1
            ;;
        *)
            printf "Error: Distribución desconocida.\n" >&2
            return 1
            ;;
    esac
}

# Función para escuchar peticiones en el puerto
listen_on_port() {
    local port="$1"
    printf "Escuchando en el puerto %s...\n" "$port"
    nc -l -p "$port"
}

# Función principal
main() {
    local distro port
    distro=$(detect_distro) || exit 1
    printf "Sistema detectado: %s\n" "$distro"

    # Instalar firewall
    if [[ $distro == "debian" || $distro == "arch" ]]; then
        install_package "$distro" "$DEBIAN_PKG" || exit 1
    elif [[ $distro == "rht" ]]; then
        install_package "$distro" "$RHT_PKG" || exit 1
    fi

    # Instalar netcat
    install_package "$distro" "$NC_PKG" || exit 1

    # Configurar el puerto
    printf "Ingrese el puerto a abrir (predeterminado: %s): " "$DEFAULT_PORT"
    read -r port
    port=${port:-$DEFAULT_PORT}

    if ! configure_firewall "$distro" "$port"; then
        printf "Error: No se pudo configurar el firewall.\n" >&2
        exit 1
    fi

    # Escuchar en el puerto
    listen_on_port "$port"
}

main "$@"
