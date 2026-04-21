# Week 4 VM Lab

This folder contains the code used for the coursework demo.

- `cw1`: attack replay, HTTP burst, mock thermostat, and Snort rules
- `cw2`: defended thermostat with API-key protection, rate limiting, lockout, and Snort monitoring

The lab is meant to run inside an Ubuntu VM on a private or host-only network.

## Data

The attack inputs are the Week 4 PCAP files:

- `SYN.pcap`
- `udp_flood.pcap`
- `dns.pcap`
- `ip_fragmented.pcap`

Copy them into `~/week4-lab/pcaps/` inside the VM before replaying traffic.

## Setup

Inside the Ubuntu VM:

1. Run `ubuntu/setup_lab.sh`
2. Check the interface name with `ip addr`
3. Apply the rules with `ubuntu/snort/apply_local_rules.sh <interface>`

## CW1 quick run

For the attack demo:

- `bash run-demo.sh`
- `bash show-demo-results.sh`

You can also run the pieces manually from `ubuntu/demo/`, for example:

- `start_mock_thermostat.sh`
- `http_burst_demo.sh`
- `icmp_burst_demo.sh`
- `replay_syn.sh`
- `replay_udp.sh`

## CW2 quick run

For the defence demo:

- `bash run-defense-demo.sh`
- `bash show-defense-results.sh`

The defended service is implemented in `ubuntu/demo/defended_thermostat.py`.
The Snort rules are in `ubuntu/snort/local.rules`.

## Output

Collected outputs are written to `evidence/`.

This includes:

- service responses
- Snort console logs
- thermostat logs
- metrics and summary files

## Notes

- Use only private or host-only IP ranges.
- Do not run the traffic generators against public targets.
- The `report/` folder is only draft writing support and is not needed to run the demo.
