export const NETWORKING_EVENTS = Object.freeze({
  connectionAccepted: 'connection:accepted',
  connectionIgnored: 'connection:ignored',
  connectionCancelled: 'connection:cancelled',
  connectionRequested: 'connection:request',
  mentorshipAccepted: 'mentorship:accepted',
  teacherLinksRead: 'teacher-links:read',
  followChanged: 'follow:changed'
});

export const NETWORKING_MESSAGES = Object.freeze({
  errors: Object.freeze({
    connectionAcceptFailed: 'Bağlantı isteği kabul edilemedi.',
    connectionIgnoreFailed: 'Bağlantı isteği yok sayılamadı.',
    connectionActionFailed: 'Bağlantı işlemi başarısız.',
    mentorshipAcceptFailed: 'Mentorluk talebi kabul edilemedi.',
    mentorshipDeclineFailed: 'Mentorluk talebi reddedilemedi.',
    mentorshipRequestFailed: 'Mentorluk isteği gönderilemedi.',
    teacherLinksReadFailed: 'Bildirimler güncellenemedi.',
    teacherOptionsLoadFailed: 'Öğretmen listesi alınamadı.',
    teacherNetworkLoadFailed: 'Öğretmen ağı yüklenemedi.',
    teacherLinkCreateFailed: 'Öğretmen bağlantısı kaydedilemedi.',
    followUpdateFailed: 'Takip durumu değiştirilemedi.'
  }),
  success: Object.freeze({
    connectionAccepted: 'Bağlantı isteği kabul edildi.',
    connectionIgnored: 'Bağlantı isteği yok sayıldı.',
    connectionCancelled: 'Bağlantı isteği geri çekildi.',
    connectionRequested: 'Yeni bağlantı isteği gönderildi.',
    mentorshipAccepted: 'Mentorluk talebi kabul edildi.',
    mentorshipDeclined: 'Mentorluk talebi reddedildi.',
    teacherLinksRead: 'Öğretmen ağı bildirimleri okundu olarak işaretlendi.',
    followUpdated: 'Takip durumu güncellendi.',
    mentorshipRequested: 'Mentorluk talebi gönderildi.',
    teacherLinkCreated: 'Öğretmen bağlantısı başarıyla kaydedildi.'
  })
});

export function getConnectionActionMode({ incomingRequestId = 0, outgoingRequestId = 0 } = {}) {
  if (Number(incomingRequestId) > 0) return 'accepted';
  if (Number(outgoingRequestId) > 0) return 'cancelled';
  return 'requested';
}

export function getConnectionActionEvent(options = {}) {
  const mode = getConnectionActionMode(options);
  if (mode === 'accepted') return NETWORKING_EVENTS.connectionAccepted;
  if (mode === 'cancelled') return NETWORKING_EVENTS.connectionCancelled;
  return NETWORKING_EVENTS.connectionRequested;
}

export function getConnectionActionSuccessMessage(options = {}) {
  const mode = getConnectionActionMode(options);
  if (mode === 'accepted') return NETWORKING_MESSAGES.success.connectionAccepted;
  if (mode === 'cancelled') return NETWORKING_MESSAGES.success.connectionCancelled;
  return NETWORKING_MESSAGES.success.connectionRequested;
}
