# Ticket design on unauthenticated ENet — risk review

Short version: the ticket is a **bearer token for one seat**, not an identity, and not a private channel. For LAN and same-machine play behind a ticket gate that is a reasonable trade. For an internet-facing UDP port it is not, yet.

| # | Risk | Severity | What actually happens | Cheapest fix |
|---|---|---|---|---|
| 1 | No confidentiality | High off-LAN | ENet is plain UDP, so the token travels in cleartext. Anyone on-path — shared Wi-Fi, hostile AP, ISP — reads `player_id`, lobby and server ids, and the token itself. | DTLS (`ENetConnection.dtls_*`), or keep the port on LAN until then. Do not describe the ticket as encryption. |
| 2 | Bearer, not proof of possession | High | Nothing binds the token to the peer presenting it. A capture can be raced to the server before the real client arrives; the thief is admitted as that player and the victim is refused. Single-use nonce stops reuse, not first use. | Bind the ticket to an ephemeral key the client proves it owns (hash of the public key in the claims, challenge-response after connect), or complete DTLS before admission. |
| 3 | One shared signing secret | High if leaked | One HMAC key serves the lobby and every game server. A leak anywhere mints tickets for any player on any server, and nothing distinguishes forged from real. | Derive per server: `key_i = HMAC(master, server_id)`. A leaked server key then cannot mint for its siblings. |
| 4 | The gate keeps the seat, not the bandwidth | Medium | ENet finishes its handshake and `peer_connected` fires *before* the ticket check. An unauthenticated peer already occupies 1 of 16 slots and can send RPCs until dropped, so 16 junk connections deny the match to real players without ever holding a ticket. | Admit only if the ticket arrives as the first packet, drop on a strict deadline, and rate-limit connections per IP at the socket/firewall level. |
| 5 | `expected_server_id` defaults to empty | Medium — a real defect | `verify()` treats `""` as "any server". One wiring mistake silently disables server binding with no error. | Make the argument required, or make the "any server" case an explicit `MatchTicket.ANY_SERVER` constant. Fix this before the code lands. |
| 6 | Trusting wall clocks | Medium | Expiry and the 5 s future-skew check compare the lobby's issue time to the server's clock. A server 6 s fast rejects every legitimate ticket; a server slow extends a token's life. | NTP on the host, and record expiry from a monotonic clock at first sight rather than trusting `iat` alone. |
| 7 | Replay cache is in-memory, and prunes on every call | Low | A restart forgets every nonce, so a captured token can be replayed once inside its TTL; `_prune()` walks all stored nonces on each `consume()`. With a 16-player cap the cost is trivial, but it is not free under a connection flood (see #4). | Fine as-is for 16 players; if it grows, prune on a timer and cap the table. |
| 8 | Identity is only as strong as the lobby | Medium | The ticket asserts "the lobby believes this is player N". With anonymous device ids plus an 8-character join code, possession of the code and a ticket is enough to take a seat; two devices can share one code. | Acceptable before accounts exist. Just do not build bans, moderation or ranked ratings on it. |
| 9 | Tokens leaking into logs | Low | Crash dumps, debug prints and network logs can retain a token that is still live for its TTL. | Never log the token, only its first 6 characters or its nonce. |

## Verdict

Keep the design; do not open a port with it yet. TTL, single-use nonces and server binding make an accident unlikely and a stolen seat expensive to repeat — but a stolen seat is still a stolen seat, and #1 and #2 mean capture is enough.

Before any internet exposure: DTLS, per-server derived keys, a required server-id, and possession-bound tickets. #3, #4 and #5 are cheap and belong in the next commit; #1 and #2 are why the plan still says LAN only.

## How sure this is

A design review from the code and the known properties of ENet, not a measured attack. No packet capture or live race has been run, because there is no server to run it against yet.
