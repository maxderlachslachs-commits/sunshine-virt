#!/bin/bash

# sunshine-virt.sh – Virtual/Mirror Display Umschalter für Sunshine + Moonlight
#
# Install:  chmod +x ~/.local/bin/sunshine-virt.sh
# Usage:    sunshine-virt.sh {virtuell|spiegel|ask|cleanup|status|daemon}
#
# Voraussetzung: geladener vkms-Kernel-Treiber (erzeugt virtuellen Ausgang Virtual-1)
#   sudo modprobe vkms
#
# Abhängigkeiten: kdialog, kscreen-doctor (KDE Plasma 6)

set -e

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-virt"
STATE_FILE="$STATE_DIR/mode"
PID_FILE="$STATE_DIR/daemon.pid"
SUNSHINE_PID_FILE="$STATE_DIR/sunshine.pid"

# Welche physischen Ausgänge existieren? (alles ausser Virtual-*)
get_physical_outputs() {
    kscreen-console json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
phys = [o['name'] for o in d['outputs'] if 'Virtual' not in o['name'] and o.get('enabled')]
print(' '.join(phys))
"
}

# Alle Ausgänge (für cleanup)
get_all_outputs() {
    kscreen-console json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
outs = [o['name'] for o in d['outputs']]
print(' '.join(outs))
"
}

setup_virtual() {
    local mode="${1:-33}"  # default: 33 = 1920x1080@60

    mkdir -p "$STATE_DIR"

    # Physische Ausgänge merken und deaktivieren
    PHYS_OUTPUTS=$(get_physical_outputs)
    echo "$PHYS_OUTPUTS" > "$STATE_DIR/physical_outputs"

    # Virtuellen Ausgang aktivieren + Modus setzen
    kscreen-doctor "output.Virtual-1.enable" "output.Virtual-1.mode.$mode" 2>/dev/null || {
        kscreen-doctor "output.Virtual-1.enable" 2>/dev/null
    }

    # Physische Ausgänge deaktivieren
    for out in $PHYS_OUTPUTS; do
        kscreen-doctor "output.$out.disable" 2>/dev/null || true
    done

    echo "virtual" > "$STATE_FILE"
    echo "Virtueller Bildschirm aktiviert (Virtual-1, Mode $mode)"
}

setup_mirror() {
    mkdir -p "$STATE_DIR"

    # Zuerst physische Ausgänge aktivieren, DANN virtuellen deaktivieren
    if [ -f "$STATE_DIR/physical_outputs" ]; then
        PHYS_OUTPUTS=$(cat "$STATE_DIR/physical_outputs")
        for out in $PHYS_OUTPUTS; do
            kscreen-doctor "output.$out.enable" 2>/dev/null || true
        done
    else
        for out in $(get_all_outputs); do
            if [[ "$out" != Virtual* ]]; then
                kscreen-doctor "output.$out.enable" 2>/dev/null || true
            fi
        done
    fi

    # Jetzt virtuellen Ausgang deaktivieren (mind. 1 physischer ist aktiv)
    kscreen-doctor "output.Virtual-1.disable" 2>/dev/null || true

    echo "mirror" > "$STATE_FILE"
    echo "Spiegelmodus aktiviert (physische Bildschirme)"
}

ask_dialog() {
    # Prüfen, ob DISPLAY gesetzt (also GUI verfügbar)
    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        echo "Kein GUI Display verfügbar – frage via Konsole" >&2
        echo "1) Virtuell (1920x1080)"
        echo "2) Virtuell (4K)"
        echo "3) Spiegel (physische Bildschirme)"
        echo "4) Abbrechen"
        read -rp "Auswahl [1-4]: " choice
    else
        choice=$(kdialog --title "Bildschirm-Modus wählen" \
            --menu "Moonlight/Sunshine Bildschirm-Modus\n\nWie soll der Stream angezeigt werden?" \
            "virtuell1080" "Virtueller Bildschirm 1920x1080 (neu verbinden)" \
            "virtuell4k"   "Virtueller Bildschirm 4096x2160 (neu verbinden)" \
            "spiegel"      "Spiegel – physische Bildschirme" \
            "abbrechen"    "Abbrechen – nichts ändern" \
            2>/dev/null)
    fi

    case "$choice" in
        virtuell1080)
            setup_virtual 33
            kdialog --title "Virtueller Bildschirm" \
                --msgbox "Virtueller Bildschirm (1920x1080) ist aktiv.\n\nBitte trennen Sie die Moonlight-Verbindung und verbinden Sie sich erneut.\nSunshine zeigt nun den virtuellen Bildschirm an." 2>/dev/null || true
            ;;
        virtuell4k)
            setup_virtual 23
            kdialog --title "Virtueller Bildschirm" \
                --msgbox "Virtueller Bildschirm (4096x2160) ist aktiv.\n\nBitte trennen Sie die Moonlight-Verbindung und verbinden Sie sich erneut.\nSunshine zeigt nun den virtuellen Bildschirm an." 2>/dev/null || true
            ;;
        spiegel)
            setup_mirror
            kdialog --title "Spiegelmodus" \
                --msgbox "Spiegelmodus aktiv.\n\nSunshine zeigt weiterhin die physischen Bildschirme an." 2>/dev/null || true
            ;;
        abbrechen|"")
            echo "Abgebrochen"
            exit 0
            ;;
        1)
            setup_virtual 33
            echo "Virtuell 1920x1080 aktiv. Bitte reconnecten."
            ;;
        2)
            setup_virtual 23
            echo "Virtuell 4K aktiv. Bitte reconnecten."
            ;;
        3)
            setup_mirror
            echo "Spiegelmodus aktiv."
            ;;
        4|"")
            echo "Abgebrochen"
            exit 0
            ;;
    esac
}

