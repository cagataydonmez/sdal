import fs from 'fs/promises';
import path from 'path';
import { getDirname } from '../../config/paths.js';
import {
  BUILT_IN_LANGUAGES,
  LANGUAGE_CONFIG_DEFAULTS,
  LANGUAGE_SEED_STRINGS,
  getSeedStringsForLang
} from './languageSeedData.js';

const __dirname = getDirname(import.meta.url);
const STORE_DIR = path.resolve(__dirname, '../../data');
const STORE_FILE = path.join(STORE_DIR, 'language-catalog.json');

function cloneLanguage(language) {
  return {
    code: String(language.code || '').trim().toLowerCase(),
    name: String(language.name || '').trim(),
    native_name: String(language.native_name || language.nativeName || '').trim(),
    is_default: !!language.is_default,
    is_active: language.is_active !== false,
    created_at: language.created_at || null
  };
}

function dedupeLanguages(languages) {
  const map = new Map();
  for (const language of languages) {
    const normalized = cloneLanguage(language);
    if (!normalized.code) continue;
    map.set(normalized.code, normalized);
  }
  const rows = Array.from(map.values());
  if (!rows.some((row) => row.is_default && row.code === 'tr')) {
    const tr = rows.find((row) => row.code === 'tr');
    if (tr) tr.is_default = true;
  }
  for (const row of rows) {
    if (row.code !== 'tr' && row.is_default) row.is_default = false;
  }
  return rows.sort((left, right) => {
    if (left.is_default !== right.is_default) return left.is_default ? -1 : 1;
    return left.code.localeCompare(right.code);
  });
}

function normalizeConfig(config, languages) {
  const activeCodes = new Set(
    languages
      .filter((row) => row.is_active)
      .map((row) => row.code)
  );
  const safeDefault = activeCodes.has('tr') ? 'tr' : (Array.from(activeCodes)[0] || 'tr');
  const next = {
    lang_selection_enabled: config?.lang_selection_enabled !== false,
    default_lang_open: String(config?.default_lang_open || safeDefault).trim().toLowerCase(),
    default_lang_closed: String(config?.default_lang_closed || safeDefault).trim().toLowerCase()
  };
  if (!activeCodes.has(next.default_lang_open)) next.default_lang_open = safeDefault;
  if (!activeCodes.has(next.default_lang_closed)) next.default_lang_closed = safeDefault;
  return next;
}

function normalizeMap(rawMap) {
  const next = {};
  for (const [lang, values] of Object.entries(rawMap || {})) {
    const langCode = String(lang || '').trim().toLowerCase();
    if (!langCode || !values || typeof values !== 'object' || Array.isArray(values)) continue;
    const entries = {};
    for (const [key, value] of Object.entries(values)) {
      const normalizedKey = String(key || '').trim();
      if (!normalizedKey) continue;
      entries[normalizedKey] = String(value ?? '');
    }
    next[langCode] = entries;
  }
  return next;
}

function normalizeDeleted(rawDeleted) {
  const next = {};
  for (const [lang, keys] of Object.entries(rawDeleted || {})) {
    const langCode = String(lang || '').trim().toLowerCase();
    if (!langCode || !Array.isArray(keys)) continue;
    next[langCode] = Array.from(new Set(
      keys
        .map((key) => String(key || '').trim())
        .filter(Boolean)
    )).sort((left, right) => left.localeCompare(right));
  }
  return next;
}

function buildEmptyStore() {
  return {
    version: 1,
    updated_at: null,
    languages: BUILT_IN_LANGUAGES.map((row) => ({ ...row, created_at: null })),
    config: { ...LANGUAGE_CONFIG_DEFAULTS },
    strings: {},
    deleted: {}
  };
}

function normalizeStore(raw) {
  const base = buildEmptyStore();
  const languages = dedupeLanguages([...(base.languages || []), ...((raw?.languages || []).map(cloneLanguage))]);
  return {
    version: 1,
    updated_at: raw?.updated_at || null,
    languages,
    config: normalizeConfig(raw?.config || base.config, languages),
    strings: normalizeMap(raw?.strings),
    deleted: normalizeDeleted(raw?.deleted)
  };
}

async function ensureStoreDir() {
  await fs.mkdir(STORE_DIR, { recursive: true });
}

async function readStore() {
  try {
    const raw = await fs.readFile(STORE_FILE, 'utf8');
    return normalizeStore(JSON.parse(raw));
  } catch {
    return buildEmptyStore();
  }
}

async function writeStore(store) {
  const normalized = normalizeStore({
    ...store,
    updated_at: new Date().toISOString()
  });
  await ensureStoreDir();
  await fs.writeFile(STORE_FILE, `${JSON.stringify(normalized, null, 2)}\n`, 'utf8');
  return normalized;
}

function isSeededString(lang, key) {
  return Object.prototype.hasOwnProperty.call(getSeedStringsForLang(lang), key);
}

