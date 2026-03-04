export class HttpError extends Error {
  constructor(statusCode, message, details = null) {
    super(message);
    this.name = 'HttpError';
    this.statusCode = Number(statusCode) || 500;
    this.details = details;
  }
}

export function isHttpError(err) {
  return err instanceof HttpError || (err && typeof err.statusCode === 'number');
}
