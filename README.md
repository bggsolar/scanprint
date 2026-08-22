# ScanPrint

**Author:** Sascha Baron (`bggsolar`)  
**Status:** Beta  
**License:** MIT  
**Current release:** 0.5.1

ScanPrint is a lightweight Home Assistant OS app that turns a network document scanner and a CUPS-compatible printer into a simple scan-to-copy workflow.

A scanner writes PDF files to folders exposed through the Home Assistant Samba share. ScanPrint monitors these folders and forwards completed PDFs to configured CUPS print queues.

The project was originally developed for a Canon imageFORMULA DR-S130 scanner and an HP LaserJet M209dw printer, but the architecture is not tied to these devices.

## Features

- Automatic PDF printing from a Samba share
- Separate Simplex and Duplex workflows
- Duplex printing on the long edge
- Multiple-copy workflow with selectable copy count
- Selectable Simplex/Duplex mode for multiple copies
- Collated multi-copy printing
- Native Home Assistant entities through MQTT Discovery
- Persistent copy-count and print-mode settings
- Automatic creation of required folders
- Failed-job directory
- CUPS connectivity and queue prechecks
- MQTT availability check
- Writable-share precheck
- Automatic app version reporting in Home Assistant
- No permanent storage required for successfully processed copy jobs

## Architecture

```text
Network scanner
      |
      | SMB / PDF
      v
Home Assistant OS
      |
      +-- Samba Share
      +-- ScanPrint
      +-- CUPS Print Server
                |
                | IPP / CUPS
                v
          Network printer
```

ScanPrint creates and uses:

```text
/share/scanprint/
├── simple/
├── duplex/
├── multicopy/
└── failed/
```

## Workflows

### Simplex
Files written to `/share/scanprint/simple` are printed automatically using the configured Simplex queue.

### Duplex
Files written to `/share/scanprint/duplex` are printed automatically using long-edge duplex printing.

### Multicopy
Files written to `/share/scanprint/multicopy` wait for user confirmation in Home Assistant.

Home Assistant provides:
- copy count: 1–20
- print mode: Simplex or Duplex
- print button
- status entity

If multiple PDFs are waiting, the oldest PDF is processed first. One button press processes one document.

## Home Assistant entities

- `number.scanprint_copies`
- `select.scanprint_mode`
- `button.scanprint_multicopy`
- `sensor.scanprint_status`

## Requirements

- Home Assistant OS / Supervisor apps environment
- MQTT integration and Supervisor-provided MQTT service (e.g. Mosquitto Broker)
- Reachable CUPS server
- Samba Share or another method for the scanner to write PDFs to `/share/scanprint`

## Installation

Add this repository to Home Assistant:

**Settings → Apps → App Store → Repositories**

Then install **ScanPrint** and configure CUPS host, port and queue names.

For local development, copy the `scanprint` directory to:

```text
/addons/scanprint
```

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

## Scanner destinations

Example SMB destinations:

```text
\\HOMEASSISTANT\share\scanprint\simple
\\HOMEASSISTANT\share\scanprint\duplex
\\HOMEASSISTANT\share\scanprint\multicopy
```

PDF is currently the expected input format.

## Startup checks

ScanPrint checks:
- `/share/scanprint` writable
- MQTT reachable
- CUPS reachable
- Simplex queue exists
- Duplex queue exists
- long-edge duplex capability detectable

Mandatory precheck failures stop normal startup.

## Failed jobs

Rejected print jobs are moved to:

```text
/share/scanprint/failed
```

with a timestamp in the filename.

## File handling

ScanPrint waits until a PDF's file size is stable before submitting it to CUPS.

After CUPS successfully accepts a job, the source PDF is deleted. ScanPrint is therefore intended as a copy workflow, not a document archive.

## Security

Recommended:
- do not expose CUPS to the Internet
- do not expose Samba to the Internet
- use dedicated Samba credentials for scanners
- keep the workflow on a trusted local network
- include the app in normal Home Assistant backups

## Tested setup

Initial development/testing:
- Canon imageFORMULA DR-S130
- HP LaserJet M209dw
- Home Assistant OS
- Samba Share
- Mosquitto Broker
- CUPS using IPP Everywhere

Other SMB-capable scanners and CUPS-compatible printers may work but have not necessarily been tested.

## Current limitations

- PDF input expected
- one multicopy document per button press
- no dedicated ScanPrint web UI
- successful completion means CUPS accepted the job, not physical output confirmation
- CUPS queue configuration remains external to ScanPrint
- current architecture list contains `amd64` only

## Project status

ScanPrint is currently beta software.

## License

MIT License. See `LICENSE`.

## Disclaimer

Independent community project. Not affiliated with or endorsed by Canon, HP, Home Assistant, OpenPrinting, or CUPS.