function getMergedStringsByLanguage(store) {
  const merged = {};
  for (const language of store.languages) {
    const lang = language.code;
    const seed = { ...getSeedStringsForLang(lang) };
    const deleted = new Set(store.deleted?.[lang] || []);
    const overrides = store.strings?.[lang] || {};
    for (const key of deleted) {
      delete seed[key];
    }
    merged[lang] = {
      ...seed,
      ...overrides
    };
  }
  return merged;
}

function getMergedRows(store) {
  const byLanguage = getMergedStringsByLanguage(store);
  const rows = [];
  for (const [lang, values] of Object.entries(byLanguage)) {
    for (const [key, value] of Object.entries(values)) {
      rows.push({
        lang_code: lang,
        key,
        value,
        updated_at: store.updated_at || null
      });
    }
  }
  rows.sort((left, right) => {
    const keyCompare = left.key.localeCompare(right.key);
    if (keyCompare !== 0) return keyCompare;
    return left.lang_code.localeCompare(right.lang_code);
  });
  return rows;
}

function ensureLanguageExists(store, code) {
  return store.languages.find((row) => row.code === code) || null;
}

export async function listLanguages() {
  const store = await readStore();
  return store.languages.map((row) => ({ ...row }));
}

export async function listActiveLanguages() {
  const rows = await listLanguages();
  return rows.filter((row) => row.is_active);
}

export async function addLanguage(payload) {
  const store = await readStore();
  const code = String(payload?.code || '').trim().toLowerCase().slice(0, 10);
  const name = String(payload?.name || '').trim().slice(0, 100);
  const nativeName = String(payload?.native_name || payload?.nativeName || '').trim().slice(0, 100);
  if (!code || !name || !nativeName) throw new Error('code, name, and native_name are required.');
  if (ensureLanguageExists(store, code)) throw new Error('Language code already exists.');
  store.languages.push({
    code,
    name,
    native_name: nativeName,
    is_default: false,
    is_active: true,
    created_at: new Date().toISOString()
  });
  await writeStore(store);
  return { ok: true, code };
}

export async function updateLanguage(code, payload = {}) {
  const store = await readStore();
  const targetCode = String(code || '').trim().toLowerCase();
  const language = ensureLanguageExists(store, targetCode);
  if (!language) throw new Error('Language not found.');
  if (payload.name !== undefined) {
    language.name = String(payload.name || '').trim().slice(0, 100);
  }
  if (payload.native_name !== undefined) {
    language.native_name = String(payload.native_name || '').trim().slice(0, 100);
  }
  if (payload.is_active !== undefined) {
    if (language.is_default && !payload.is_active) {
      throw new Error('Cannot deactivate the default language.');
    }
    language.is_active = !!payload.is_active;
  }
  const saved = await writeStore(store);
  return saved.languages.find((row) => row.code === targetCode);
}

export async function deleteLanguage(code) {
  const store = await readStore();
  const targetCode = String(code || '').trim().toLowerCase();
  const language = ensureLanguageExists(store, targetCode);
  if (!language) throw new Error('Language not found.');
  if (language.is_default) throw new Error('Cannot delete the default language.');
  store.languages = store.languages.filter((row) => row.code !== targetCode);
  delete store.strings[targetCode];
  delete store.deleted[targetCode];
  if (store.config.default_lang_open === targetCode) store.config.default_lang_open = 'tr';
  if (store.config.default_lang_closed === targetCode) store.config.default_lang_closed = 'tr';
  await writeStore(store);
  return { ok: true };
}

export async function getLanguageConfig() {
  const store = await readStore();
  return { ...store.config };
}

export async function updateLanguageConfig(payload = {}) {
  const store = await readStore();
  const activeCodes = new Set(store.languages.filter((row) => row.is_active).map((row) => row.code));
  const selectionEnabled = payload.lang_selection_enabled !== undefined
    ? !!payload.lang_selection_enabled
    : store.config.lang_selection_enabled;
  const defaultOpen = payload.default_lang_open !== undefined
    ? String(payload.default_lang_open || '').trim().toLowerCase()
    : store.config.default_lang_open;
  const defaultClosed = payload.default_lang_closed !== undefined
    ? String(payload.default_lang_closed || '').trim().toLowerCase()
    : store.config.default_lang_closed;
  if (defaultOpen && !activeCodes.has(defaultOpen)) throw new Error(`Language "${defaultOpen}" not found.`);
  if (defaultClosed && !activeCodes.has(defaultClosed)) throw new Error(`Language "${defaultClosed}" not found.`);
  store.config = normalizeConfig({
    lang_selection_enabled: selectionEnabled,
    default_lang_open: defaultOpen || store.config.default_lang_open,
    default_lang_closed: defaultClosed || store.config.default_lang_closed
  }, store.languages);
  const saved = await writeStore(store);
  return { ok: true, ...saved.config };
}

