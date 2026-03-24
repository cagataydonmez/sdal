import { registerAlbumRoutes } from './albumRoutes.js';
import { registerLegacyInboxRoutes } from './legacyInboxRoutes.js';
import { registerMemberDirectoryRoutes } from './memberDirectoryRoutes.js';
import { registerMessengerRoutes } from './messengerRoutes.js';

export function registerMemberCommunicationRoutes(app, deps) {
  registerMemberDirectoryRoutes(app, deps);
  registerLegacyInboxRoutes(app, deps);
  registerMessengerRoutes(app, deps);
  registerAlbumRoutes(app, deps);
}
