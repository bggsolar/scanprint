# ScanPrint Documentation

See the repository `README.md` for installation, configuration, workflows, and limitations.

## Quick start

1. Install and configure a CUPS server.
2. Ensure Home Assistant has an MQTT service available.
3. Install ScanPrint from the repository.
4. Configure:
   - CUPS host
   - CUPS port
   - Simplex queue
   - Duplex queue
5. Configure the scanner to write PDF files to one of:
   - `/share/scanprint/simple`
   - `/share/scanprint/duplex`
   - `/share/scanprint/multicopy`
6. Check the ScanPrint log for successful startup prechecks.

ScanPrint is beta software.
