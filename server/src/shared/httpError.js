export class HttpError extends Error {
  constructor(statusCode, message, details = null) {
    super(message);
    this.name = 'HttpError';
    this.statusCode = Number(statusCode) || 500;
    this.details = details;
    if (details && typeof details === 'object' && details.code) {
      this.code = String(details.code);
    }
  }
}

export function isHttpError(err) {
  return err instanceof HttpError || (err && typeof err.statusCode === 'number');
}
