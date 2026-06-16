#!/usr/bin/env bash

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
M='\033[0;35m'
W='\033[1;37m'
DIM='\033[2m'
BLINK='\033[5m'
NC='\033[0m'
BOLD='\033[1m'
ULINE='\033[4m'

TARGET=""
PORT_RANGE="1-1024"
SCAN_MODE="tcp"
TIMEOUT=1
THREADS=100
OUTPUT_FILE=""
PAUSED=0
STOPPED=0
VERBOSE=0
BANNER_GRAB=1
OS_DETECT=0
SCAN_PID=""
CURRENT_PORT=0
OPEN_PORTS=()
FILTERED_PORTS=()
CLOSED_COUNT=0
START_TIME=0
declare -A SERVICE_MAP

trap handle_interrupt INT

handle_interrupt() {
    echo ""
    echo -e "\n${Y}[!] Ctrl+C detected — pausing scan...${NC}"
    PAUSED=1
    pause_menu
}

trap cleanup EXIT

cleanup() {
    tput cnorm 2>/dev/null
    echo -e "\n${DIM}[~] SEE THAT session ended.${NC}"
}

print_logo() {
    clear
    echo -e "${C}"
    cat << 'LOGO'

 __    __  __   _____        _   _____ 
/ _\  /__\/__\ /__   \/\  /\/_\ /__   \
\ \  /_\ /_\     / /\/ /_/ //_\\  / /\/
_\ \//__//__    / / / __  /  _  \/ /   
\__/\__/\__/    \/  \/ /_/\_/ \_/\/    
                                       
LOGO
    echo -e "${B}"
    cat << 'WAVE'
  ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋
   Advanced Port Scanner  | S E E  T H A T |  v1.0
  ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋
   Author: SYED SAMEER UL HASSAN  |  License: Apache 2.0

WAVE
    echo -e "${NC}"
}

load_service_map() {
    SERVICE_MAP=(
        [20]="FTP-DATA"     [21]="FTP"          [22]="SSH"
        [23]="Telnet"       [25]="SMTP"          [53]="DNS"
        [67]="DHCP"         [68]="DHCP-Client"   [69]="TFTP"
        [80]="HTTP"         [88]="Kerberos"       [110]="POP3"
        [111]="RPC"         [119]="NNTP"          [123]="NTP"
        [135]="MS-RPC"      [137]="NetBIOS-NS"    [138]="NetBIOS-DGM"
        [139]="NetBIOS-SSN" [143]="IMAP"          [161]="SNMP"
        [162]="SNMP-Trap"   [179]="BGP"           [194]="IRC"
        [389]="LDAP"        [443]="HTTPS"          [445]="SMB"
        [465]="SMTPS"       [500]="IKE"            [514]="Syslog"
        [515]="LPD"         [587]="SMTP-Sub"       [631]="IPP"
        [636]="LDAPS"       [873]="Rsync"          [993]="IMAPS"
        [995]="POP3S"       [1080]="SOCKS5"        [1194]="OpenVPN"
        [1433]="MSSQL"      [1521]="Oracle-DB"     [1723]="PPTP"
        [2049]="NFS"        [2082]="cPanel-HTTP"   [2083]="cPanel-HTTPS"
        [2181]="Zookeeper"  [2375]="Docker"        [2376]="Docker-TLS"
        [3000]="Grafana"    [3306]="MySQL"          [3389]="RDP"
        [4444]="MSF-4444"   [4848]="GlassFish"     [5000]="Flask/UPnP"
        [5432]="PostgreSQL" [5601]="Kibana"         [5672]="RabbitMQ"
        [5900]="VNC"        [5984]="CouchDB"        [6379]="Redis"
        [6443]="Kubernetes" [7001]="WebLogic"       [7474]="Neo4j"
        [8080]="HTTP-Alt"   [8443]="HTTPS-Alt"      [8888]="Jupyter"
        [9000]="PHP-FPM"    [9042]="Cassandra"      [9090]="Prometheus"
        [9200]="Elasticsearch" [9300]="ES-Cluster"  [10250]="Kubelet"
        [11211]="Memcached" [15672]="RabbitMQ-UI"   [27017]="MongoDB"
        [27018]="MongoDB-Shard" [50000]="SAP"       [50070]="Hadoop-HDFS"
    )
}

