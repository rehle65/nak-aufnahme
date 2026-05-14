#!/bin/bash
# NAK Gottesdienst Aufnahme
# Verwendung: nak-aufnahme.sh GOTTESDIENST_BEGINN DAUER_MINUTEN [test]
#   GOTTESDIENST_BEGINN: Format HH:MM (z.B. 20:00)
#   DAUER_MINUTEN:       Aufnahmedauer ab OBS-Start in Minuten (z.B. 90)
#   test:                Optionaler Parameter — kompletter Ablauf, Aufnahme nur 3 Minuten

LOG=~/nak-aufnahme.log

# Parameter prüfen
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "[$(date)] FEHLER: Aufruf: nak-aufnahme.sh HH:MM DAUER_MINUTEN [test]" | tee -a "$LOG"
    exit 1
fi

# --- Laufende Instanzen beenden ---
MYPID=$$
RUNNING=$(pgrep -f "nak-aufnahme.sh" | grep -v "^${MYPID}$")
if [ -n "$RUNNING" ]; then
    echo "[$(date)] Laufende Instanz(en) gefunden (PID: $RUNNING) — werden beendet." | tee -a "$LOG"
    kill $RUNNING 2>/dev/null
    sleep 2
    kill -9 $RUNNING 2>/dev/null
    echo "[$(date)] Alte Instanz(en) beendet." >> "$LOG"
fi

GOTTESDIENST="$1"
DAUER="$2"
TESTMODUS="${3:-}"

# Validierung Gottesdienstzeit
if ! echo "$GOTTESDIENST" | grep -qE '^([01][0-9]|2[0-3]):[0-5][0-9]$'; then
    echo "[$(date)] FEHLER: Ungültige Zeit '$GOTTESDIENST'. Format: HH:MM" | tee -a "$LOG"
    exit 1
fi

# Validierung Dauer
if ! echo "$DAUER" | grep -qE '^[0-9]+$'; then
    echo "[$(date)] FEHLER: Ungültige Dauer '$DAUER'. Nur Minuten als Zahl angeben." | tee -a "$LOG"
    exit 1
fi

# Testmodus: Aufnahmedauer auf 3 Minuten begrenzen
if [ "$TESTMODUS" = "test" ]; then
    AUFNAHME_SECS=180
    echo "[$(date)] *** TESTMODUS — Aufnahmedauer: 3 Minuten ***" >> "$LOG"
else
    AUFNAHME_SECS=$((DAUER * 60))
fi

# Zeiten berechnen
TODAY=$(date +%Y-%m-%d)
GOTTESDIENST_SECS=$(date -j -f "%Y-%m-%d %H:%M:%S" "${TODAY} ${GOTTESDIENST}:00" +%s)

# OBS-Aufnahme: 10 Minuten vor Gottesdienstbeginn
OBS_START_SECS=$((GOTTESDIENST_SECS - 10 * 60))

# naciptv startet ~50 Sek vor OBS-Start (Puffer für Ladezeit)
NACIPTV_START_SECS=$((OBS_START_SECS - 50))

# Aufnahmeende
OBS_STOP_SECS=$((OBS_START_SECS + AUFNAHME_SECS))

OBS_START_TIME=$(date -j -f "%s" "$OBS_START_SECS" +%H:%M)
OBS_STOP_TIME=$(date -j -f "%s" "$OBS_STOP_SECS" +%H:%M)

if [ "$TESTMODUS" = "test" ]; then
    echo "[$(date)] NAK-Aufnahme TESTLAUF: Gottesdienst $GOTTESDIENST Uhr | OBS-Start $OBS_START_TIME Uhr | OBS-Stop $OBS_STOP_TIME Uhr (3 Min Test)" >> "$LOG"
else
    echo "[$(date)] NAK-Aufnahme geplant: Gottesdienst $GOTTESDIENST Uhr | OBS-Start $OBS_START_TIME Uhr | OBS-Stop $OBS_STOP_TIME Uhr (${DAUER} Min)" >> "$LOG"
fi

# Warten bis naciptv gestartet werden soll
NOW_SECS=$(date +%s)
WAIT_NACIPTV=$((NACIPTV_START_SECS - NOW_SECS))

if [ $WAIT_NACIPTV -gt 0 ]; then
    echo "[$(date)] Warte ${WAIT_NACIPTV} Sekunden bis naciptv-Start..." >> "$LOG"
    sleep $WAIT_NACIPTV
fi

# naciptv starten
echo "[$(date)] Öffne naciptv PWA..." >> "$LOG"
open "/Users/roland.ehle/Applications/Edge Apps.localized/naciptv.app"

# Warten bis naciptv-Fenster tatsächlich bereit ist (max. 40 Sekunden)
echo "[$(date)] Warte auf naciptv-Fenster..." >> "$LOG"
NACIPTV_READY=0
for i in $(seq 1 20); do
    sleep 2
    WIN=$(osascript -e 'tell application "System Events" to tell process "naciptv" to count windows' 2>/dev/null)
    if [ "$WIN" -ge 1 ] 2>/dev/null; then
        NACIPTV_READY=1
        echo "[$(date)] naciptv-Fenster bereit nach $((i * 2)) Sekunden" >> "$LOG"
        break
    fi
