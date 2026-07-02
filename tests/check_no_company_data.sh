#!/usr/bin/env bash
# Gate anti-filtración: falla si algún archivo trackeado contiene tokens que
# parezcan datos reales (account ids, instance ids, subdominios SSO) fuera de
# la allowlist de placeholders ficticios. No contiene datos de la org.
set -u
cd "$(dirname "$0")/.." || exit 2

ALLOWED_ACCOUNTS="123456789012 210987654321"
ALLOWED_INSTANCES="i-0123456789abcdef0"
ALLOWED_SSO_SUBDOMAIN="my-org"

fail=0
files=$(git ls-files)

for tok in $(printf '%s\n' "$files" | xargs grep -hoE '[0-9]{12}' 2>/dev/null | sort -u); do
  case " $ALLOWED_ACCOUNTS " in *" $tok "*) ;; *) echo "posible account id real: $tok"; fail=1;; esac
done

for tok in $(printf '%s\n' "$files" | xargs grep -hoE 'i-[0-9a-f]{17}' 2>/dev/null | sort -u); do
  case " $ALLOWED_INSTANCES " in *" $tok "*) ;; *) echo "posible instance id real: $tok"; fail=1;; esac
done

for tok in $(printf '%s\n' "$files" | xargs grep -hoE '[a-z0-9-]+\.awsapps\.com' 2>/dev/null | sort -u); do
  case "$tok" in "$ALLOWED_SSO_SUBDOMAIN.awsapps.com") ;; *) echo "posible SSO start url real: $tok"; fail=1;; esac
done

if [ "$fail" -eq 0 ]; then
  echo "✅ sin datos de la empresa en archivos trackeados"
else
  echo "❌ revisar los tokens de arriba antes de pushear"
fi
exit "$fail"
