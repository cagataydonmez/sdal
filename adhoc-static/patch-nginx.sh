#!/usr/bin/env bash
set -euo pipefail

CONF=/etc/nginx/conf.d/00-sdal.conf

if grep -q 'location /cdcleaner/' "$CONF"; then
  echo "Location blocks already present, skipping"
  nginx -t && systemctl reload nginx && echo "nginx OK"
  exit 0
fi

python3 - "$CONF" << 'PYEOF'
import sys, re

conf_path = sys.argv[1]
with open(conf_path) as f:
    content = f.read()

# Find the /cdiptv/ location block with flexible whitespace
match = re.search(r'(\s*)location\s+/cdiptv/', content)
if not match:
    print("ERROR: could not find /cdiptv/ location block")
    sys.exit(1)

indent = match.group(1)
print(f"Detected indent: {repr(indent)}")

insert = f'''{indent}location /cdcleaner/ {{
{indent}    root /var/www/sdal;
{indent}    types {{ text/html html; application/octet-stream ipa; text/xml plist; }}
{indent}    default_type application/octet-stream;
{indent}}}

{indent}location /adhoc/ {{
{indent}    root /var/www/sdal;
{indent}    index index.html;
{indent}}}

'''

content = re.sub(r'(\s*)location\s+/cdiptv/', insert + indent + 'location /cdiptv/', content, count=1)

with open(conf_path, 'w') as f:
    f.write(content)

print("nginx config patched successfully")
PYEOF

nginx -t && systemctl reload nginx && echo "nginx reloaded OK"
