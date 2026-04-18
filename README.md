# nak-aufnahme

Automatische Aufnahme von NAK-Gottesdiensten (Neuapostolische Kirche) auf dem Mac mit OBS und naciptv.

## Was macht das Script?

Das Script `nak-aufnahme.sh` steuert den kompletten Aufnahme-Ablauf vollautomatisch:

1. Startet **naciptv** (PWA) und positioniert das Fenster auf dem gewünschten Monitor
2. Startet **OBS Studio** und positioniert es auf dem zweiten Monitor
3. Beginnt die OBS-Aufnahme **10 Minuten vor Gottesdienstbeginn**
4. Stoppt die Aufnahme nach der angegebenen Dauer
5. Beendet OBS und naciptv

Das Script kann beliebig früh gestartet werden — es wartet intern auf den richtigen Zeitpunkt. Ideal für den automatischen Start per macOS **launchd**.

## Voraussetzungen

### 1. OBS Studio

OBS muss installiert und eine Aufnahme-Szene eingerichtet sein. Die Aufnahme wird per Tastenkürzel gesteuert — diese müssen in OBS so konfiguriert sein:

- **F9** → Aufnahme starten
- **F10** → Aufnahme stoppen

### 2. naciptv als PWA (einmalige Einrichtung)

naciptv muss einmalig als Progressive Web App über Microsoft Edge installiert werden:

1. [https://naciptv.com](https://naciptv.com) im Edge-Browser öffnen
2. Mit den NAK-Zugangsdaten anmelden
3. Edge-Menü → Apps → Diese Seite als App installieren
4. Die App erscheint dann unter `~/Applications/Edge Apps.localized/naciptv.app`

> **Wichtig:** Durch diese Einrichtung erscheint der Mac im IPTV-Portal als Gerät. Das Gerät muss einmalig im Portal zu den jeweiligen Gottesdiensten hinzugefügt werden, damit der Stream freigegeben wird.

### 3. Fensterpositionen anpassen

Im Script sind die Fensterpositionen auf ein bestimmtes Monitor-Setup abgestimmt und müssen angepasst werden. So ermittelt ihr die richtigen Koordinaten:

1. naciptv bzw. OBS manuell auf den gewünschten Monitor schieben
2. Position per AppleScript abfragen:

```bash
osascript -e 'tell application "System Events" to tell process "naciptv" to get position of window 1'
osascript -e 'tell application "System Events" to tell process "OBS" to get position of window 1'
```

3. Die ausgegebenen Werte im Script eintragen (Zeilen mit `set position of window 1 to`)

## Installation

```bash
# Script herunterladen
curl -o ~/nak-aufnahme.sh https://raw.githubusercontent.com/rehle65/nak-aufnahme/main/nak-aufnahme.sh

# Ausführbar machen
chmod +x ~/nak-aufnahme.sh
```

## Verwendung

```bash
~/nak-aufnahme.sh GOTTESDIENST_BEGINN DAUER_MINUTEN [test]
```

| Parameter | Format | Beschreibung |
|-----------|--------|-------------|
| `GOTTESDIENST_BEGINN` | `HH:MM` | Uhrzeit des Gottesdienstbeginns |
| `DAUER_MINUTEN` | Zahl | Aufnahmedauer in Minuten |
| `test` | Wort | Optional: Testmodus — kompletter Ablauf, Aufnahme nur 3 Minuten |

### Beispiele

```bash
# Sonntagsgottesdienst um 10:00 Uhr, 90 Minuten aufnehmen:
~/nak-aufnahme.sh 10:00 90

# Abenddienst um 20:00 Uhr, 100 Minuten:
~/nak-aufnahme.sh 20:00 100

# Testlauf (kompletter Ablauf, Aufnahme nur 3 Minuten):
~/nak-aufnahme.sh 10:00 90 test
```

### Zeitplan

| Zeitpunkt | Berechnung |
|-----------|-----------|
| naciptv startet | Gottesdienstbeginn − ~10:50 Min |
| OBS-Aufnahme startet | Gottesdienstbeginn − 10 Min |
| Aufnahme endet | OBS-Start + Laufzeit |

## Automatischer Start per launchd

Damit das Script automatisch zur richtigen Zeit startet, ohne dass etwas anderes laufen muss, kann ein macOS launchd-Job eingerichtet werden.

### Plist-Datei erstellen

Datei speichern unter `~/Library/LaunchAgents/de.naki.gottesdienst-aufnahme.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>de.naki.gottesdienst-aufnahme</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/BENUTZERNAME/nak-aufnahme.sh</string>
        <string>10:00</string>
        <string>90</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>9</integer>
        <key>Weekday</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/BENUTZERNAME/nak-aufnahme.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/BENUTZERNAME/nak-aufnahme-error.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
```

> `BENUTZERNAME` durch den macOS-Benutzernamen ersetzen.  
> Wochentage: 0=Sonntag, 1=Montag, 2=Dienstag, 3=Mittwoch, 4=Donnerstag, 5=Freitag, 6=Samstag

**Wichtig:** Der Script-Start (hier 09:09) sollte ~20 Minuten vor Gottesdienstbeginn liegen — das Script wartet intern auf den richtigen Moment.

### Job laden und prüfen

```bash
# Laden:
launchctl load ~/Library/LaunchAgents/de.naki.gottesdienst-aufnahme.plist

# Status prüfen (Job muss in der Liste erscheinen):
launchctl list | grep naki

# Job entfernen:
launchctl unload ~/Library/LaunchAgents/de.naki.gottesdienst-aufnahme.plist
rm ~/Library/LaunchAgents/de.naki.gottesdienst-aufnahme.plist
```

Der Mac muss zum Startzeitpunkt eingeschaltet und angemeldet sein — mehr nicht.

## Log-Dateien

```bash
# Aufnahme-Log verfolgen:
tail -f ~/nak-aufnahme.log

# Fehlerlog:
cat ~/nak-aufnahme-error.log
```

## Lizenz

MIT
