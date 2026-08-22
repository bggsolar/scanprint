# ScanPrint Documentation

## Home Assistant OS reference setup

```text
Home Assistant OS
├── Samba Share
├── Mosquitto Broker
├── CUPS Print Server
└── ScanPrint
```

## Quick start

1. Install and configure CUPS.
2. Ensure a Supervisor-provided MQTT service is available.
3. Add `https://github.com/bggsolar/scanprint` to the Home Assistant App Store repositories.
4. Install ScanPrint.
5. Configure CUPS host, port, Simplex queue and Duplex queue.
6. Start ScanPrint.
7. Verify the startup log.
8. Configure scanner SMB destinations.

## Scanner folders

- `/share/scanprint/simple`
- `/share/scanprint/duplex`
- `/share/scanprint/multicopy`

Failed jobs are stored in:

- `/share/scanprint/failed`

## Diagnostics in Home Assistant

- `binary_sensor.scanprint_ready`
- `sensor.scanprint_multicopy_pending`
- `sensor.scanprint_multicopy_next`
- `sensor.scanprint_failed_count`
- `sensor.scanprint_last_job`

See `README.md` for complete documentation and troubleshooting.
