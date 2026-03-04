import { HttpError } from '../shared/httpError.js';

export class ChatService {
  constructor({ messageRepository }) {
    this.messageRepository = messageRepository;
  }

  listMessages({ sinceId, beforeId, limit }) {
    return this.messageRepository.listMessages({ sinceId, beforeId, limit });
  }

  sendMessage({ userId, body }) {
    if (!body) {
      throw new HttpError(400, 'Mesaj boş olamaz.');
    }
    return this.messageRepository.createMessage({
      userId,
      body,
      createdAt: new Date().toISOString()
    });
  }

  updateMessage({ messageId, body, canManage }) {
    if (!messageId) {
      throw new HttpError(400, 'Geçersiz mesaj ID.');
    }
    const existing = this.messageRepository.findMessageById(messageId);
    if (!existing) {
      throw new HttpError(404, 'Mesaj bulunamadı.');
    }
    if (!canManage(existing)) {
      throw new HttpError(403, 'Bu mesajı düzenleme yetkin yok.');
    }
    if (!body) {
      throw new HttpError(400, 'Mesaj boş olamaz.');
    }
    return this.messageRepository.updateMessage(messageId, body);
  }

  deleteMessage({ messageId, canManage }) {
    if (!messageId) {
      throw new HttpError(400, 'Geçersiz mesaj ID.');
    }
    const existing = this.messageRepository.findMessageById(messageId);
    if (!existing) {
      throw new HttpError(404, 'Mesaj bulunamadı.');
    }
    if (!canManage(existing)) {
      throw new HttpError(403, 'Bu mesajı silme yetkin yok.');
    }
    this.messageRepository.deleteMessage(messageId);
    return { ok: true, id: messageId };
  }
}
