# Wi-Fi Security & Privacy

Securing your Wi-Fi connection is a fundamental step in protecting your local network traffic and preventing physical tracking.

## Hidden Networks

**Myth**: "Hiding" your SSID (network name) makes you more secure.
**Reality**: Hiding your SSID actually hurts your privacy.

When you hide your network, your router stops broadcasting its name, but it still broadcasts its existence. Authentication requests from your devices (phone, laptop) must now actively shout "Are you there, [MyHiddenNetwork]?" to find it.

- **Privacy Leak**: Your devices will constantly broadcast the name of your hidden network wherever you go, potentially revealing your home network name to anyone listening at coffee shops, airports, etc.
- **No Security Benefit**: Anyone with a Wi-Fi scanner can still see the network and its traffic.

**Recommendation**: Do NOT hide your network. Use a generic name (e.g., "Network" or "BlueHouse") that doesn't identify you personally.

## MAC Address Randomization

Your MAC address is a unique hardware identifier assigned to your Wi-Fi card. It can be used to track your physical location as you move between Wi-Fi access points.

- **Tracking**: Retailers and advertisers use Wi-Fi probes to track how long you stay in a store and where you move.
- **Solution**: "Spoofing" or randomizing your MAC address makes it harder to link your activity to a single device over time.

**Better-Anonymity Tool**:
Use the `wifi spoof-mac` command to assign a random, valid unicast MAC address to your interface before connecting to a public network.

```bash
better-anonymity wifi spoof-mac
```

*Note: This will temporarily disconnect you from the network.*

**Automated Event-Driven Spoofing (Daemon)**:
If you want to automate this process so that your MAC address is mathematically scrambled every single time your computer boots up, wakes from sleep, or connects to a new network environment, install the background LaunchDaemon:

```bash
better-anonymity wifi daemon-on
```

To safely remove the daemon and restore normal static MAC behavior:

```bash
better-anonymity wifi daemon-off
```

**LinkLiar GUI Tool**:
For users who prefer a graphical interface or want persistent MAC address spoofing rules managed beautifully in the macOS menu bar, LinkLiar is excellent. You can install it via the CLI:

```bash
better-anonymity install linkliar
```

## Encryption: WPA2 vs WPA3

- **WEP**: Obsolete and insecure. Never use.
- **WPA2**: Currently the standard, but vulnerable to offline dictionary attacks if your password is weak.
- **WPA3**: The modern standard. It uses "Simultaneous Authentication of Equals" (SAE) which makes it immune to offline dictionary attacks, meaning even a weak password is much reduced in risk (though you should still use a strong one!).

**Recommendation**:

- Use **WPA3-Personal** (SAE) if your router supports it.
- If not, use **WPA2-AES** with a long, strong passphrase.
- Avoid **WPA/WPA2-TKIP** (mixed mode) if possible as TKIP is insecure.

## Auditing Connection

You can audit your current connection security with:

```bash
better-anonymity wifi audit
```

This will display the SSID and encryption type (e.g., WPA2, WPA3).
