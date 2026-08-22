#!/usr/bin/with-contenv bashio

set -u

APP_VERSION="${APP_VERSION:-unknown}"

CUPS_HOST="$(bashio::config 'cups_host')"
CUPS_PORT="$(bashio::config 'cups_port')"
SIMPLE_QUEUE="$(bashio::config 'simplex_queue')"
DUPLEX_QUEUE="$(bashio::config 'duplex_queue')"
COPIES_DEFAULT="$(bashio::config 'copies_default')"
PRINT_MODE_DEFAULT="$(bashio::config 'print_mode_default')"
COLLATE="$(bashio::config 'collate')"

CUPS_SERVER="${CUPS_HOST}:${CUPS_PORT}"

BASE_DIR="/share/scanprint"
SIMPLE_DIR="$BASE_DIR/simple"
DUPLEX_DIR="$BASE_DIR/duplex"
MULTICOPY_DIR="$BASE_DIR/multicopy"
FAILED_DIR="$BASE_DIR/failed"

STATE_FILE="/data/scanprint-state"

MQTT_HOST="$(bashio::services mqtt "host")"
MQTT_PORT="$(bashio::services mqtt "port")"
MQTT_USER="$(bashio::services mqtt "username")"
MQTT_PASSWORD="$(bashio::services mqtt "password")"

MQTT_BASE="scanprint"
MQTT_DISCOVERY="homeassistant"

COPIES="$COPIES_DEFAULT"
PRINT_MODE="$PRINT_MODE_DEFAULT"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_ok() {
    log "OK: $*"
}

log_warn() {
    log "WARNUNG: $*"
}

log_error() {
    log "FEHLER: $*"
}

mqtt_pub() {
    mosquitto_pub \
        -h "$MQTT_HOST" \
        -p "$MQTT_PORT" \
        -u "$MQTT_USER" \
        -P "$MQTT_PASSWORD" \
        "$@"
}

create_directories() {
    mkdir -p \
        "$SIMPLE_DIR" \
        "$DUPLEX_DIR" \
        "$MULTICOPY_DIR" \
        "$FAILED_DIR"
}

load_state() {
    if [ ! -f "$STATE_FILE" ]; then
        log "Kein gespeicherter Laufzeitzustand vorhanden"
        return
    fi

    while IFS='=' read -r key value; do
        case "$key" in
            COPIES)
                if [[ "$value" =~ ^[0-9]+$ ]] &&
                   [ "$value" -ge 1 ] &&
                   [ "$value" -le 20 ]; then
                    COPIES="$value"
                fi
                ;;
            PRINT_MODE)
                case "$value" in
                    Simplex|Duplex)
                        PRINT_MODE="$value"
                        ;;
                esac
                ;;
        esac
    done < "$STATE_FILE"

    log "Gespeicherter Zustand geladen: $COPIES Kopie(n), $PRINT_MODE"
}

save_state() {
    cat > "$STATE_FILE" <<EOF
COPIES=$COPIES
PRINT_MODE=$PRINT_MODE
EOF
}

check_share() {
    local testfile="$BASE_DIR/.scanprint-write-test"

    if ! touch "$testfile" 2>/dev/null; then
        log_error "$BASE_DIR ist nicht beschreibbar"
        return 1
    fi

    rm -f "$testfile"
    log_ok "/share/scanprint ist beschreibbar"
    return 0
}

check_mqtt() {
    if [ -z "$MQTT_HOST" ] || [ -z "$MQTT_PORT" ]; then
        log_error "MQTT-Serviceinformationen fehlen"
        return 1
    fi

    if ! nc -z -w 3 "$MQTT_HOST" "$MQTT_PORT"; then
        log_error "MQTT nicht erreichbar: $MQTT_HOST:$MQTT_PORT"
        return 1
    fi

    log_ok "MQTT erreichbar: $MQTT_HOST:$MQTT_PORT"
    return 0
}

check_cups_connection() {
    if ! nc -z -w 3 "$CUPS_HOST" "$CUPS_PORT"; then
        log_error "CUPS nicht erreichbar: $CUPS_SERVER"
        return 1
    fi

    log_ok "CUPS erreichbar: $CUPS_SERVER"
    return 0
}

check_queue() {
    local queue="$1"
    local description="$2"

    if ! lpstat -h "$CUPS_SERVER" -p "$queue" >/dev/null 2>&1; then
        log_error "$description-Queue '$queue' nicht gefunden"
        return 1
    fi

    log_ok "$description-Queue gefunden: $queue"
    return 0
}