usage() {
    print_logo
    echo -e "${W}USAGE:${NC}"
    echo -e "  ${G}./seethat.sh${NC} [OPTIONS]\n"
    echo -e "${W}OPTIONS:${NC}"
    echo -e "  ${C}-t  <target>${NC}     IP address or hostname to scan"
    echo -e "  ${C}-p  <range>${NC}      Port range (default: 1-1024)"
    echo -e "                 Examples: 80, 22-443, 1-65535, top100"
    echo -e "  ${C}-m  <mode>${NC}       Scan mode:"
    echo -e "                   ${Y}tcp${NC}      — TCP connect scan (default)"
    echo -e "                   ${Y}udp${NC}      — UDP scan (requires root)"
    echo -e "                   ${Y}both${NC}     — TCP + UDP"
    echo -e "                   ${Y}service${NC}  — TCP + banner grab + service ID"
    echo -e "                   ${Y}stealth${NC}  — SYN scan (requires root / nmap)"
    echo -e "  ${C}-T  <1-5>${NC}        Timing/threads (1=slow,5=fast, default:3)"
    echo -e "  ${C}-o  <file>${NC}       Save results to file (.txt or .json)"
    echo -e "  ${C}-v${NC}              Verbose mode (show closed ports too)"
    echo -e "  ${C}-n${NC}              No-stop mode (ignore Ctrl+C, run to end)"
    echo -e "  ${C}-h${NC}              Show this help\n"
    echo -e "${W}CONTROLS (during scan):${NC}"
    echo -e "  ${Y}Ctrl+C${NC}  → Pause and open selection menu (wifite2-style)"
    echo -e "  ${Y}[s]${NC}     → Stop scan gracefully and show results"
    echo -e "  ${Y}[r]${NC}     → Resume scan"
    echo -e "  ${Y}[q]${NC}     → Quit immediately\n"
    echo -e "${W}EXAMPLES:${NC}"
    echo -e "  ${DIM}./seethat.sh -t 192.168.1.1 -p 1-65535 -m service -T 4 -o results.txt"
    echo -e "  ./seethat.sh -t scanme.nmap.org -p top100 -m stealth"
    echo -e "  ./seethat.sh -t 10.0.0.1 -p 1-1024 -m both -v -n${NC}\n"
    echo -e "${C}≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋${NC}"
}

TOP100_PORTS=(21 22 23 25 53 67 68 69 80 88 110 111 119 123 135 137
              138 139 143 161 162 179 194 389 443 445 465 500 514 515
              587 631 636 873 993 995 1080 1194 1433 1521 1723 2049
              2082 2083 2181 2375 2376 3000 3306 3389 4444 4848 5000
              5432 5601 5672 5900 5984 6379 6443 7001 7474 8080 8443
              8888 9000 9042 9090 9200 9300 10250 11211 15672 27017
              27018 50000 50070 80 443 8080 8443 3000 4000 5000 8000
              8888 9000 9090 9200 6379 27017 5432 3306 1433 5900)

draw_progress() {
    local current=$1
    local total=$2
    local width=40
    local pct=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    local elapsed=$(( $(date +%s) - START_TIME ))
    local rate=0
    [[ $elapsed -gt 0 ]] && rate=$(( current / elapsed ))
    local bar="${G}"
    for (( i=0; i<filled; i++ )); do bar+="✅"; done
    bar+="${DIM}"
    for (( i=0; i<empty; i++ )); do bar+="░"; done
    bar+="${NC}"
    printf "\r  ${C}[${NC}%s${C}]${NC} ${W}%3d%%${NC}  ${DIM}Port: %-6d  Open: %-4d  Rate: %d/s  Elapsed: %ds${NC}" \
        "$bar" "$pct" "$current" "${#OPEN_PORTS[@]}" "$rate" "$elapsed"
}

