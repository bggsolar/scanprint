# ScanPrint

**Author:** Sascha Baron (`bggsolar`)  
**Status:** Beta  
**License:** MIT  
**Current release:** 0.5.2

ScanPrint is a lightweight Home Assistant OS app that turns a network document scanner and a CUPS-compatible printer into a simple scan-to-copy workflow.

A scanner writes PDF files to folders exposed through the Home Assistant Samba share. ScanPrint monitors these folders and forwards completed PDFs to configured CUPS print queues.

The project was originally developed for a Canon imageFORMULA DR-S130 scanner and an HP LaserJet M209dw printer, but the architecture is not tied to these devices.

## Recommended Home Assistant OS setup

```text
Home Assistant OS
├── Samba Share
├── Mosquitto Broker
├── CUPS Print Server
└── ScanPrint
```

ScanPrint is designed for Home Assistant OS with Supervisor/App support.

It uses:
- `/share` for scanner input and failed jobs,
- the Supervisor-provided MQTT service for Home Assistant entities,
- a reachable CUPS server for printing.

ScanPrint does **not** include or configure the CUPS server itself.

## Features

- Automatic PDF printing from a Samba share
- Separate Simplex and Duplex workflows
- Long-edge duplex printing
- Multiple-copy workflow with selectable copy count
- Selectable Simplex/Duplex mode for multiple copies
- Collated multi-copy printing
- MQTT Discovery
- Persistent copy-count and print-mode settings
- Startup dependency checks
- Available CUPS queue listing
- Multicopy queue visibility in Home Assistant
- Failed-job counter
- Last-job sensor
- Technical readiness binary sensor
- Automatic app version and architecture reporting
- No permanent storage required for successfully processed copy jobs

## Folder structure

```text
/share/scanprint/
├── simple/
├── duplex/
├── multicopy/
└── failed/
```

### Simplex

Files placed in `/share/scanprint/simple` are printed automatically with the configured Simplex queue.

### Duplex

Files placed in `/share/scanprint/duplex` are printed automatically using long-edge duplex printing.

### Multicopy

Files placed in `/share/scanprint/multicopy` wait for user confirmation.

If multiple PDFs are waiting, the oldest PDF is processed first. One press of the multicopy print button processes exactly one document.

## Home Assistant entities

Core controls:

- `number.scanprint_copies`
- `select.scanprint_mode`
- `button.scanprint_multicopy`
- `sensor.scanprint_status`

Diagnostics and queue visibility:

- `binary_sensor.scanprint_ready`
- `sensor.scanprint_multicopy_pending`
- `sensor.scanprint_multicopy_next`
- `sensor.scanprint_failed_count`
- `sensor.scanprint_last_job`

### Ready

`binary_sensor.scanprint_ready` reflects whether the app passed its startup checks and is operational.

### Multicopy pending

`sensor.scanprint_multicopy_pending` shows how many PDF documents are waiting.

### Multicopy next

`sensor.scanprint_multicopy_next` shows the filename of the oldest waiting PDF.

### Failed count

`sensor.scanprint_failed_count` shows how many failed PDFs are currently stored in `/share/scanprint/failed`.

### Last job

`sensor.scanprint_last_job` shows the last submitted job in a compact format.

## Installation on Home Assistant OS

1. Open **Settings → Apps → App Store**.
2. Open the repository menu.
3. Add:

   ```text
   https://github.com/bggsolar/scanprint
   ```

4. Refresh the App Store.
5. Install **ScanPrint**.
6. Open the **Configuration** tab.
7. Configure CUPS host, port and queue names.
8. Start the app.
9. Check the app log.

For development, the `scanprint` directory may also be copied to:

```text
/addons/scanprint
```

Do not keep both a repository-installed and a local development copy with the same slug active at the same time.

## Configuration

Example:

```yaml
cups_host: "homeassistant.local"
cups_port: 631
simplex_queue: "Printer_Simplex"
duplex_queue: "Printer_Duplex"
copies_default: 1
print_mode_default: "Simplex"
collate: true
```

### CUPS host and port

The configured host may be the Home Assistant host itself if CUPS is running as another HAOS app and is reachable over the LAN address.