cleanup() {
    # Stelle sicher, dass physische Bildschirme an sind und Virtual aus
    setup_mirror
    rm -f "$STATE_FILE" "$PID_FILE"
    echo "Cleanup: physische Bildschirme wiederhergestellt"
}

status() {
    if [ -f "$STATE_FILE" ]; then
        echo "Modus: $(cat "$STATE_FILE")"
        kscreen-console json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for o in d['outputs']:
    icon = '✓' if o.get('enabled') else '✗'
    mode = o.get('currentModeId', '?')
    print(f'  {icon} {o[\"name\"]} (id={o[\"id\"]}) mode={mode} enabled={o.get(\"enabled\")}')
"
    else
        echo "Kein Modus gesetzt (Standard-Bildschirme)"
        kscreen-console json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for o in d['outputs']:
    icon = '✓' if o.get('enabled') else '✗'
    print(f'  {icon} {o[\"name\"]} (id={o[\"id\"]}) enabled={o.get(\"enabled\")}')
"
    fi
}

# Prüfen ob der Daemon läuft
check_daemon() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$PID_FILE"
    fi
    return 1
}

# Daemon-Modus: Überwacht Moonlight-Verbindungen und zeigt Dialog
daemon_mode() {
    mkdir -p "$STATE_DIR"
    echo $$ > "$PID_FILE"

    echo "Daemon gestartet (PID $$) – überwache Moonlight/Sunshine Verbindungen..."

    while true; do
        # Warte auf Sunshine-Prozess
        SUNSHINE_PID=$(pidof sunshine 2>/dev/null || echo "")

        if [ -n "$SUNSHINE_PID" ]; then
            echo "$SUNSHINE_PID" > "$SUNSHINE_PID_FILE"

            # Prüfe auf aktive Moonlight-Verbindungen über Sunshine Log
            # Wenn Verbindung aktiv und noch kein Dialog gezeigt
            if ! [ -f "$STATE_DIR/asked" ]; then
                # Kurz warten bis Stream stabil ist
                sleep 2
                # Dialog zeigen (blockiert bis Auswahl)
                ask_dialog
                touch "$STATE_DIR/asked"
            fi
        else
            rm -f "$SUNSHINE_PID_FILE" "$STATE_DIR/asked"
        fi

        sleep 5
    done
}

case "${1:-ask}" in
    virtuell|virtual)
        setup_virtual "${2:-33}"
        ;;
    spiegel|mirror)
        setup_mirror
        ;;
    ask|choose)
        ask_dialog
        ;;
    cleanup)
        cleanup
        ;;
    status)
        status
        ;;
    daemon)
        daemon_mode
        ;;
    *)
        echo "Verwendung: $0 {virtuell|spiegel|ask|cleanup|status|daemon}"
        echo ""
        echo "  virtuell [mode]  – Virtuellen Bildschirm aktivieren (Mode: 33=1080p, 23=4K)"
        echo "  spiegel          – Physische Bildschirme (Spiegelmodus)"
        echo "  ask              – Dialog zur Auswahl anzeigen"
        echo "  cleanup          – Alles zurücksetzen (physische Bildschirme an)"
        echo "  status           – Aktuellen Modus anzeigen"
        echo "  daemon           – Daemon-Modus (überwacht Verbindungen)"
        exit 1
        ;;
esac
