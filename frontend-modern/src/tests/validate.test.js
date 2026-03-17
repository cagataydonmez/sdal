/**
 * Tests for zod-based login schema matching the backend LoginSchema.
 * We mirror the schema here to test client-side validation parity.
 */
import { describe, it, expect } from 'vitest';
import { z } from 'zod';

const LoginSchema = z.object({
  kadi: z.string().min(1, 'auth_username_required').max(15),
  sifre: z.string().min(1, 'auth_password_required').max(20),
});

describe('LoginSchema', () => {
  it('passes valid credentials', () => {
    const result = LoginSchema.safeParse({ kadi: 'johndoe', sifre: 'secret123' });
    expect(result.success).toBe(true);
  });

  it('rejects empty username', () => {
    const result = LoginSchema.safeParse({ kadi: '', sifre: 'secret' });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('auth_username_required');
  });

  it('rejects empty password', () => {
    const result = LoginSchema.safeParse({ kadi: 'user', sifre: '' });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('auth_password_required');
  });

  it('rejects username > 15 chars', () => {
    const result = LoginSchema.safeParse({ kadi: 'a'.repeat(16), sifre: 'pass' });
    expect(result.success).toBe(false);
  });

  it('rejects password > 20 chars', () => {
    const result = LoginSchema.safeParse({ kadi: 'user', sifre: 'x'.repeat(21) });
    expect(result.success).toBe(false);
  });
});

const RegisterCheckSchema = z.object({
  kadi: z.string().max(15).optional().default(''),
  email: z.string().max(50).optional().default(''),
});

describe('RegisterCheckSchema', () => {
  it('passes with just username', () => {
    const result = RegisterCheckSchema.safeParse({ kadi: 'alice' });
    expect(result.success).toBe(true);
    expect(result.data.kadi).toBe('alice');
  });

  it('passes with just email', () => {
    const result = RegisterCheckSchema.safeParse({ email: 'alice@example.com' });
    expect(result.success).toBe(true);
  });

  it('passes with empty body (defaults applied)', () => {
    const result = RegisterCheckSchema.safeParse({});
    expect(result.success).toBe(true);
    expect(result.data.kadi).toBe('');
  });

  it('rejects username > 15 chars', () => {
    const result = RegisterCheckSchema.safeParse({ kadi: 'a'.repeat(16) });
    expect(result.success).toBe(false);
  });
});
