#!/usr/bin/env bash
# One-time administrator setup for Alan's existing Vivado container.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
if [[ $EUID != 0 ]]; then
    printf 'Run this installer once with sudo; future builds need no password.\n' >&2
    exit 1
fi
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
container_name=cs256-vivado-ubuntu24
container_uid=$(id -u alan)
container_gid=$(id -g alan)
[[ $container_uid == 1000 && $container_gid == 1000 ]] || {
    printf 'This setup is specific to Alan UID/GID 1000.\n' >&2; exit 1;
}
container_id=$(/usr/bin/docker inspect --format '{{.Id}}' "$container_name")
[[ $container_id =~ ^[0-9a-f]{64}$ ]] || exit 1
[[ $(/usr/bin/docker inspect --format '{{.HostConfig.Privileged}}' "$container_id") == false ]] || {
    printf 'Refusing a privileged container.\n' >&2; exit 1;
}
mounts=$(/usr/bin/docker inspect --format '{{range .Mounts}}{{println .Destination}}{{end}}' "$container_id")
for destination in $mounts; do
    case $destination in
        /tools|/builds|/home/vivado|/downloads|/project|/build-homework1.tcl) ;;
        *) printf 'Unexpected container mount: %s\n' "$destination" >&2; exit 1 ;;
    esac
done
/usr/bin/docker start "$container_id" >/dev/null
/usr/bin/docker exec --user "$container_uid:$container_gid" "$container_id" test -x /usr/bin/setpriv
/usr/sbin/visudo -c >/dev/null
launcher=/usr/local/sbin/cs256-vivado
policy=/etc/sudoers.d/cs256-vivado
if [[ -e $launcher ]] && ! grep -Fq CS256_FIXED_CONTAINER_LAUNCHER "$launcher"; then
    printf 'Refusing to overwrite an unrelated launcher.\n' >&2; exit 1
fi
if [[ -e $policy ]] && ! grep -Fq CS256_FIXED_CONTAINER_POLICY "$policy"; then
    printf 'Refusing to overwrite an unrelated sudo policy.\n' >&2; exit 1
fi
temporary_dir=$(mktemp -d)
trap 'rm -rf -- "$temporary_dir"' EXIT
sed -e "s/@CONTAINER_ID@/$container_id/g" \
    -e "s/@CONTAINER_UID@/$container_uid/g" -e "s/@CONTAINER_GID@/$container_gid/g" \
    "$source_dir/cs256-vivado.in" > "$temporary_dir/launcher"
printf '# CS256_FIXED_CONTAINER_POLICY\nalan ALL=(root) NOPASSWD: /usr/local/sbin/cs256-vivado\n' > "$temporary_dir/policy"
bash -n "$temporary_dir/launcher"
/usr/sbin/visudo -cf "$temporary_dir/policy" >/dev/null
install -o root -g root -m 0755 "$temporary_dir/launcher" "$launcher"
install -o root -g root -m 0440 "$temporary_dir/policy" "$policy"
/usr/sbin/visudo -c >/dev/null
printf 'Installed fixed-container launcher for %s.\n' "$container_id"
printf 'Unattended check: sudo -n /usr/local/sbin/cs256-vivado exec id\n'
