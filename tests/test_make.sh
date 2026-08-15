#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
plugin_dir="$test_root/home/.config/omarchy/plugins"
mkdir -p "$fake_bin" "$plugin_dir"

cat > "$fake_bin/omarchy-shell" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$fake_bin/omarchy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == plugin && "$2" == enable ]]; then
  printf '%s\n' "enabled $3" > "$TEST_ROOT/enabled"
  exit 0
fi
if [[ "$1" == plugin && "$2" == add ]]; then
  mkdir -p "$PLUGIN_DIR/$PLUGIN_ID"
  printf '%s\n' "$3" > "$TEST_ROOT/repository"
  printf '%s\n' "added $PLUGIN_ID" > "$TEST_ROOT/added"
  exit 0
fi
if [[ "$1" == restart && "$2" == shell ]]; then
  printf '%s\n' "restarted shell" > "$TEST_ROOT/reloaded"
  exit 0
fi
echo "unexpected omarchy command" >&2
exit 1
EOF

chmod +x "$fake_bin/omarchy-shell" "$fake_bin/omarchy"

export HOME="$test_root/home"
export PATH="$fake_bin:$PATH"
export TEST_ROOT="$test_root"
export PLUGIN_DIR="$plugin_dir"
export PLUGIN_ID="mokkabonna.plugin-settings"

make -C "$repo_dir" local PLUGIN_DIR="$plugin_dir" >/dev/null
test -L "$plugin_dir/$PLUGIN_ID"
test "$(readlink -f "$plugin_dir/$PLUGIN_ID")" = "$repo_dir"
test -f "$test_root/enabled"

make -C "$repo_dir" reload >/dev/null
test -f "$test_root/reloaded"

rm "$plugin_dir/$PLUGIN_ID"
mkdir -p "$plugin_dir/$PLUGIN_ID"
printf '%s\n' installed > "$plugin_dir/$PLUGIN_ID/source"
make -C "$repo_dir" install PLUGIN_DIR="$plugin_dir" PLUGIN_REPO=https://example.test/plugin.git >/dev/null
test -d "$plugin_dir/$PLUGIN_ID"
test -f "$test_root/added"
test "$(cat "$test_root/repository")" = "https://example.test/plugin.git"
test -f "$test_root/enabled"
backup=$(find "$plugin_dir" -maxdepth 1 -name ".${PLUGIN_ID}.previous.*" -print -quit)
test -n "$backup"
test -f "$backup/source"

release_repo="$test_root/release-repo"
cp -a "$repo_dir" "$release_repo"
rm -rf "$release_repo/.git"
git -C "$release_repo" init -q
git -C "$release_repo" config user.name "Release Test"
git -C "$release_repo" config user.email "release-test@example.test"
git -C "$release_repo" config commit.gpgsign false
git -C "$release_repo" add .
git -C "$release_repo" commit -qm "Initial test state"

make -C "$release_repo" release VERSION=9.8.7 RELEASE_CHECK=manifest >/dev/null
test "$(jq -r '.version' "$release_repo/manifest.json")" = "9.8.7"
test "$(git -C "$release_repo" log -1 --pretty=%s)" = "Release v9.8.7"
git -C "$release_repo" rev-parse -q --verify refs/tags/v9.8.7 >/dev/null
test -z "$(git -C "$release_repo" status --short)"

printf '%s\n' "Make integration tests passed"