done

if [ $NACIPTV_READY -eq 0 ]; then
    echo "[$(date)] WARNUNG: naciptv-Fenster nicht gefunden nach 40 Sekunden — versuche trotzdem fortzufahren" >> "$LOG"
fi

# naciptv positionieren und Vollbild
osascript -e 'tell application "System Events" to tell process "naciptv" to set position of window 1 to {3200, -1080}'
sleep 1
osascript -e 'tell application "System Events" to tell process "naciptv" to set value of attribute "AXFullScreen" of window 1 to true'
echo "[$(date)] naciptv auf Smart M70F im Vollbild" >> "$LOG"

# OBS starten
echo "[$(date)] Starte OBS..." >> "$LOG"
open -a OBS

# *** NEU: Warten bis OBS-Fenster wirklich bereit ist (max. 60 Sekunden) ***
OBS_READY=0
for i in $(seq 1 30); do
    sleep 2
    WIN=$(osascript -e 'tell application "System Events" to tell process "OBS" to count windows' 2>/dev/null)
    if [ "$WIN" -ge 1 ] 2>/dev/null; then
        OBS_READY=1
        echo "[$(date)] OBS bereit nach $((i * 2)) Sekunden" >> "$LOG"
        break
    fi
done

if [ $OBS_READY -eq 0 ]; then
    echo "[$(date)] FEHLER: OBS nicht gestartet nach 60 Sekunden — Abbruch!" >> "$LOG"
    exit 1
fi

# Zusätzliche 5 Sekunden Puffer damit OBS vollständig geladen ist
sleep 5

osascript -e 'tell application "System Events" to tell process "OBS" to set position of window 1 to {5120, 323}'
echo "[$(date)] OBS auf MacBook Display positioniert" >> "$LOG"

# Aufnahme starten via F9
osascript -e 'tell application "OBS" to activate'
sleep 3
osascript -e 'tell application "System Events" to key code 101'
echo "[$(date)] F9 gesendet — warte auf Aufnahmestart..." >> "$LOG"

# *** NEU: Prüfen ob Aufnahmedatei tatsächlich angelegt wurde (max. 30 Sekunden) ***
RECORDING_CONFIRMED=0
for i in $(seq 1 15); do
    sleep 2
    NEWEST=$(ls -t ~/Movies/*.mp4 ~/Movies/*.mkv 2>/dev/null | head -1)
    if [ -n "$NEWEST" ]; then
        FILE_AGE=$(( $(date +%s) - $(date -r "$NEWEST" +%s) ))
        if [ $FILE_AGE -lt 60 ]; then
            RECORDING_CONFIRMED=1
            echo "[$(date)] Aufnahme bestätigt: $(basename "$NEWEST")" >> "$LOG"
            break
        fi
    fi
done

# *** NEU: Wenn keine Datei — nochmal F9 versuchen ***
if [ $RECORDING_CONFIRMED -eq 0 ]; then
    echo "[$(date)] WARNUNG: Keine Aufnahmedatei gefunden — sende F9 erneut..." >> "$LOG"
    osascript -e 'tell application "OBS" to activate'
    sleep 2
    osascript -e 'tell application "System Events" to key code 101'
    sleep 5
    # Nochmal prüfen
    NEWEST=$(ls -t ~/Movies/*.mp4 ~/Movies/*.mkv 2>/dev/null | head -1)
    if [ -n "$NEWEST" ]; then
        FILE_AGE=$(( $(date +%s) - $(date -r "$NEWEST" +%s) ))
        if [ $FILE_AGE -lt 60 ]; then
            echo "[$(date)] Aufnahme nach 2. Versuch bestätigt: $(basename "$NEWEST")" >> "$LOG"
            RECORDING_CONFIRMED=1
        fi
    fi
    if [ $RECORDING_CONFIRMED -eq 0 ]; then
        echo "[$(date)] FEHLER: Aufnahme konnte nicht gestartet werden — OBS läuft, aber keine Datei!" >> "$LOG"
        # Trotzdem weiterlaufen und am Ende stoppen versuchen
    fi
fi

echo "[$(date)] Aufnahme läuft ${AUFNAHME_SECS} Sekunden bis $OBS_STOP_TIME Uhr" >> "$LOG"

# Warten
sleep $AUFNAHME_SECS

# Aufnahme stoppen via F10
osascript -e 'tell application "OBS" to activate'
sleep 2
osascript -e 'tell application "System Events" to key code 109'
echo "[$(date)] Aufnahme gestoppt (F10)" >> "$LOG"

sleep 3

# OBS beenden
osascript -e 'quit app "OBS"'
echo "[$(date)] OBS beendet" >> "$LOG"

# naciptv beenden
osascript -e 'tell application "naciptv" to quit' 2>/dev/null
sleep 2
pkill -f "naciptv" 2>/dev/null
echo "[$(date)] naciptv beendet" >> "$LOG"

echo "[$(date)] Fertig." >> "$LOG"
