export const NETWORKING_TELEMETRY_EVENTS = Object.freeze({
  hubViewed: 'network_hub_viewed',
  hubSuggestionsLoaded: 'network_hub_suggestions_loaded',
  exploreViewed: 'network_explore_viewed',
  exploreSuggestionsLoaded: 'network_explore_suggestions_loaded',
  teacherNetworkViewed: 'teacher_network_viewed'
});

export async function sendNetworkingTelemetry({
  eventName,
  sourceSurface,
  targetUserId = null,
  entityType = '',
  entityId = null,
  metadata = null
} = {}) {
  if (!eventName) return;
  try {
    await fetch('/api/new/network/telemetry', {
      method: 'POST',
      credentials: 'include',
      keepalive: true,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        event_name: eventName,
        source_surface: sourceSurface,
        target_user_id: targetUserId,
        entity_type: entityType,
        entity_id: entityId,
        metadata
      })
    });
  } catch {
    // Telemetry should never block the UI flow.
  }
}
