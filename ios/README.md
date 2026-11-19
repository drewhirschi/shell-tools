# ios-install

Build a signed Release app on a build Mac and install it on the iPhone, from
Linux, for any iOS project. Replaces the per-repo copies (`daily_mirror`'s
`scripts/install-iphone.sh`, the manual steps in fin-stream's
`ios/REMOTE-INSTALL.md`).

```sh
ios-install doctor               # are the Macs, the phone and the tools ready?
ios-install doctor trustdeeds    # same, plus that project's checkout and last build
ios-install -n trustdeeds        # read-only checks, then print every command
ios-install trustdeeds           # sync, build, verify, install, launch
ios-install dailymirror --host jsn
ios-install trustdeeds --source ~/.herdr/worktrees/fin-stream/some-branch
ios-install trustdeeds --skip-sync --skip-build      # reinstall the last build
ios-install trustdeeds --no-install                  # build and verify only
```

`ios-install --help` lists every option.

## What it does

1. **Picks a build Mac.** Asks each of `HOSTS` (default `terakar`, `jsn`) for
   its `devicectl` device list and takes the first that shows the phone as
   available. `--host` forces one.
2. **Syncs source** with rsync. Build output, `.git`, `xcuserdata` and `.env*`
   are never sent, and nothing on the Mac is deleted.
3. **Runs the project's `PREBUILD`** (for example `npm ci` and `pod-install`)
   over plain ssh.
4. **Builds signed Release in the Mac's desktop session.** `codesign` over ssh
   fails with `errSecInternalComponent` because the login keychain is only
   unlocked for the logged-in desktop. The build runs as a one-off LaunchAgent
   in `gui/<uid>` with no `KeepAlive`, and is booted out when it finishes. It
   targets `generic/platform=iOS`, so it does not depend on the phone, and it
   passes `-allowProvisioningUpdates`. The script polls with short ssh calls, so
   a dropped connection does not affect the build. Log:
   `~/.cache/ios-install/<project>/build.log` on the Mac.
5. **Verifies** the signature, the embedded profile and the bundle id, prints
   the entitlements, and fails if any of `REQUIRE_ENTITLEMENTS` is missing.
6. **Starts the CoreDevice tailnet bridge only if needed**, that is, when the
   chosen Mac is paired with the phone but does not list it as available.
7. **Installs over the existing app and launches it.** Same bundle id plus
   compatible signing keeps the app's data; never uninstall first.

Nothing is hard-coded about the network. The Mac's LAN address comes from its
default route, the device identifiers from `devicectl`, the phone's Tailscale
address from `tailscale status`, and its LAN address, advert and tunnel ports
from a fresh `avahi-browse` and port probe.

## The bridge

`coredevice-tailnet-bridge.py` runs on the Mac. It republishes the phone's
`_remotepairing._tcp` advert there and relays the phone's tunnel ports to its
Tailscale address, so a Mac on another network can install. It needs:

- the phone **already paired** with that Mac (the bridge relays a pairing, it
  cannot create one),
- the phone unlocked and on the same LAN as the machine running `ios-install`,
  which is where the advert is captured,
- Tailscale connected on the phone.

The advert's instance id and `authTag` rotate every few minutes, so the script
captures them immediately before starting the bridge. The bridge is stopped
when the install finishes or the script exits.

## Project config

A project is a small bash file: either `ios/projects/<name>.conf` here, or
`.ios-install.conf` in the project's own repo (found by walking up from the
current directory, with `LOCAL_ROOT` defaulting to that repo).

| Variable | Meaning |
|---|---|
| `LOCAL_ROOT` | Local checkout. `--source` overrides it. |
| `SYNC` | Paths under `LOCAL_ROOT` to rsync. `dir/` sends the contents, `dir` the directory. |
| `SYNC_EXCLUDES` | Extra rsync excludes. |
| `REMOTE_DIR` | Sync destination, relative to the Mac's home. |
| `XCODE_DIR` | Where `xcodebuild` runs, relative to `REMOTE_DIR` (default `.`). |
| `PROJECT` or `WORKSPACE` | The Xcode container. |
| `SCHEME`, `BUNDLE_ID` | Required. |
| `PRODUCT` | App bundle name (default `$SCHEME.app`). |
| `DERIVED_DATA` | Relative to `XCODE_DIR` (default `build-device`). |
| `PREBUILD` | Shell run in `REMOTE_DIR` before the build. |
| `XCODEBUILD_ARGS` | Extra `xcodebuild` arguments. |
| `REQUIRE_ENTITLEMENTS` | Entitlement keys the signed app must carry. |
| `HOSTS`, `SSH_USER`, `TEAM`, `DEVICE`, `PHONE_TAILSCALE` | Defaults: `(terakar jsn)`, `drew`, `C9P58ZP4AQ`, `drew-25`, the only iOS Tailscale peer. |

## Requirements

Here: `ssh`, `rsync`, `python3`, plus `tailscale` and `avahi-browse` for the
bridge. On the Mac: Xcode at `/Applications/Xcode.app`, a logged-in desktop
session, an Apple account in Xcode for automatic signing, and the phone paired
once (USB or shared Wi-Fi).

## Status

Verified on November 18, 2026 against terakar and jsn: `doctor`, `--dry-run`
for both projects, and the verify step against an existing Trust Deeds build.
Not yet exercised end to end from this script: the LaunchAgent build, the
bridge start, and the install. The `dailymirror` config uses a new
`build-device` derived-data directory, so its first build is a full one.