check_duplex_support() {
    local options

    options="$(
        lpoptions \
            -h "$CUPS_SERVER" \
            -p "$DUPLEX_QUEUE" \
            -l 2>/dev/null || true
    )"

    if echo "$options" | grep -q "DuplexNoTumble"; then
        log_ok "Duplex lange Kante wird unterstützt"
        return 0
    fi

    log_warn "DuplexNoTumble wurde für '$DUPLEX_QUEUE' nicht erkannt"
    return 0
}

run_prechecks() {
    local failed=0

    log "================================================="
    log "Abhängigkeitsprüfung"
    log "================================================="

    check_share || failed=1
    check_mqtt || failed=1
    check_cups_connection || failed=1
    check_queue "$SIMPLE_QUEUE" "Simplex" || failed=1
    check_queue "$DUPLEX_QUEUE" "Duplex" || failed=1
    check_duplex_support

    log "================================================="

    if [ "$failed" -ne 0 ]; then
        log_error "Precheck fehlgeschlagen."
        log_error "ScanPrint wird nicht gestartet."
        exit 1
    fi

    log_ok "Alle erforderlichen Abhängigkeiten verfügbar"
}

publish_discovery() {
    log "Publiziere MQTT Discovery..."

    DEVICE="$(
        jq -nc \
            --arg version "$APP_VERSION" \
            '{
                identifiers:["scanprint"],
                name:"ScanPrint",
                manufacturer:"Local",
                model:"HAOS ScanPrint",
                sw_version:$version
            }'
    )"

    mqtt_pub -r \
        -t "$MQTT_DISCOVERY/number/scanprint/copies/config" \
        -m "$(jq -nc --argjson device "$DEVICE" '{
            name:"Kopien",
            unique_id:"scanprint_copies",
            default_entity_id:"number.scanprint_copies",
            command_topic:"scanprint/copies/set",
            state_topic:"scanprint/copies/state",
            min:1,
            max:20,
            step:1,
            mode:"box",
            icon:"mdi:content-copy",
            availability_topic:"scanprint/status",
            payload_available:"online",
            payload_not_available:"offline",
            device:$device
        }')"

    mqtt_pub -r \
        -t "$MQTT_DISCOVERY/select/scanprint/mode/config" \
        -m "$(jq -nc --argjson device "$DEVICE" '{
            name:"Druckmodus",
            unique_id:"scanprint_mode",
            default_entity_id:"select.scanprint_mode",
            command_topic:"scanprint/mode/set",
            state_topic:"scanprint/mode/state",
            options:["Simplex","Duplex"],
            icon:"mdi:book-open-page-variant",
            availability_topic:"scanprint/status",
            payload_available:"online",
            payload_not_available:"offline",
            device:$device
        }')"

    mqtt_pub -r \
        -t "$MQTT_DISCOVERY/button/scanprint/multicopy/config" \
        -m "$(jq -nc --argjson device "$DEVICE" '{
            name:"Mehrfachkopie drucken",
            unique_id:"scanprint_multicopy",
            default_entity_id:"button.scanprint_multicopy",
            command_topic:"scanprint/multicopy/print",
            payload_press:"PRESS",
            icon:"mdi:printer",
            availability_topic:"scanprint/status",
            payload_available:"online",
            payload_not_available:"offline",
            device:$device
        }')"

    mqtt_pub -r \
        -t "$MQTT_DISCOVERY/sensor/scanprint/status/config" \
        -m "$(jq -nc --argjson device "$DEVICE" '{
            name:"Status",
            unique_id:"scanprint_job_status",
            default_entity_id:"sensor.scanprint_status",
            state_topic:"scanprint/job/status",
            icon:"mdi:printer-check",
            availability_topic:"scanprint/status",
            payload_available:"online",
            payload_not_available:"offline",
            device:$device
        }')"

    mqtt_pub -r -t "$MQTT_BASE/copies/state" -m "$COPIES"
    mqtt_pub -r -t "$MQTT_BASE/mode/state" -m "$PRINT_MODE"
    mqtt_pub -r -t "$MQTT_BASE/status" -m "online"
    mqtt_pub -r -t "$MQTT_BASE/job/status" -m "bereit"
}

wait_until_stable() {
    local file="$1"
    local previous=-1
    local current=-2
    local stable=0

    while [ "$stable" -lt 2 ]; do
        if [ ! -f "$file" ]; then
            return 1
        fi

        current="$(stat -c %s "$file" 2>/dev/null || echo -1)"

        if [ "$current" = "$previous" ] && [ "$current" -gt 0 ]; then
            stable=$((stable + 1))
        else
            stable=0
        fi

        previous="$current"
        sleep 2
    done

    return 0
}

