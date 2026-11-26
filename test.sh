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
PATH="$T/bin:$PATH" $W login c 2>/dev/null
ok "failed login restores" 'grep -q KEEP "$WRS_WRANGLER_CONFIG" && [[ ! -f "$WRS_HOME/profiles/c.toml" ]]'
printf '#!/bin/sh\nprintf "oauth_token = \\"NEW\\"\\n" > "$WRS_WRANGLER_CONFIG"\n' > "$T/bin/npx"
PATH="$T/bin:$PATH" $W login c
ok "login saves new" 'grep -q NEW "$WRS_HOME/profiles/c.toml" && [[ "$(cat "$WRS_HOME/active")" == c ]]'
rm -rf "$T"
exit $fail