grab_banner() {
    local host=$1
    local port=$2
    local banner=""
    banner=$(echo -e "HEAD / HTTP/1.0\r\n\r\n" | timeout 2 nc -w 2 "$host" "$port" 2>/dev/null | head -3 | tr -d '\r\n' | cut -c1-60)
    if [[ -z "$banner" ]]; then
        banner=$(timeout 2 nc -w 2 "$host" "$port" 2>/dev/null | head -1 | tr -d '\r\n' | cut -c1-60)
    fi
    echo "$banner"
}

port_label() {
    local port=$1
    echo "${SERVICE_MAP[$port]:-unknown}"
}

scan_tcp_port() {
    local host=$1
    local port=$2
    ( exec 3<>/dev/tcp/"$host"/"$port" ) 2>/dev/null
    return $?
}

scan_udp_port() {
    local host=$1
    local port=$2
    nc -zu -w "$TIMEOUT" "$host" "$port" 2>/dev/null
    return $?
}

print_open_port() {
    local port=$1
    local proto=$2
    local service
    service=$(port_label "$port")
    local banner=""
    if [[ "$SCAN_MODE" == "service" && "$BANNER_GRAB" -eq 1 ]]; then
        banner=$(grab_banner "$TARGET" "$port")
        [[ -n "$banner" ]] && banner="${DIM}  ↳ ${banner}${NC}"
    fi
    printf "\n  ${G}[OPEN]${NC}  %-6s  %-6s  ${W}%-16s${NC}%s\n" \
        "$port" "$proto" "$service" "$banner"
}

pause_menu() {
    echo ""
    echo -e "${C}╔══════════════════════════════════════╗${NC}"
    echo -e "${C}║${NC}   ${W}SEE THAT — Scan Paused${NC}              ${C}║${NC}"
    echo -e "${C}╠══════════════════════════════════════╣${NC}"
    echo -e "${C}║${NC}  ${G}[r]${NC}  Resume scan                     ${C}║${NC}"
    echo -e "${C}║${NC}  ${Y}[s]${NC}  Stop and show results            ${C}║${NC}"
    echo -e "${C}║${NC}  ${R}[q]${NC}  Quit immediately                 ${C}║${NC}"
    echo -e "${C}╚══════════════════════════════════════╝${NC}"
    echo -ne "  ${W}Choice:${NC} "
    local choice
    read -r -t 30 choice
    case "${choice,,}" in
        r) PAUSED=0; echo -e "  ${G}[+] Resuming scan...${NC}" ;;
        s) STOPPED=1; PAUSED=0; echo -e "  ${Y}[*] Stopping scan...${NC}" ;;
        q) echo -e "  ${R}[!] Quitting.${NC}"; exit 0 ;;
        *) PAUSED=0; echo -e "  ${G}[+] Resuming by default...${NC}" ;;
    esac
}

run_stealth_scan() {
    if ! command -v nmap &>/dev/null; then
        echo -e "${R}[!] Stealth mode requires nmap. Install it first.${NC}"
        exit 1
    fi
    if [[ $EUID -ne 0 ]]; then
        echo -e "${R}[!] SYN stealth scan requires root. Run with sudo.${NC}"
        exit 1
    fi
    echo -e "\n${M}[*] Stealth SYN scan via nmap...${NC}\n"
    nmap -sS -T4 -p "$PORT_RANGE" --open -oG - "$TARGET" 2>/dev/null \
    | grep "Ports:" \
    | grep -oP '\d+/open/tcp//\S*' \
    | while IFS='/' read -r port _ _ _ service _; do
        SERVICE_MAP[$port]="${service:-unknown}"
        OPEN_PORTS+=("$port")
        printf "  ${G}[OPEN]${NC}  %-6s  tcp    ${W}%s${NC}\n" "$port" "${service:-unknown}"
    done
}

