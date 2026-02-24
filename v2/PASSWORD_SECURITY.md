# Password Handling & Security

This document describes how ThinLinc Connection Manager handles passwords,
the design decisions behind it, and an honest assessment of the security
properties. This is current as of version 2.0, Feb. 24 2026.

## Overview

When a user opts to save a password, the following chain executes:

```
User enters password
        |
        v
KeychainHelper.save()
        |
        v
/usr/bin/security add-generic-password  -->  macOS login Keychain
        |                                         (encrypted at rest)
        |
        v
    [on Connect]
        |
        v
askpass script written to ~/.thinlinc/askpass_<name>.sh
        |
        v
tlclient launched with: -C <config> -P <askpass_script>
        |
        v
tlclient executes askpass_script
        |
        v
/usr/bin/security find-generic-password -w  -->  password to stdout
        |
        v
tlclient reads password from stdout, logs in
```

## Where the password lives

| Location | Contains password? | Details |
|---|---|---|
| macOS login Keychain | Yes (encrypted) | Stored under service `ThinLincConnectionManager`, keyed by connection UUID |
| `connections.json` (Dropbox-synced or local) | No | Never contains passwords. Only server, username, auth type |
| `tlclient_<name>.conf` config file | No | Contains server, username, auth method. Never the password |
| `askpass_<name>.sh` script | No | Contains a `security find-generic-password` command referencing the UUID, not the password itself |
| Process command line (`ps`) | No | The `-P` flag points to the askpass script path, not the password |
| Application memory | Briefly | The password exists in the Swift `@State` variable while the edit sheet is open, and transiently in `KeychainHelper.save()` argument |

## What is secure

**Keychain encryption at rest.** The macOS login Keychain encrypts all
stored passwords using the user's login password as the key. The
encrypted database lives at `~/Library/Keychains/login.keychain-db`.
When the Mac is powered off or the user is logged out, the passwords
are inaccessible without the login password.

**No password in config files.** The ThinLinc config file
(`tlclient_<name>.conf`) never contains the password.

**No password on the command line.** ThinLinc's `-p <password>` flag
would expose the password to any process that can read `/proc` or run
`ps`. This uses `-P <askpass_script>` instead, which only exposes the
script path.

**No password in synced files.** The `connections.json` file syncs via
Dropbox. It contains connection metadata only. Passwords stay local in
the Keychain and do not sync between machines.

**Askpass script contains no secrets.** The script at
`~/.thinlinc/askpass_<name>.sh` contains only:

```bash
#!/bin/bash
security find-generic-password -s "ThinLincConnectionManager" -a "<UUID>" -w
```

This is a reference to a Keychain entry, not the password itself.
Anyone reading the script learns the UUID but cannot retrieve the
password without being logged in as the user.

## What is NOT secure (known limitations)

**Password passes through `security` CLI arguments.** When saving,
`KeychainHelper` runs:

```
/usr/bin/security add-generic-password -s ... -a ... -w <PASSWORD> -U
```

The password appears as a command-line argument to the `security`
process. For a brief moment, it is visible to other processes owned by
the same user via `ps aux`. This is inherent to using the `security`
CLI rather than the Security.framework API.The CLI is used because
Security.framework's `SecItemAdd` creates Keychain entries with ACLs
that prevent the askpass script from reading them back (the
`security` CLI needs to be the creator to have implicit trust). This needs further work, maybe this can be overcome.

**Askpass script is readable by the user.** The script at
`~/.thinlinc/askpass_<name>.sh` has mode `0700` (owner-only). Any
process running as the same user can read and execute it, which would
retrieve the password from Keychain. This is equivalent to the
security of the Keychain itself -- any process running as the logged-in
user can call `security find-generic-password` directly.

**Password passes through tlclient's stdin/pipe.** When tlclient
executes the askpass script, the password flows through a pipe from the
script's stdout to tlclient. This is a standard Unix IPC mechanism and
is not visible to other processes, but the password exists in kernel
pipe buffers briefly.

**No per-application Keychain access control.** Because `security` CLI (not Security.framework) is used, the Keychain entry's ACL
trusts `/usr/bin/security` as the creating application. Any process
that can invoke `/usr/bin/security` as the current user can read the
password. This is the same trust boundary as the login Keychain itself.

**Login Keychain is unlocked while logged in.** macOS automatically
unlocks the login Keychain when the user logs in. Passwords are
accessible to any process running in the user's session without further
authentication. This is standard macOS behavior and applies to all
login Keychain items (including those stored by Safari, Mail, etc.).

## Why this design

Three approaches were evaluated for passing the password to tlclient:

1. **`-p <password>` (command-line argument)** -- Rejected. The
   password is visible in `ps` output for the entire lifetime of the
   tlclient process.

2. **`PASSWORD=<hex>` in the config file** -- Rejected. Even with
   `REMOVE_CONFIGURATION=1` (which tells tlclient to delete the config
   after reading), the password exists on disk in cleartext temporarily.
   On SSDs, the data may persist in wear-leveling blocks.

3. **`-P <askpass_script>` (chosen)** -- The password never touches
   the filesystem. It flows from Keychain through a pipe directly into
   tlclient's memory. The only moment the password appears as a CLI
   argument is during the one-time `security add-generic-password` call
   when saving.

## Deleting stored passwords

When the user turns off "Save to macOS Keychain" in the connection
editor, `KeychainHelper.delete(for:)` removes the Keychain entry
immediately. When a connection is switched from Password to Key auth,
any stored password is also deleted. When a connection is deleted
entirely from the app, the Keychain entry should be cleaned up as well.