### Queues

ScanPrint requires separate configured queue names for:
- Simplex
- Duplex

At startup, ScanPrint lists the available CUPS queues in the app log. This makes queue-name mistakes easier to diagnose.

### Defaults

`copies_default` and `print_mode_default` are initial values. Runtime choices made through Home Assistant are stored persistently in `/data`.

## Scanner configuration

A scanner only needs to be able to write PDFs over SMB.

Typical targets:

```text
\\HOMEASSISTANT\share\scanprint\simple
\\HOMEASSISTANT\share\scanprint\duplex
\\HOMEASSISTANT\share\scanprint\multicopy
```

PDF is currently the expected input format.

## Startup checks

Before normal operation ScanPrint checks:

- configuration values
- `/share/scanprint` write access
- MQTT reachability
- CUPS reachability
- Simplex queue existence
- Duplex queue existence
- detectable long-edge duplex capability

The app also lists all available CUPS queues.

Mandatory failures stop ScanPrint instead of silently accepting scanner files that cannot be printed.

## Failed jobs

If CUPS rejects a print submission, ScanPrint moves the PDF to:

```text
/share/scanprint/failed
```

The filename receives a timestamp.

The failed-file counter is exposed to Home Assistant as:

```text
sensor.scanprint_failed_count
```

## File handling

ScanPrint waits for a PDF file size to become stable before submitting it to CUPS.

After successful CUPS submission, the source PDF is deleted.

A successful job means that CUPS accepted the print request. It does not guarantee that paper physically exited the printer.

ScanPrint is therefore a copy workflow, not a document archive.

## Home Assistant OS notes

- ScanPrint requires the Supervisor/App environment.
- `/share` is mounted read/write into the app.
- MQTT credentials are supplied through the Supervisor service.
- App configuration is handled through the Home Assistant UI.
- Persistent runtime state is stored in `/data`.
- Normal Home Assistant app backups can therefore protect app configuration/state.
- CUPS and Samba should remain restricted to the trusted local network.

## Updating

When a new ScanPrint version is released:
1. refresh the Home Assistant App Store if necessary,
2. open ScanPrint,
3. install the offered update,
4. review the changelog,
5. verify the startup precheck log.

The GitHub repository is the source of truth for repository-based installations.

## Troubleshooting

### Queue not found

Example:

```text
FEHLER: Simplex-Queue 'Printer_Simplex' nicht gefunden
```

Check the list of available CUPS queues printed immediately before the error and copy the exact queue name into ScanPrint configuration.

### CUPS not reachable

Check:
- hostname/IP address,
- port 631,
- CUPS app/server status,
- network accessibility.

### MQTT not reachable

Ensure that a Supervisor-provided MQTT service such as Mosquitto Broker is installed and running.

### Duplex not detected

ScanPrint looks for `DuplexNoTumble`, representing long-edge duplex printing.

If the printer itself has duplex disabled in its device settings, enabling it only in CUPS may not be sufficient.

### Files remain in `failed`

Review the ScanPrint app log and CUPS queue state. Failed files are intentionally preserved for manual inspection or reprocessing.

## Security

Recommended:
- do not expose CUPS directly to the Internet
- do not expose Samba directly to the Internet
- use dedicated scanner SMB credentials
- use a trusted LAN or VPN
- protect Home Assistant with normal backups

## Tested setup

Initial development and testing:

- Home Assistant OS
- Mosquitto Broker
- Samba Share
- CUPS / IPP Everywhere
- Canon imageFORMULA DR-S130
- HP LaserJet M209dw
- amd64

Other SMB-capable scanners and CUPS-compatible printers may work but have not necessarily been tested.

## Current limitations

- PDF input expected
- one multicopy document per button press
- no dedicated ScanPrint web UI
- no automatic CUPS queue creation
- physical print completion is not verified
- only `amd64` currently listed in `arch`

## Project status

ScanPrint is currently beta software.

## License

MIT License. See `LICENSE`.

## Disclaimer

Independent community project. Not affiliated with or endorsed by Canon, HP, Home Assistant, OpenPrinting, or CUPS.
