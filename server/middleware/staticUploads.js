import express from 'express';
import path from 'path';

export function registerStaticUploads(app, uploadsDir) {
  app.use('/uploads/images', (_req, res, next) => {
    res.set('Cache-Control', 'public, max-age=31536000, immutable');
    next();
  }, express.static(path.join(uploadsDir, 'images')));
}

