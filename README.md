# Description
This is an extremely crude network stack implementation. Included in this implementation are the following:
- On startup nodes will broadcast to all addresses and await responses and build a list of its own neighbors.
- Next each node floods the networks with information regarding itself, its neighbors, and number of hops to get to each neighbor.
- At the end of the link state flooding each node has a complete routing table.
- At this point nodes are able to send messages back and forth via a (crude) TCP implementation.

# Requirements
- TinyOS

# Usage
1. Clone this repo and mount it to TinyOS.
2. Inside the repo run `make micaz sim`.
3. run `python TestSim.py`.

To edit/add triggers look insdie `TestSim.py`.