run_scan() {
    local ports=()
    if [[ "$PORT_RANGE" == "top100" ]]; then
        ports=("${TOP100_PORTS[@]}")
    else
        if [[ "$PORT_RANGE" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            for (( p=start; p<=end; p++ )); do ports+=("$p"); done
        elif [[ "$PORT_RANGE" =~ ^[0-9]+$ ]]; then
            ports=("$PORT_RANGE")
        else
            echo -e "${R}[!] Invalid port range: $PORT_RANGE${NC}"
            exit 1
        fi
    fi

    local total=${#ports[@]}
    local count=0
    START_TIME=$(date +%s)

    echo ""
    echo -e "${C}  ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋${NC}"
    echo -e "  ${W}Target  :${NC} ${G}$TARGET${NC}"
    echo -e "  ${W}Ports   :${NC} $PORT_RANGE  (${total} ports)"
    echo -e "  ${W}Mode    :${NC} $SCAN_MODE"
    echo -e "  ${W}Timeout :${NC} ${TIMEOUT}s"
    echo -e "${C}  ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋${NC}"
    echo ""

    if [[ "$SCAN_MODE" == "stealth" ]]; then
        run_stealth_scan
        return
    fi

    local active_jobs=0
    for port in "${ports[@]}"; do
        while [[ $PAUSED -eq 1 ]]; do sleep 0.2; done
        [[ $STOPPED -eq 1 ]] && break
        CURRENT_PORT=$port
        (( count++ ))

        if [[ "$SCAN_MODE" == "tcp" || "$SCAN_MODE" == "service" || "$SCAN_MODE" == "both" ]]; then
            (
                if scan_tcp_port "$TARGET" "$port"; then
                    print_open_port "$port" "TCP"
                else
                    if [[ $VERBOSE -eq 1 ]]; then
                        printf "\r  ${DIM}[closed] %-6s TCP${NC}" "$port"
                    fi
                fi
            ) &
        fi

        if [[ "$SCAN_MODE" == "udp" || "$SCAN_MODE" == "both" ]]; then
            (
                if scan_udp_port "$TARGET" "$port"; then
                    printf "\n  ${Y}[OPEN?]${NC}  %-6s  UDP    ${W}%s${NC}\n" \
                        "$port" "$(port_label "$port")"
                fi
            ) &
        fi

        (( active_jobs++ ))
        if (( active_jobs >= THREADS )); then
            wait
            active_jobs=0
        fi
        draw_progress "$count" "$total"
    done
    wait
    echo ""
}

collect_open_ports() {
    local ports=()
    if [[ "$PORT_RANGE" == "top100" ]]; then
        ports=("${TOP100_PORTS[@]}")
    elif [[ "$PORT_RANGE" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        for (( p=BASH_REMATCH[1]; p<=BASH_REMATCH[2]; p++ )); do ports+=("$p"); done
    else
        ports=("$PORT_RANGE")
    fi
    for port in "${ports[@]}"; do
        if scan_tcp_port "$TARGET" "$port" 2>/dev/null; then
            OPEN_PORTS+=("$port")
        fi
    done
}

print_summary() {
    local elapsed=$(( $(date +%s) - START_TIME ))
    echo ""
    echo -e "${C}"
    cat << 'WAVE2'
  ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋
   ~ ~ ~   S C A N   R E S U L T S   ~ ~ ~
  ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋
WAVE2
    echo -e "${NC}"
    echo -e "  ${W}Host        :${NC} ${G}$TARGET${NC}"
    echo -e "  ${W}Scan Mode   :${NC} $SCAN_MODE"
    echo -e "  ${W}Time Taken  :${NC} ${elapsed}s"
    echo -e "  ${W}Open Ports  :${NC} ${G}${#OPEN_PORTS[@]}${NC} found\n"

    if [[ ${#OPEN_PORTS[@]} -gt 0 ]]; then
        echo -e "  ${ULINE}PORT    PROTO   SERVICE                  STATE${NC}"
        for port in "${OPEN_PORTS[@]}"; do
            local svc
            svc=$(port_label "$port")
            printf "  ${G}%-7s${NC} %-7s ${W}%-24s${NC} ${G}OPEN${NC}\n" "$port" "TCP" "$svc"
        done
    else
        echo -e "  ${Y}No open ports found in the scanned range.${NC}"
    fi

    if [[ -n "$OUTPUT_FILE" ]]; then
        save_results
    fi

    echo ""
    echo -e "${C}  ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋${NC}"
}

save_results() {
    local ext="${OUTPUT_FILE##*.}"
    if [[ "$ext" == "json" ]]; then
        {
            echo "{"
            echo "  \"target\": \"$TARGET\","
            echo "  \"scan_mode\": \"$SCAN_MODE\","
            echo "  \"port_range\": \"$PORT_RANGE\","
            echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
            echo "  \"open_ports\": ["
            local first=1
            for port in "${OPEN_PORTS[@]}"; do
                [[ $first -eq 0 ]] && echo ","
                echo -n "    {\"port\": $port, \"service\": \"$(port_label "$port")\"}"
                first=0
            done
            echo ""
            echo "  ]"
            echo "}"
        } > "$OUTPUT_FILE"
    else
        {
            echo "SEE THAT Results — $(date)"
            echo "Target: $TARGET | Mode: $SCAN_MODE | Range: $PORT_RANGE"
            echo "-----------------------------------------------"
            for port in "${OPEN_PORTS[@]}"; do
                echo "$port/tcp  OPEN  $(port_label "$port")"
            done
        } > "$OUTPUT_FILE"
    fi
    echo -e "\n  ${G}[+] Results saved to:${NC} ${W}$OUTPUT_FILE${NC}"
}

parse_args() {
    local NO_STOP=0
    while getopts ":t:p:m:T:o:vnh" opt; do
        case $opt in
            t) TARGET="$OPTARG" ;;
            p) PORT_RANGE="$OPTARG" ;;
            m) SCAN_MODE="$OPTARG" ;;
            T)
                case "$OPTARG" in
                    1) THREADS=10;  TIMEOUT=3 ;;
                    2) THREADS=50;  TIMEOUT=2 ;;
                    3) THREADS=100; TIMEOUT=1 ;;
                    4) THREADS=200; TIMEOUT=1 ;;
                    5) THREADS=500; TIMEOUT=1 ;;
                    *) echo -e "${R}[!] Timing must be 1-5${NC}"; exit 1 ;;
                esac
                ;;
            o) OUTPUT_FILE="$OPTARG" ;;
            v) VERBOSE=1 ;;
            n) NO_STOP=1 ;;
            h) usage; exit 0 ;;
            :) echo -e "${R}[!] Option -$OPTARG requires an argument.${NC}"; exit 1 ;;
            ?) echo -e "${R}[!] Unknown option -$OPTARG${NC}"; usage; exit 1 ;;
        esac
    done
    if [[ $NO_STOP -eq 1 ]]; then
        trap '' INT
        echo -e "${Y}[!] No-stop mode active — Ctrl+C is disabled.${NC}"
    fi
}

