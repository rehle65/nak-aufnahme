#!/bin/bash
# NAK Gottesdienst Aufnahme
# Verwendung: nak-aufnahme.sh GOTTESDIENST_BEGINN DAUER_MINUTEN [test]
#   GOTTESDIENST_BEGINN: Format HH:MM (z.B. 20:00)
#   DAUER_MINUTEN:       Aufnahmedauer ab OBS-Start in Minuten (z.B. 90)
#   test:                Optionaler Parameter — kompletter Ablauf, Aufnahme nur 3 Minuten
#
# Beispiele:
#   ./nak-aufnahme.sh 20:00 90        -> normaler Ablauf, OBS startet 19:50, läuft 90 Min
#   ./nak-aufnahme.sh 20:00 90 test   -> Testlauf, OBS startet 19:50, Aufnahme nur 3 Min

LOG=~/nak-aufnahme.log

# Parameter prüfen
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "[$(date)] FEHLER: Aufruf: nak-aufnahme.sh HH:MM DAUER_MINUTEN [test]" | tee -a "$LOG"
    exit 1
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

# naciptv startet ~50 Sek vor OBS-Start (8 Sek Start + 30 Sek OBS-Init + 3 Sek + Puffer)
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
sleep 8
osascript -e 'tell application "System Events" to tell process "naciptv" to set position of window 1 to {3200, -1080}'
osascript -e 'tell application "System Events" to tell process "naciptv" to set value of attribute "AXFullScreen" of window 1 to true'
echo "[$(date)] naciptv auf Smart M70F im Vollbild" >> "$LOG"

# OBS starten
echo "[$(date)] Starte OBS..." >> "$LOG"
open -a OBS
sleep 30
osascript -e 'tell application "System Events" to tell process "OBS" to set position of window 1 to {5120, 323}'
echo "[$(date)] OBS auf MacBook Display positioniert" >> "$LOG"

# Aufnahme starten via F9
osascript -e 'tell application "OBS" to activate'
sleep 3
osascript -e 'tell application "System Events" to key code 101'
echo "[$(date)] Aufnahme gestartet (F9) — läuft ${AUFNAHME_SECS} Sekunden bis $OBS_STOP_TIME Uhr" >> "$LOG"

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
