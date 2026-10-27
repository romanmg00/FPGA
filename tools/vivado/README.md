# Unattended Vivado on Alan's desktop

**Installed and verified 27 October 2026.** Fresh `sudo -n -k` invocations work;
`id` reports UID/GID 1000, `NoNewPrivs` reports 1, and container `sudo` is denied.
The launcher is root-owned mode 0755 and its policy is root-owned mode 0440.
The one-use administrator credential file was removed after installation.

One-time setup, requiring administrator authentication:

```bash
sudo bash tools/vivado/install-unattended.sh
```

This installs a root-owned `/usr/local/sbin/cs256-vivado` and a matching
`/etc/sudoers.d/cs256-vivado` policy. Alan may invoke **only that launcher**
without a password. It starts or executes commands in the existing
`cs256-vivado-ubuntu24` container, pinned to its full ID at setup. It grants no
general Docker daemon access or host root shell. The command runs as UID/GID
1000 with `no_new_privs`, so the container's existing sudo policy cannot elevate
it. It cannot choose another container, add mounts, or pass daemon options.
The installer rejects privileged containers and unexpected mount destinations.

Verify from an ordinary terminal or agent session:

```bash
sudo -n /usr/local/sbin/cs256-vivado status
sudo -n /usr/local/sbin/cs256-vivado exec id
sudo -n /usr/local/sbin/cs256-vivado exec grep NoNewPrivs /proc/self/status
```

The UART experiment's `run.sh --docker` automatically uses this launcher when
installed. Agent shell tools must run the launcher outside their filesystem
sandbox; sandbox approval is separate from sudo authentication and may depend
on the harness policy. There is no interactive credential fallback in that
launcher path.

Generic Vivado invocation:

```bash
sudo -n /usr/local/sbin/cs256-vivado start
sudo -n /usr/local/sbin/cs256-vivado exec bash -c \
  'source /tools/2025.2/Vivado/settings64.sh; source /home/vivado/vivado-runtime.sh; vivado -version'
```

The existing host/container mounts and tool versions remain unchanged. If an
administrator replaces the container, rerun the installer to deliberately pin
the new ID. Preserve the old tools, home and build artifacts first. Remove
`/etc/sudoers.d/cs256-vivado` as administrator to revoke unattended access;
removing the launcher alone leaves an unused policy entry.