move_failed() {
    local file="$1"
    local basename
    local timestamp

    basename="$(basename "$file")"
    timestamp="$(date '+%Y%m%d-%H%M%S')"

    log_error "Verschiebe $basename nach failed"

    mv "$file" "$FAILED_DIR/${timestamp}_${basename}"

    mqtt_pub -r \
        -t "$MQTT_BASE/job/status" \
        -m "Fehler: $basename"
}

print_file() {
    local file="$1"
    local queue="$2"
    local mode="$3"
    local basename
    local output
    local rc

    basename="$(basename "$file")"

    case "${basename,,}" in
        *.pdf) ;;
        *)
            log_warn "$basename ist keine PDF und wird ignoriert"
            return 0
            ;;
    esac

    log "ERKANNT: $file"

    if ! wait_until_stable "$file"; then
        log_error "Datei nicht stabil oder verschwunden: $basename"
        return 1
    fi

    log "STABIL: $basename"

    mqtt_pub -r \
        -t "$MQTT_BASE/job/status" \
        -m "Drucke $basename"

    if [ "$mode" = "duplex" ]; then
        output="$(
            lp \
                -h "$CUPS_SERVER" \
                -d "$queue" \
                -o sides=two-sided-long-edge \
                -o Duplex=DuplexNoTumble \
                -o media=A4 \
                "$file" 2>&1
        )"
        rc=$?
    else
        output="$(
            lp \
                -h "$CUPS_SERVER" \
                -d "$queue" \
                -o sides=one-sided \
                -o Duplex=None \
                -o media=A4 \
                "$file" 2>&1
        )"
        rc=$?
    fi

    if [ "$rc" -ne 0 ]; then
        log_error "Druckauftrag fehlgeschlagen: $output"
        move_failed "$file"
        return 1
    fi

    log "CUPS: $output"

    if rm -f "$file"; then
        log_ok "$basename an CUPS übergeben und Quelldatei gelöscht"
    else
        log_warn "$basename wurde gedruckt, konnte aber nicht gelöscht werden"
    fi

    mqtt_pub -r \
        -t "$MQTT_BASE/job/status" \
        -m "bereit"

    return 0
}

get_oldest_multicopy_file() {
    local file
    local mtime
    local oldest_file=""
    local oldest_mtime=""

    while IFS= read -r -d '' file; do
        mtime="$(stat -c %Y "$file" 2>/dev/null || echo 0)"

        if [ -z "$oldest_file" ] || [ "$mtime" -lt "$oldest_mtime" ]; then
            oldest_file="$file"
            oldest_mtime="$mtime"
        fi
    done < <(
        find "$MULTICOPY_DIR" \
            -maxdepth 1 \
            -type f \
            -iname '*.pdf' \
            -print0
    )

    printf '%s' "$oldest_file"
}

print_multicopy() {
    local file
    local basename
    local queue
    local mode_text
    local output
    local rc

    file="$(get_oldest_multicopy_file)"

    if [ -z "$file" ]; then
        log_warn "Keine Mehrfachkopie vorhanden"
        mqtt_pub -r \
            -t "$MQTT_BASE/job/status" \
            -m "Keine Mehrfachkopie vorhanden"
        return 0
    fi

    basename="$(basename "$file")"

    if [ "$PRINT_MODE" = "Duplex" ]; then
        queue="$DUPLEX_QUEUE"
        mode_text="Duplex"
    else
        queue="$SIMPLE_QUEUE"
        mode_text="Simplex"
    fi

    log "MEHRFACHKOPIE: $basename x $COPIES ($mode_text)"

    if ! wait_until_stable "$file"; then
        log_error "Mehrfachkopie nicht stabil: $basename"
        mqtt_pub -r \
            -t "$MQTT_BASE/job/status" \
            -m "Fehler: Datei nicht vollständig"
        return 1
    fi

    mqtt_pub -r \
        -t "$MQTT_BASE/job/status" \
        -m "Drucke $COPIES Kopie(n) – $mode_text"

    if [ "$PRINT_MODE" = "Duplex" ]; then
        if [ "$COLLATE" = "true" ]; then
            output="$(
                lp \
                    -h "$CUPS_SERVER" \
                    -d "$queue" \
                    -n "$COPIES" \
                    -o collate=true \
                    -o sides=two-sided-long-edge \
                    -o Duplex=DuplexNoTumble \
                    -o media=A4 \
                    "$file" 2>&1
            )"
        else
            output="$(
                lp \
                    -h "$CUPS_SERVER" \
                    -d "$queue" \
                    -n "$COPIES" \
                    -o collate=false \
                    -o sides=two-sided-long-edge \
                    -o Duplex=DuplexNoTumble \
                    -o media=A4 \
                    "$file" 2>&1
            )"
        fi
        rc=$?
    else
        if [ "$COLLATE" = "true" ]; then
            output="$(
                lp \
                    -h "$CUPS_SERVER" \
                    -d "$queue" \
                    -n "$COPIES" \
                    -o collate=true \
                    -o sides=one-sided \
                    -o Duplex=None \
                    -o media=A4 \
                    "$file" 2>&1
            )"
        else
            output="$(
                lp \
                    -h "$CUPS_SERVER" \
                    -d "$queue" \
                    -n "$COPIES" \
                    -o collate=false \
                    -o sides=one-sided \
                    -o Duplex=None \
                    -o media=A4 \
                    "$file" 2>&1
            )"
        fi
        rc=$?
    fi

    if [ "$rc" -ne 0 ]; then
        log_error "Mehrfachkopie fehlgeschlagen: $output"
        move_failed "$file"
        return 1
    fi

    log "CUPS: $output"

    if rm -f "$file"; then
        log_ok "$basename x $COPIES ($mode_text) an CUPS übergeben"
    else
        log_warn "Mehrfachkopie gedruckt, Quelldatei konnte nicht gelöscht werden"
    fi

    mqtt_pub -r \
        -t "$MQTT_BASE/job/status" \
        -m "bereit"

    return 0
}

