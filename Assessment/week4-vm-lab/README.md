# Assignment

Code for the coursework demo.

- `cw1`: attack replay, HTTP burst, mock thermostat, Snort detection
- `cw2`: defended thermostat with API key, rate limiting, lockout, and Snort monitoring

Run everything inside an Ubuntu VM on a private or host-only network.

## Data

Place these files in `~/week4-lab/pcaps/` inside the VM:

- `SYN.pcap`
- `udp_flood.pcap`
- `dns.pcap`
- `ip_fragmented.pcap`

## Setup

1. Run `ubuntu/setup_lab.sh`
2. Find the interface with `ip addr`
3. Run `ubuntu/snort/apply_local_rules.sh <interface>`

## Run

`cw1`

- `bash run-demo.sh`
- `bash show-demo-results.sh`

`cw2`

- `bash run-defense-demo.sh`
- `bash show-defense-results.sh`

## Files

- `ubuntu/demo/`: attack and defence scripts
- `ubuntu/snort/`: local Snort rules
- `evidence/`: sample outputs from the demo

## Notes

- Use only private or host-only IP ranges.
- Do not target public IPs.
- `report/` is not needed to run the code.
