import { describe, it, expect, vi, beforeEach } from 'vitest';
import { api, withQuery } from '../utils/apiClient.js';

describe('withQuery', () => {
  it('appends query params', () => {
    expect(withQuery('/api/foo', { q: 'bar', page: 2 })).toBe('/api/foo?q=bar&page=2');
  });

  it('skips empty values', () => {
    expect(withQuery('/api/foo', { q: '', page: null })).toBe('/api/foo');
  });
});

describe('api', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn());
  });

  it('throws on non-ok response', async () => {
    fetch.mockResolvedValue({
      ok: false,
      status: 401,
      text: async () => 'Unauthorized',
    });
    await expect(api.get('/api/session')).rejects.toThrow('Unauthorized');
  });

  it('returns null on 204', async () => {
    fetch.mockResolvedValue({ ok: true, status: 204, json: async () => null });
    const result = await api.get('/api/logout');
    expect(result).toBeNull();
  });

  it('returns parsed json on success', async () => {
    fetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ user: { id: 1 } }),
    });
    const result = await api.get('/api/session');
    expect(result.user.id).toBe(1);
  });
});
