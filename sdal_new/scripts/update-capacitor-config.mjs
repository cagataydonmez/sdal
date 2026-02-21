import fs from 'node:fs';
import path from 'node:path';

const configPath = path.resolve('capacitor.config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const rawServerUrl = process.env.CAP_SERVER_URL?.trim();

function normalizeServerUrl(input) {
  if (!input) return '';

  // Collapse duplicated protocol prefixes such as "https://https://host".
  let value = input.replace(/^(https?:\/\/)+/i, (match) => {
    return match.toLowerCase().includes('https://') ? 'https://' : 'http://';
  });

  // Default to https when protocol is omitted.
  if (!/^https?:\/\//i.test(value)) {
    value = `https://${value}`;
  }

  try {
    const parsed = new URL(value);
    if (!parsed.hostname) return '';
    return parsed.toString();
  } catch {
    return '';
  }
}

const serverUrl = normalizeServerUrl(rawServerUrl);

if (serverUrl) {
  config.server = {
    url: serverUrl,
    cleartext: serverUrl.startsWith('http://')
  };
} else {
  delete config.server;
}

fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
console.log(
  rawServerUrl && !serverUrl
    ? `Invalid CAP_SERVER_URL: ${rawServerUrl}`
    : serverUrl
    ? `Capacitor server.url set to ${serverUrl}`
    : 'Capacitor server.url removed (using bundled web assets).'
);
