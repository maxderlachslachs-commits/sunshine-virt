# sunshine-virt

Virtueller Bildschirm (vkms) + Mirror-Umschaltung für **Moonlight + Sunshine** unter **KDE Plasma 6 (Wayland)**.

## Features

- **Virtueller Bildschirm** über `vkms` (Virtual Kernel Mode Setting) – kein HDMI-Dummy-Plug nötig
- Per `kscreen-doctor` wird der virtuelle Ausgang `Virtual-1` aktiviert, physische Bildschirme deaktiviert
- **Spiegelmodus** – physische Bildschirme bleiben an, Sunshine streamt wie gewohnt
- **Interaktiver Dialog** (`kdialog`) zur Auswahl beim Verbinden
- Vollständig via Moonlight-App-Liste steuerbar
- Daemon-Modus für automatisierte Abfrage bei Verbindungsaufbau

## Voraussetzungen

| Paket | Zweck |
|-------|-------|
| `sunshine` | Game-Stream-Host |
| `moonlight-qt` | Client (beliebiges Gerät) |
| `kdialog` | Dialogfenster (KDE) |
| `kscreen-doctor` | Bildschirm-Konfiguration (KDE) |
| `python3` | Für JSON-Parsing |
| Linux-Kernel ≥6.x mit `vkms` | Virtual Display Treiber |

Prüfen ob `vkms` verfügbar ist:

    modinfo vkms

Sollte Modul-Informationen anzeigen. Bei Arch Linux im Standard-Kernel enthalten.

## Installation

### 1. vkms automatisch laden

    sudo tee /etc/modules-load.d/vkms.conf <<< "vkms"
    sudo modprobe vkms

Nach Reboot oder `sudo modprobe vkms` erscheint `Virtual-1` in den Bildschirm-Einstellungen.

### 2. Skript installieren

    cp sunshine-virt.sh ~/.local/bin/
    chmod +x ~/.local/bin/sunshine-virt.sh

### 3. Sunshine Apps konfigurieren

`~/.config/sunshine/apps.json` um folgende Apps ergänzen:

| App in Moonlight | Beschreibung |
|-----------------|--------------|
| **Virtuell (1920x1080)** | Schaltet auf virtuellen Bildschirm, physische aus |
| **Virtuell (4K)** | Wie oben, mit 4096x2160 Auflösung |
| **Spiegel (Mirror)** | Schaltet zurück auf physische Bildschirme |
| **Display-Modus wählen** | Zeigt `kdialog`-Auswahl auf dem Host |

Nach dem Hinzufügen: Sunshine Web UI → "Restart" (oder `systemctl --user restart sunshine`).

### 4. (Optional) Daemon-Service

    mkdir -p ~/.config/systemd/user
    cp sunshine-virt.service ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user enable --now sunshine-virt.service

Der Daemon überwacht Sunshine-Verbindungen und zeigt bei jedem neuen
Client-Verbindungsaufbau den Auswahl-Dialog (1x pro Session).

## Benutzung

### Via Moonlight App-Liste

1. Moonlight öffnen und mit dem Host verbinden
2. Gewünschte App auswählen:
   - **Virtuell (1920x1080)** – stream startet auf virtuellem Display
   - **Virtuell (4K)** – gleiches Setup in 4K
   - **Spiegel (Mirror)** – physische Bildschirme werden gestreamt
3. Nach Wahl "Virtuell": Stream trennen und erneut verbinden
4. Nach Wahl "Spiegel": Stream läuft normal weiter

### Interaktiver Dialog

App "**Display-Modus wählen**" in Moonlight starten.
Daraufhin erscheint auf dem Host ein `kdialog`-Fenster:

- *Virtueller Bildschirm 1920x1080* – aktiviert Virtual-1, deaktiviert physische
- *Virtueller Bildschirm 4K* – gleiches Setup in 4K
- *Spiegel – physische Bildschirme* – schaltet zurück
- *Abbrechen* – nichts ändern

Nach der Wahl "Virtuell": Verbindung trennen, erneut verbinden.
Nun streamt Sunshine den virtuellen Bildschirm.

### Kommandozeile

    sunshine-virt.sh virtuell [mode]   # Virtuell (default mode=33 = 1920x1080)
    sunshine-virt.sh spiegel           # Spiegelmodus
    sunshine-virt.sh ask               # Dialog anzeigen
    sunshine-virt.sh status            # Aktuelle Ausgänge anzeigen
    sunshine-virt.sh cleanup           # Alles zurücksetzen

## So funktioniert's

```
Moonlight Client                Sunshine Host
     │                              │
     │  App "Virtuell" starten       │
     │─────────────────────────────> │
     │                              ├─ sunshine-virt.sh virtuell
     │                              ├─ vkms (Virtual-1) aktivieren
     │                              ├─ physische Ausgänge deaktivieren
     │  Stream zeigt Virtual-1      │
     │<─────────────────────────────│
     │                              │
     │  [User trennt Verbindung]    │
     │                              │
     │  Erneutes Verbinden          │
     │─────────────────────────────> │
     │  Stream zeigt Virtual-1      │
     │<─────────────────────────────│
```

## Troubleshooting

**Virtual-1 erscheint nicht**
→ `sudo modprobe vkms` ausführen. Prüfen mit `ls /sys/class/drm/`.

**"Alle Ausgabegeräte deaktivieren ist nicht zulässig"**
→ Der `cleanup`-/`spiegel`-Befehl aktiviert zuerst die physischen Ausgänge,
bevor Virtual-1 deaktiviert wird. Das Skript behandelt dies korrekt.

**Stream zeigt schwarzen Bildschirm**
→ Nach Umschaltung auf Virtuell: Moonlight-Verbindung trennen und neu verbinden.
Der Stream muss neu aufgebaut werden, um den neuen Bildschirm zu erfassen.

## Lizenz

MIT
