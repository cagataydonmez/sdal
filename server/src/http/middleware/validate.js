
const MAX_REJECTION_HISTORY = 200;
const rejections = [];

/** Returns the most recent validation rejections (newest first). */
export function getValidationRejections(limit = 50) {
  return rejections.slice(0, limit);
}

/** Resets the in-memory rejection log (for tests). */
export function clearValidationRejections() {
  rejections.length = 0;
}

function recordRejection(url, method, messages) {
  rejections.unshift({ url, method, messages, at: new Date().toISOString() });
  if (rejections.length > MAX_REJECTION_HISTORY) rejections.length = MAX_REJECTION_HISTORY;
}

/**
 * Express middleware factory for zod schema validation.
 * Usage: app.post('/route', validate(MySchema), handler)
 *
 * @param {import('zod').ZodSchema} schema
 * @param {'body'|'query'|'params'} [source='body']
 */
export function validate(schema, source = 'body') {
  return (req, res, next) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const messages = (result.error.issues ?? result.error.errors).map(e => e.message);
      recordRejection(req.path, req.method, messages);
      return res.status(400).json({ error: messages.join(', ') });
    }
    req[source] = result.data;
    next();
  };
}
