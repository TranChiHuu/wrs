#!/usr/bin/env bash
set -u
T="$(mktemp -d)"
export WRS_WRANGLER_CONFIG="$T/wr/default.toml" WRS_HOME="$T/home"
W="$(cd "$(dirname "$0")" && pwd)/wrs"
fail=0
ok() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }
mkdir -p "$T/wr"
printf 'oauth_token = "A1"\nrefresh_token = "RA1"\n' > "$WRS_WRANGLER_CONFIG"
$W save a
ok "save mode" '[[ "$(stat -f %Lp "$WRS_HOME/profiles/a.toml")" == 600 && "$(stat -f %Lp "$WRS_HOME/profiles")" == 700 ]]'
ok "active=a" '[[ "$(cat "$WRS_HOME/active")" == a ]]'
printf 'oauth_token = "B1"\nrefresh_token = "RB1"\n' > "$WRS_WRANGLER_CONFIG"
$W save b
$W switch a
ok "switch a content" 'grep -q A1 "$WRS_WRANGLER_CONFIG"'
printf 'oauth_token = "A2"\nrefresh_token = "RA2"\n' > "$WRS_WRANGLER_CONFIG"
$W use b
ok "switch b content" 'grep -q B1 "$WRS_WRANGLER_CONFIG"'
$W switch a
ok "refreshed token survived" 'grep -q A2 "$WRS_WRANGLER_CONFIG"'
$W list
ok "list marks active" '[[ "$($W list | grep "^\*")" == "* a" ]]'
$W remove a 2>/dev/null; ok "remove active refused" '[[ -f "$WRS_HOME/profiles/a.toml" ]]'
$W remove b; ok "remove b" '[[ ! -f "$WRS_HOME/profiles/b.toml" ]]'
$W remove -f a; ok "remove -f active" '[[ ! -f "$WRS_HOME/profiles/a.toml" ]]'
$W 2>/dev/null; ok "no args exit 1" '[[ $? -eq 1 ]]'
$W bogus 2>/dev/null; ok "unknown exit 1" '[[ $? -eq 1 ]]'
$W switch 2>/dev/null; ok "missing name exit 1" '[[ $? -eq 1 ]]'
$W switch nope 2>/dev/null; ok "unknown profile exit 1" '[[ $? -eq 1 ]]'
mkdir -p "$T/bin"; printf '#!/bin/sh\nexit 1\n' > "$T/bin/npx"; chmod +x "$T/bin/npx"
printf 'oauth_token = "KEEP"\n' > "$WRS_WRANGLER_CONFIG"
$W save k >/dev/null; PATH="$T/bin:$PATH" $W login c 2>/dev/null
ok "failed login restores" 'grep -q KEEP "$WRS_WRANGLER_CONFIG" && [[ ! -f "$WRS_HOME/profiles/c.toml" ]]'
printf '#!/bin/sh\nprintf "oauth_token = \\"NEW\\"\\n" > "$WRS_WRANGLER_CONFIG"\n' > "$T/bin/npx"
PATH="$T/bin:$PATH" $W login c
ok "login saves new" 'grep -q NEW "$WRS_HOME/profiles/c.toml" && [[ "$(cat "$WRS_HOME/active")" == c ]]'
cat > "$T/bin/npx" <<'N'
#!/bin/sh
case "$*" in
  *login*) printf 'oauth_token = "AUTO"\n' > "$WRS_WRANGLER_CONFIG" ;;
  *whoami*) grep -q AUTO "$WRS_WRANGLER_CONFIG" && echo "You are logged in with an OAuth Token, associated with the email auto@x.io." || echo "You are logged in with an OAuth Token, associated with the email c@x.io." ;;
esac
N
PATH="$T/bin:$PATH" $W login
ok "login without name uses email" 'grep -q AUTO "$WRS_HOME/profiles/auto@x.io.toml" && [[ "$(cat "$WRS_HOME/active")" == auto@x.io ]]'
PATH="$T/bin:$PATH" $W use c >/dev/null
ok "switch by unique prefix" '[[ "$(cat "$WRS_HOME/active")" == c ]]'
$W use zz 2>/dev/null; ok "no prefix match exit 1" '[[ $? -eq 1 ]]'
printf '#!/bin/sh\ncase "$*" in *login*) printf "oauth_token = \\"X\\"\\n" > "$WRS_WRANGLER_CONFIG";; esac\n' > "$T/bin/npx"
$W use c >/dev/null; cp "$WRS_HOME/profiles/c.toml" "$T/c.before"
PATH="$T/bin:$PATH" $W login 2>/dev/null
ok "unknown email restores and keeps profile" '[[ $? -ne 0 ]] && cmp -s "$WRS_WRANGLER_CONFIG" "$T/c.before" && cmp -s "$WRS_HOME/profiles/c.toml" "$T/c.before" && [[ "$(cat "$WRS_HOME/active")" == c ]]'
rm -f "$WRS_HOME/active"
PATH="$T/bin:$PATH" $W login 2>/dev/null
ok "first login refuses when current email unknown" '[[ $? -ne 0 ]] && cmp -s "$WRS_WRANGLER_CONFIG" "$T/c.before"'
cat > "$T/bin/npx" <<'N'
#!/bin/sh
case "$*" in
  *login*) printf 'oauth_token = "SECOND"\n' > "$WRS_WRANGLER_CONFIG" ;;
  *whoami*) grep -q SECOND "$WRS_WRANGLER_CONFIG" && echo "associated with the email second@x.io." || echo "associated with the email first@x.io." ;;
esac
N
rm -rf "$WRS_HOME"; printf 'oauth_token = "FIRST"\n' > "$WRS_WRANGLER_CONFIG"
PATH="$T/bin:$PATH" $W login >/dev/null
ok "first login auto-saves existing login" 'grep -q FIRST "$WRS_HOME/profiles/first@x.io.toml" && grep -q SECOND "$WRS_HOME/profiles/second@x.io.toml" && [[ "$(cat "$WRS_HOME/active")" == second@x.io ]]'
$W use first >/dev/null; ok "prefix switch to email profile" 'grep -q FIRST "$WRS_WRANGLER_CONFIG"'
$W use "" 2>/dev/null; ok "empty name exit 1" '[[ $? -eq 1 ]]'
$W use "" 2>/dev/null; $W use x 2>/dev/null; ok "ambiguous prefix refused" '[[ $? -eq 1 ]] && grep -q FIRST "$WRS_WRANGLER_CONFIG"'
$W use ../etc 2>/dev/null; ok "path traversal refused" '[[ $? -eq 1 ]]'
rm -rf "$T"
exit $fail
