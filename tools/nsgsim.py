#!/usr/bin/env python3
"""
nsgsim.py — decide whether an NSG allows a given flow, the way Azure does:
rules sorted by priority, first match wins, then the default rules.

Graders use this so they assert BEHAVIOUR ("443 from Internet reaches the
subnet") instead of the shape of any particular fix — add an allow rule,
narrow the deny, either passes.

Usage:
    az network nsg show -g $RG -n $NSG --query securityRules -o json > rules.json
    python3 nsgsim.py rules.json --direction Inbound --protocol Tcp \
        --port 443 --source Internet
Prints "Allow" or "Deny" and exits 0 for Allow, 1 for Deny, 2 on bad input.

Simplifications (fine for grading: tasks always test Internet->subnet flows):
    * source matching understands *, Internet, 0.0.0.0/0 and CIDR prefixes;
      the Internet "source" is modelled as an arbitrary public IP.
    * default inbound rules are modelled as: AllowVnetInBound,
      AllowAzureLoadBalancerInBound, DenyAllInBound (65500).
"""
import ipaddress
import json
import sys

PUBLIC_PROBE_IP = ipaddress.ip_address("203.0.113.10")  # TEST-NET-3: "some internet host"

def port_matches(port, ranges):
    for r in ranges:
        r = str(r)
        if r == "*":
            return True
        if "-" in r:
            lo, hi = r.split("-", 1)
            if int(lo) <= port <= int(hi):
                return True
        elif int(r) == port:
            return True
    return False

def source_matches(source, prefixes):
    for p in prefixes:
        p = str(p)
        if p == "*":
            return True
        if source == "Internet":
            if p == "Internet":
                return True
            try:
                if PUBLIC_PROBE_IP in ipaddress.ip_network(p, strict=False):
                    return True
            except ValueError:
                continue  # service tags other than Internet don't cover it
        elif p == source:
            return True
    return False

def rule_prefixes(rule, single, plural):
    vals = []
    if rule.get(single):
        vals.append(rule[single])
    vals += rule.get(plural) or []
    return vals

def evaluate(rules, direction, protocol, port, source):
    live = [r for r in rules if r.get("direction") == direction]
    for r in sorted(live, key=lambda r: r.get("priority", 65000)):
        if r.get("protocol", "*") not in ("*", protocol):
            continue
        if not port_matches(port, rule_prefixes(r, "destinationPortRange", "destinationPortRanges")):
            continue
        if not source_matches(source, rule_prefixes(r, "sourceAddressPrefix", "sourceAddressPrefixes")):
            continue
        return r.get("access", "Deny")
    # default rules: traffic from the Internet falls through to DenyAllInBound
    if direction == "Inbound" and source in ("VirtualNetwork", "AzureLoadBalancer"):
        return "Allow"
    return "Deny"

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__.strip())
        sys.exit(2)
    path = args[0]
    opt = {"--direction": "Inbound", "--protocol": "Tcp",
           "--port": None, "--source": "Internet"}
    for i in range(1, len(args) - 1, 2):
        if args[i] not in opt:
            print(f"nsgsim: unknown option {args[i]}", file=sys.stderr)
            sys.exit(2)
        opt[args[i]] = args[i + 1]
    if opt["--port"] is None:
        print("nsgsim: --port is required", file=sys.stderr)
        sys.exit(2)
    try:
        rules = json.load(open(path)) or []
    except (OSError, json.JSONDecodeError) as e:
        print(f"nsgsim: cannot read rules: {e}", file=sys.stderr)
        sys.exit(2)
    verdict = evaluate(rules, opt["--direction"], opt["--protocol"],
                       int(opt["--port"]), opt["--source"])
    print(verdict)
    sys.exit(0 if verdict == "Allow" else 1)

if __name__ == "__main__":
    main()
