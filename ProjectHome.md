# OpenFPC (Full Packet Capture) project #


## OpenFPC hosting has now moved to Github ##

https://github.com/leonward/OpenFPC
Please go find the latest release there.

Keeping the content on googlecode for a historic view.


---


OpenFPC is a set of scripts that combine to provide a lightweight full-packet network traffic recorder & buffering tool. It's design goal is to allow non-expert users to deploy a distributed network traffic recorder on COTS hardware while integrating into existing alert and log tools.

OpenFPC is described as lightweight because it follows a different design model to other FPC/Network traffic forensic tools that I have seen. It doesn't provide a user with the ability to trigger automatic events (IDS-like functions), or watch for anomalous traffic changes (NBA-like functions) as it is assumed external open source, or comercial tools already provide this detection capability. OpenFPC fits in as a companion to provide extra (full packet/traffic stream) data as a bolt-on to these tools allowing deeper analysis of event data where required.

Simply give it a logfile entry in one of the supported formats, and it will provide you with the PCAP.

For more information, visit the OpenFPC project home at http://www.openfpc.org

## Features and futures ##

  * Automated install on Debain and RH style distributions
  * Extraction of single streams based on event occurrence time, or start/end timestamps
  * Extracts stream data based on common logfile/alert formats
**Distributed collection with central extraction**  Optional compression and extract checksums
**Ability to request data from external tools/user interfaces**

## TODO ##

  * Central web-based UI for stream/data extraction from distributed remote storage buffers
  * Automatic calculation of an optimal configuration for extraction speed based on available storage.
