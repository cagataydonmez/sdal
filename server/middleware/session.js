import session from 'express-session';

export function sessionMiddleware({ isProd }) {
  return session({
    secret: process.env.SDAL_SESSION_SECRET || 'sdal-dev-secret',
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 1000 * 60 * 60 * 2,
      httpOnly: true,
      sameSite: 'lax',
      secure: isProd
    }
  });
}