export async function listLanguageStrings({ lang, q, page = 1, limit = 50 } = {}) {
  const store = await readStore();
  const targetLang = String(lang || '').trim().toLowerCase();
  const needle = String(q || '').trim().toLowerCase();
  const rows = getMergedRows(store).filter((row) => {
    if (targetLang && row.lang_code !== targetLang) return false;
    if (!needle) return true;
    return row.key.toLowerCase().includes(needle) || row.value.toLowerCase().includes(needle);
  });
  const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 2000);
  const safePage = Math.max(Number(page) || 1, 1);
  const offset = (safePage - 1) * safeLimit;
  return {
    strings: rows.slice(offset, offset + safeLimit),
    total: rows.length,
    page: safePage,
    limit: safeLimit
  };
}

export async function listLanguageStringKeys({ q, page = 1, limit = 100 } = {}) {
  const store = await readStore();
  const needle = String(q || '').trim().toLowerCase();
  const keys = Array.from(new Set(getMergedRows(store).map((row) => row.key)))
    .filter((key) => !needle || key.toLowerCase().includes(needle))
    .sort((left, right) => left.localeCompare(right));
  const safeLimit = Math.min(Math.max(Number(limit) || 100, 1), 500);
  const safePage = Math.max(Number(page) || 1, 1);
  const offset = (safePage - 1) * safeLimit;
  return {
    keys: keys.slice(offset, offset + safeLimit),
    total: keys.length,
    page: safePage,
    limit: safeLimit
  };
}

export async function upsertLanguageString(lang, key, value) {
  const store = await readStore();
  const targetLang = String(lang || '').trim().toLowerCase();
  const normalizedKey = String(key || '').trim();
  if (!targetLang || !normalizedKey) throw new Error('lang and key are required.');
  if (!ensureLanguageExists(store, targetLang)) throw new Error('Language not found.');
  if (!store.strings[targetLang]) store.strings[targetLang] = {};
  store.strings[targetLang][normalizedKey] = String(value ?? '');
  store.deleted[targetLang] = (store.deleted[targetLang] || []).filter((item) => item !== normalizedKey);
  await writeStore(store);
  return { ok: true };
}

export async function bulkUpsertLanguageStrings(lang, strings) {
  const store = await readStore();
  const targetLang = String(lang || '').trim().toLowerCase();
  if (!targetLang) throw new Error('lang is required.');
  if (!ensureLanguageExists(store, targetLang)) throw new Error('Language not found.');
  if (!strings || typeof strings !== 'object' || Array.isArray(strings)) {
    throw new Error('strings must be a key/value object.');
  }
  if (!store.strings[targetLang]) store.strings[targetLang] = {};
  const deletedSet = new Set(store.deleted[targetLang] || []);
  let count = 0;
  for (const [key, value] of Object.entries(strings)) {
    const normalizedKey = String(key || '').trim();
    if (!normalizedKey) continue;
    store.strings[targetLang][normalizedKey] = String(value ?? '');
    deletedSet.delete(normalizedKey);
    count += 1;
  }
  store.deleted[targetLang] = Array.from(deletedSet).sort((left, right) => left.localeCompare(right));
  await writeStore(store);
  return { ok: true, count };
}

export async function deleteLanguageString(lang, key) {
  const store = await readStore();
  const targetLang = String(lang || '').trim().toLowerCase();
  const normalizedKey = String(key || '').trim();
  if (!targetLang || !normalizedKey) throw new Error('lang and key are required.');
  if (store.strings[targetLang]) delete store.strings[targetLang][normalizedKey];
  if (isSeededString(targetLang, normalizedKey)) {
    const deletedSet = new Set(store.deleted[targetLang] || []);
    deletedSet.add(normalizedKey);
    store.deleted[targetLang] = Array.from(deletedSet).sort((left, right) => left.localeCompare(right));
  } else {
    store.deleted[targetLang] = (store.deleted[targetLang] || []).filter((item) => item !== normalizedKey);
  }
  await writeStore(store);
  return { ok: true };
}

export async function deleteLanguageKey(key) {
  const store = await readStore();
  const normalizedKey = String(key || '').trim();
  if (!normalizedKey) throw new Error('key is required.');
  for (const language of store.languages) {
    const lang = language.code;
    if (store.strings[lang]) delete store.strings[lang][normalizedKey];
    if (isSeededString(lang, normalizedKey)) {
      const deletedSet = new Set(store.deleted[lang] || []);
      deletedSet.add(normalizedKey);
      store.deleted[lang] = Array.from(deletedSet).sort((left, right) => left.localeCompare(right));
    } else {
      store.deleted[lang] = (store.deleted[lang] || []).filter((item) => item !== normalizedKey);
    }
  }
  await writeStore(store);
  return { ok: true };
}

export async function getPublicLanguageStrings(lang) {
  const store = await readStore();
  const targetLang = String(lang || '').trim().toLowerCase();
  const language = store.languages.find((row) => row.code === targetLang && row.is_active);
  if (!language) return { strings: {} };
  const merged = getMergedStringsByLanguage(store);
  return { strings: merged[targetLang] || {} };
}