validate() {
    if [[ -z "$TARGET" ]]; then
        echo -e "${R}[!] No target specified. Use -t <ip/host>${NC}\n"
        usage
        exit 1
    fi
    local valid_modes=("tcp" "udp" "both" "service" "stealth")
    local ok=0
    for m in "${valid_modes[@]}"; do [[ "$m" == "$SCAN_MODE" ]] && ok=1; done
    if [[ $ok -eq 0 ]]; then
        echo -e "${R}[!] Invalid mode '$SCAN_MODE'. Choose: tcp|udp|both|service|stealth${NC}"
        exit 1
    fi
    if [[ "$SCAN_MODE" == "udp" || "$SCAN_MODE" == "both" ]] && [[ $EUID -ne 0 ]]; then
        echo -e "${Y}[!] UDP scanning works best as root. Some results may be inaccurate.${NC}"
    fi
    if ! ping -c1 -W1 "$TARGET" &>/dev/null 2>&1; then
        echo -e "${Y}[!] Warning: host may be unreachable or blocking ICMP. Proceeding anyway...${NC}"
    fi
}

main() {
    tput civis 2>/dev/null
    print_logo
    load_service_map
    parse_args "$@"
    validate
    echo -e "${C}  ~ See That — scanning now ~${NC}"
    echo -e "  ${DIM}[Ctrl+C to pause | -n flag to disable]${NC}\n"
    run_scan
    print_summary
    tput cnorm 2>/dev/null
}

main "$@"
