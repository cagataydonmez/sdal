import express from 'express';
import path from 'path';

export function registerLegacyStatics(app, legacyDir) {
  app.use('/legacy', express.static(legacyDir));
  app.use('/smiley', express.static(path.join(legacyDir, 'smiley')));
}

