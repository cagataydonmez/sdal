import { registerCommunityRoutes } from './communityRoutes.js';
import { registerOpportunityRoutes } from './opportunityRoutes.js';

export function registerEventJobRoutes(app, deps) {
  registerCommunityRoutes(app, deps);
  registerOpportunityRoutes(app, deps);
}
