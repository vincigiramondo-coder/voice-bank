# Security

## Supported release

The native client is tested on Apple Silicon with macOS 14 or later. The separate self-hosted server is tested with Python 3.13.13. Public binary releases must be Developer ID signed and notarized; locally generated ad-hoc packages are test artifacts only.

## Network boundary

The server binds to `127.0.0.1` by default. Non-loopback mode requires a bearer token unless the operator deliberately sets `VOICE_BANK_ALLOW_INSECURE_LAN=1`. Bearer authentication does not encrypt HTTP traffic; use Tailscale/VPN or a TLS reverse proxy and never expose the service directly to the internet.

The native client supports HTTP only for localhost, private LAN ranges, local hostnames, and Tailscale addresses. Public server addresses must use HTTPS. The App Transport Security exception exists solely to support user-configured self-hosted LAN and Tailscale endpoints; endpoint validation prevents ordinary public HTTP targets.

## Sensitive data

Audio uses unique owner-only temporary directories that are removed after processing. The client stores text History under `~/Documents/Voice Bank/History`; delete that directory to remove it. Tokens and endpoint preferences stay in the user's account and must never be committed.

## Dependency advisory note

The 2026-08-11 review identified advisories in `cryptography==49.0.0`, `msgpack==1.2.0`, `setuptools==81.0.0`, and `torch==2.11.0`. The first two are updated in this release to `50.0.0` and `1.2.1`.

PyTorch remains at `2.11.0` because the matching macOS `torchaudio` release available to this runtime is also `2.11.0`; updating Torch alone to `2.13.0` would create an unsupported binary pair. PyTorch 2.11 also requires `setuptools < 82`, which prevents adopting the reported `setuptools` fix in this environment. The reported issues have not been shown reachable through Voice Bank's inference path, but these are explicit temporary exceptions rather than a claim of no risk. Recheck and move the PyTorch/torchaudio pair together, then update setuptools, before a binary release.

## Reporting

Do not include recordings, transcripts, access tokens, private addresses, or home-directory paths in a public issue. Report suspected vulnerabilities privately to the repository owner until a dedicated security contact is published.
