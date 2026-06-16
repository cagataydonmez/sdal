#!/usr/bin/env bash
set -euo pipefail

CONF=/etc/nginx/conf.d/00-sdal.conf

if grep -q 'location /cdcleaner/' "$CONF"; then
  echo "Location blocks already present, skipping"
  nginx -t && systemctl reload nginx && echo "nginx OK"
  exit 0
fi

# Insert /cdcleaner/ and /adhoc/ location blocks before the existing /cdiptv/ block
python3 - "$CONF" << 'PYEOF'
import sys, re

conf_path = sys.argv[1]
with open(conf_path) as f:
    content = f.read()

insert = '''    location /cdcleaner/ {
        root /var/www/sdal;
        types { text/html html; application/octet-stream ipa; text/xml plist; }
        default_type application/octet-stream;
    }

    location /adhoc/ {
        root /var/www/sdal;
        index index.html;
    }

'''

content = content.replace('    location /cdiptv/', insert + '    location /cdiptv/', 1)

with open(conf_path, 'w') as f:
    f.write(content)

print("nginx config patched")
PYEOF

nginx -t && systemctl reload nginx && echo "nginx reloaded OK"
