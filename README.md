

```
 __    __  __   _____        _   _____ 
/ _\  /__\/__\ /__   \/\  /\/_\ /__   \
\ \  /_\ /_\     / /\/ /_/ //_\\  / /\/
_\ \//__//__    / / / __  /  _  \/ /   
\__/\__/\__/    \/  \/ /_/\_/ \_/\/    

  ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋
   Advanced Port Scanner  | S E E  T H A T |  v1.0
  ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋
   Author: SYED SAMEER UL HASSAN  |  License: Apache 2.0
```

> **SEE THAT** is a pure-bash, zero-dependency advanced port scanner with parallel scanning, banner grabbing, service fingerprinting, wifite2-style interactive controls, and JSON/TXT output. Built for CCT-certified security professionals.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Folder Structure](#folder-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [How It Works](#how-it-works)
- [Scan Modes](#scan-modes)
- [Usage](#usage)
- [Flag Reference](#flag-reference)
- [Controls During a Scan](#controls-during-a-scan)
- [Output Formats](#output-formats)
- [Scan Mode Decision Chart](#scan-mode-decision-chart)
- [Architecture Diagram](#architecture-diagram)
- [Scan Flow](#scan-flow)
- [Service Fingerprint Map](#service-fingerprint-map)
- [Timing Profiles](#timing-profiles)
- [Examples](#examples)
- [Legal Notice](#legal-notice)
- [License](#license)

---

## Overview

SEE THAT gives you full visibility into what ports are open on any target — without needing nmap, python, or any external tool for basic TCP/UDP scanning. It uses pure bash `/dev/tcp` sockets for TCP, `nc` for UDP, and optionally delegates to `nmap` only for stealth SYN mode.

```mermaid
graph LR
    A[You run seethat.sh] --> B{Scan Mode?}
    B -->|tcp| C[Pure Bash /dev/tcp]
    B -->|udp| D[netcat UDP]
    B -->|both| E[TCP + UDP parallel]
    B -->|service| F[TCP + Banner Grab]
    B -->|stealth| G[nmap SYN scan]
    C --> H[Results]
    D --> H
    E --> H
    F --> H
    G --> H
    H --> I{Output?}
    I -->|-o file.txt| J[Plain Text Report]
    I -->|-o file.json| K[JSON Report]
    I -->|no flag| L[Terminal Display]
```

---

## Features

| Feature | Detail |
|---|---|
| Pure-bash TCP scan | No tools needed — uses `/dev/tcp` sockets |
| UDP scan | Via `nc -zu` |
| Banner grabbing | HTTP HEAD + raw socket grab |
| Service fingerprinting | 60+ built-in port-to-service mappings |
| Parallel scanning | Configurable thread pool (10–500 jobs) |
| wifite2-style controls | Ctrl+C pauses, does not quit |
| No-stop mode | `-n` flag disables Ctrl+C entirely |
| JSON output | Machine-readable results |
| TXT output | Human-readable report |
| Stealth SYN mode | Delegates to nmap when available |
| Live progress bar | Port rate, open count, elapsed time |
| Colour-coded terminal | Full ANSI colour output |

---

## Folder Structure

```
SEE_THAT/
├── README.md        
|── LICENSE
└── see_that.sh       
```

---

## Requirements

| Requirement | Used for | Install |
|---|---|---|
| `bash` 4.0+ | Core script runtime | Pre-installed on Linux/macOS |
| `nc` (netcat) | UDP scanning, banner grabbing | `apt install netcat` |
| `ping` | Host reachability check | Pre-installed |
| `tput` | Terminal cursor control | Pre-installed |
| `nmap` *(optional)* | Stealth SYN mode only | `apt install nmap` |
| `root / sudo` *(optional)* | UDP + stealth modes | — |

> For TCP scanning and service mode — no extra tools are needed at all.

---

## Installation

```bash
git clone https://github.com/yourrepo/see-that.git
cd "SEE THAT"
chmod +x seethat.sh
./seethat.sh -h
```

Or download just the script:

```bash
curl -O https://raw.githubusercontent.com/yourrepo/see-that/main/seethat.sh
chmod +x seethat.sh
```

---

## How It Works

SEE THAT builds a list of ports from your `-p` argument, then fires parallel background jobs — up to the thread limit you set with `-T`. Each job attempts a connection and reports back. A live progress bar updates in place using `\r` carriage returns.

```mermaid
sequenceDiagram
    participant User
    participant Script
    participant Target

    User->>Script: ./seethat.sh -t 192.168.1.1 -p 1-1024 -m service
    Script->>Script: Parse args, validate target
    Script->>Target: ping -c1 (reachability check)
    Target-->>Script: response / timeout
    loop For each port in range
        Script->>Target: /dev/tcp connect (TCP)
        Target-->>Script: open / refused
        alt Port is open
            Script->>Target: Banner grab (nc HEAD request)
            Target-->>Script: Banner string
            Script->>User: [OPEN] port  service  banner
        end
    end
    Script->>User: Summary table
    Script->>User: Save to file (if -o used)
```

---

## Scan Modes

```mermaid
graph TD
    A[Choose Scan Mode] --> B[tcp]
    A --> C[udp]
    A --> D[both]
    A --> E[service]
    A --> F[stealth]

    B --> B1["Pure bash /dev/tcp\nFastest, no root needed\nTCP only"]
    C --> C1["nc -zu UDP probe\nRoot recommended\nUDP only"]
    D --> D1["TCP + UDP simultaneously\nParallel jobs\nBroadest coverage"]
    E --> E1["TCP connect + banner grab\nService identification\nHTTP HEAD request"]
    F --> F1["nmap SYN -sS\nRequires root + nmap\nStealthy, no full handshake"]
```

### Mode Comparison

| Mode | Speed | Root Needed | Tool Needed | Best For |
|---|---|---|---|---|
| `tcp` | ⚡⚡⚡⚡⚡ | No | None | Quick recon |
| `udp` | ⚡⚡ | Recommended | nc | UDP service discovery |
| `both` | ⚡⚡⚡ | Recommended | nc | Full port sweep |
| `service` | ⚡⚡⚡ | No | nc | Service ID + banners |
| `stealth` | ⚡⚡⚡⚡ | Yes | nmap | Low-noise SYN scan |

---

## Usage

```bash
./seethat.sh [OPTIONS]
```

### Basic TCP scan

```bash
./seethat.sh -t 192.168.1.1
```

### Full port range with service detection

```bash
./seethat.sh -t 192.168.1.1 -p 1-65535 -m service -T 4
```

### Top 100 common ports, fast, save JSON

```bash
./seethat.sh -t 10.0.0.1 -p top100 -T 5 -o results.json
```

### UDP scan as root

```bash
sudo ./seethat.sh -t 192.168.1.1 -p 1-1024 -m udp
```

### Stealth SYN scan (nmap under the hood)

```bash
sudo ./seethat.sh -t 192.168.1.1 -p 1-1024 -m stealth
```

### No-stop mode (run to completion, no pause on Ctrl+C)

```bash
./seethat.sh -t 192.168.1.1 -p 1-65535 -n -o full_scan.txt
```

### Verbose (show closed ports too)

```bash
./seethat.sh -t 192.168.1.1 -p 80-500 -v
```

---

## Flag Reference

| Flag | Argument | Default | Description |
|---|---|---|---|
| `-t` | `<ip/hostname>` | — | **Required.** Target to scan |
| `-p` | `<range>` | `1-1024` | Port range. Use `80`, `22-443`, `1-65535`, or `top100` |
| `-m` | `<mode>` | `tcp` | Scan mode: `tcp` `udp` `both` `service` `stealth` |
| `-T` | `1–5` | `3` | Timing/threads profile (see table below) |
| `-o` | `<filename>` | — | Save output. `.txt` or `.json` extension |
| `-v` | — | off | Verbose: also print closed ports |
| `-n` | — | off | No-stop mode: disable Ctrl+C interrupt |
| `-h` | — | — | Show help and exit |

---

## Controls During a Scan

SEE THAT works like **wifite2** — pressing `Ctrl+C` does **not** kill the scan. Instead it opens an interactive pause menu:

```
  ╔══════════════════════════════════════╗
  ║   SEE THAT — Scan Paused                    ║
  ╠══════════════════════════════════════╣
  ║  [r]  Resume scan                           ║
  ║  [s]  Stop and show results                 ║
  ║  [q]  Quit immediately                      ║
  ╚══════════════════════════════════════╝
  Choice:
```

| Key | Action |
|---|---|
| `r` | Resume the scan from where it paused |
| `s` | Stop gracefully and print the results table |
| `q` | Exit immediately |
| *(anything else / timeout)* | Resume automatically |

> Use `-n` flag to disable Ctrl+C entirely for unattended / automated scans.

---

## Output Formats

### Terminal (default)

Colour-coded live output with a progress bar:

```
  [████████████████░░░░░░░░░░░░░░░░░░░░░░░░]  42%  Port: 430    Open: 3    Rate: 88/s  Elapsed: 5s

  [OPEN]  22      TCP    SSH
  [OPEN]  80      TCP    HTTP
  [OPEN]  443     TCP    HTTPS
```

### Text file (`-o results.txt`)

```
SEE THAT Results — Tue Jun 16 12:00:00 UTC 2026
Target: 192.168.1.1 | Mode: service | Range: 1-1024
-----------------------------------------------
22/tcp  OPEN  SSH
80/tcp  OPEN  HTTP
443/tcp OPEN  HTTPS
```

### JSON file (`-o results.json`)

```json
{
  "target": "192.168.1.1",
  "scan_mode": "service",
  "port_range": "1-1024",
  "timestamp": "2026-06-16T12:00:00Z",
  "open_ports": [
    {"port": 22, "service": "SSH"},
    {"port": 80, "service": "HTTP"},
    {"port": 443, "service": "HTTPS"}
  ]
}
```

---

## Scan Mode Decision Chart

```mermaid
flowchart TD
    Start([Start]) --> Q1{Do you have root?}
    Q1 -->|No| Q2{Need service info?}
    Q1 -->|Yes| Q3{Want stealth?}
    Q2 -->|Yes| M_service[Use: -m service]
    Q2 -->|No| M_tcp[Use: -m tcp]
    Q3 -->|Yes| M_stealth[Use: -m stealth]
    Q3 -->|No| Q4{Need UDP too?}
    Q4 -->|Yes| M_both[Use: -m both]
    Q4 -->|No| Q5{Need service info?}
    Q5 -->|Yes| M_service2[Use: -m service]
    Q5 -->|No| M_tcp2[Use: -m tcp]

    style M_service fill:#2d6a2d,color:#fff
    style M_service2 fill:#2d6a2d,color:#fff
    style M_tcp fill:#1a4a7a,color:#fff
    style M_tcp2 fill:#1a4a7a,color:#fff
    style M_stealth fill:#6a2d6a,color:#fff
    style M_both fill:#7a4a00,color:#fff
```

---

## Architecture Diagram

```mermaid
graph TB
    subgraph Input
        A[CLI Flags] --> B[parse_args]
        B --> C[validate]
    end

    subgraph Core Engine
        C --> D[run_scan]
        D --> E{Mode?}
        E -->|tcp/service/both| F[scan_tcp_port\n/dev/tcp socket]
        E -->|udp/both| G[scan_udp_port\nnc -zu]
        E -->|stealth| H[run_stealth_scan\nnmap -sS]
        F -->|open| I[print_open_port]
        G -->|open| I
        H -->|open| I
        I -->|service mode| J[grab_banner\nnc HEAD request]
        J --> I
    end

    subgraph Parallelism
        D --> K[Background Jobs Pool]
        K --> L[Thread Limiter\nactive_jobs limit]
        L --> M[wait builtin\nbatch sync]
    end

    subgraph Controls
        N[Ctrl+C trap] --> O[handle_interrupt]
        O --> P[pause_menu]
        P -->|r| D
        P -->|s| Q[print_summary]
        P -->|q| R[exit 0]
    end

    subgraph Output
        Q --> S[Terminal Table]
        Q --> T{-o flag?}
        T -->|.txt| U[save_results TXT]
        T -->|.json| V[save_results JSON]
    end

    subgraph Services
        W[load_service_map\n60+ port mappings] --> F
        W --> G
        W --> I
    end
```

---

## Scan Flow

```mermaid
stateDiagram-v2
    [*] --> Initialise
    Initialise --> LoadServices : load_service_map
    LoadServices --> ParseArgs : parse_args
    ParseArgs --> Validate : validate
    Validate --> Scanning : run_scan
    Scanning --> Paused : Ctrl+C
    Paused --> Scanning : [r] resume
    Paused --> Summarise : [s] stop
    Paused --> [*] : [q] quit
    Scanning --> Summarise : complete
    Summarise --> SaveFile : -o flag set
    Summarise --> [*] : done
    SaveFile --> [*] : done
```

---

## Service Fingerprint Map

SEE THAT has 60+ built-in port-to-service mappings. No external files needed.

```mermaid
mindmap
  root((SEE THAT\nService Map))
    Web
      80 HTTP
      443 HTTPS
      8080 HTTP-Alt
      8443 HTTPS-Alt
      8888 Jupyter
    Database
      3306 MySQL
      5432 PostgreSQL
      1433 MSSQL
      1521 Oracle
      27017 MongoDB
      6379 Redis
      9200 Elasticsearch
      5984 CouchDB
      9042 Cassandra
    Remote Access
      22 SSH
      23 Telnet
      3389 RDP
      5900 VNC
    Mail
      25 SMTP
      110 POP3
      143 IMAP
      465 SMTPS
      993 IMAPS
      995 POP3S
    File Transfer
      20 FTP-DATA
      21 FTP
      69 TFTP
      873 Rsync
      2049 NFS
    Container / Cloud
      2375 Docker
      2376 Docker-TLS
      6443 Kubernetes
      10250 Kubelet
    Monitoring
      9090 Prometheus
      5601 Kibana
      3000 Grafana
    Messaging
      5672 RabbitMQ
      15672 RabbitMQ-UI
      11211 Memcached
    Directory / Auth
      389 LDAP
      636 LDAPS
      88 Kerberos
      500 IKE
```

---

## Timing Profiles

The `-T` flag controls how aggressively the scanner runs.

```mermaid
xychart-beta
    title "Timing Profile — Threads vs Timeout"
    x-axis ["T1 Slow", "T2 Careful", "T3 Default", "T4 Aggressive", "T5 Insane"]
    y-axis "Threads" 0 --> 550
    bar [10, 50, 100, 200, 500]
```

| Profile | Flag | Threads | Timeout | Best For |
|---|---|---|---|---|
| Slow | `-T 1` | 10 | 3s | Fragile/old targets, IDS evasion |
| Careful | `-T 2` | 50 | 2s | Stable targets, low noise |
| Default | `-T 3` | 100 | 1s | General use |
| Aggressive | `-T 4` | 200 | 1s | Fast internal networks |
| Insane | `-T 5` | 500 | 1s | LAN only, maximum speed |

> On external targets, stick to T1–T3. T5 on a WAN will flood your connection and miss ports.

---

## Examples

### Example 1 — Quick check of a router

```bash
./seethat.sh -t 192.168.1.1 -p top100
```

### Example 2 — Full web server recon with service detection

```bash
./seethat.sh -t 10.10.10.5 -p 1-65535 -m service -T 4 -o webserver.json
```

### Example 3 — Automated scan, no interruptions, save results

```bash
./seethat.sh -t 172.16.0.1 -p 1-1024 -n -o scan_$(date +%F).txt
```

### Example 4 — Stealth SYN scan (needs root + nmap)

```bash
sudo ./seethat.sh -t 192.168.1.100 -p 1-1024 -m stealth -o stealth.txt
```

### Example 5 — Verbose UDP sweep

```bash
sudo ./seethat.sh -t 192.168.1.1 -p 1-500 -m udp -v -T 2
```

### Example 6 — Combined TCP+UDP on a single port

```bash
./seethat.sh -t 192.168.1.1 -p 53 -m both
```

---

## Legal Notice

> **SEE THAT is for authorised security testing only.**
>
> Only scan systems you own or have explicit written permission to test.
> Unauthorised port scanning may violate the Computer Misuse Act 1990 (UK), the CFAA (US), and equivalent laws in your jurisdiction.
>
> The author — Syed Sameer Ul Hassan — accepts no liability for misuse of this tool.

---

## License

```
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [2026] [Syed Sameer Ul Hassan]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```

---

*SEE THAT — Advanced Port Scanner | CCT Edition | v1.0*