process_existing() {
    log "Prüfe vorhandene Standard-Dateien..."

    find "$SIMPLE_DIR" \
        -maxdepth 1 \
        -type f \
        -iname '*.pdf' \
        -print0 |
    while IFS= read -r -d '' file; do
        print_file "$file" "$SIMPLE_QUEUE" "simple"
    done

    find "$DUPLEX_DIR" \
        -maxdepth 1 \
        -type f \
        -iname '*.pdf' \
        -print0 |
    while IFS= read -r -d '' file; do
        print_file "$file" "$DUPLEX_QUEUE" "duplex"
    done
}

mqtt_listener() {
    mosquitto_sub \
        -h "$MQTT_HOST" \
        -p "$MQTT_PORT" \
        -u "$MQTT_USER" \
        -P "$MQTT_PASSWORD" \
        -v \
        -t "$MQTT_BASE/copies/set" \
        -t "$MQTT_BASE/mode/set" \
        -t "$MQTT_BASE/multicopy/print" |
    while read -r topic payload; do
        case "$topic" in
            "$MQTT_BASE/copies/set")
                if [[ "$payload" =~ ^[0-9]+$ ]] &&
                   [ "$payload" -ge 1 ] &&
                   [ "$payload" -le 20 ]; then
                    COPIES="$payload"
                    save_state
                    log "Kopienzahl: $COPIES"
                    mqtt_pub -r \
                        -t "$MQTT_BASE/copies/state" \
                        -m "$COPIES"
                else
                    log_warn "Ungültige Kopienzahl: $payload"
                fi
                ;;
            "$MQTT_BASE/mode/set")
                case "$payload" in
                    Simplex|Duplex)
                        PRINT_MODE="$payload"
                        save_state
                        log "Druckmodus: $PRINT_MODE"
                        mqtt_pub -r \
                            -t "$MQTT_BASE/mode/state" \
                            -m "$PRINT_MODE"
                        ;;
                    *)
                        log_warn "Ungültiger Druckmodus: $payload"
                        ;;
                esac
                ;;
            "$MQTT_BASE/multicopy/print")
                if [ "$payload" = "PRESS" ]; then
                    print_multicopy
                fi
                ;;
        esac
    done
}

cleanup() {
    log "ScanPrint wird beendet"
    mqtt_pub -r \
        -t "$MQTT_BASE/status" \
        -m "offline" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

create_directories
load_state

log "================================================="
log "ScanPrint $APP_VERSION"
log "================================================="
log "Konfiguration:"
log "CUPS:           $CUPS_SERVER"
log "Simplex:        $SIMPLE_QUEUE"
log "Duplex:         $DUPLEX_QUEUE"
log "Kopien Default: $COPIES_DEFAULT"
log "Modus Default:  $PRINT_MODE_DEFAULT"
log "Collate:        $COLLATE"
log "================================================="

run_prechecks
publish_discovery
mqtt_listener &
process_existing

log_ok "ScanPrint bereit"
log "Dateiüberwachung aktiv"

inotifywait \
    -m \
    -e close_write \
    -e moved_to \
    --format '%w%f' \
    "$SIMPLE_DIR" \
    "$DUPLEX_DIR" |
while IFS= read -r file; do
    case "$file" in
        "$SIMPLE_DIR"/*)
            print_file "$file" "$SIMPLE_QUEUE" "simple"
            ;;
        "$DUPLEX_DIR"/*)
            print_file "$file" "$DUPLEX_QUEUE" "duplex"
            ;;
    esac
done
