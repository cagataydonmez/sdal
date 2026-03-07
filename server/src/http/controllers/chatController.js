import { isHttpError } from '../../shared/httpError.js';
import { toLegacyChatMessageItem } from '../dto/legacyApiMappers.js';

export function createChatController({
  chatService,
  formatUserText,
  isFormattedContentEmpty,
  canManageChatMessage,
  broadcastChatMessage,
  broadcastChatUpdate,
  broadcastChatDelete,
  scheduleEngagementRecalculation
}) {
  async function listMessages(req, res) {
    try {
      const sinceId = parseInt(req.query.sinceId || '0', 10) || 0;
      const beforeId = parseInt(req.query.beforeId || '0', 10) || 0;
      const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 200);
      const messages = await chatService.listMessages({ sinceId, beforeId, limit });
      return res.json({ items: messages.map((message) => toLegacyChatMessageItem(message)) });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('chat.listMessages failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function sendMessage(req, res) {
    try {
      const rawMessage = String(req.body?.message || '').slice(0, 5000);
      const message = formatUserText(rawMessage);
      const body = isFormattedContentEmpty(message) ? '' : message;
      const created = await chatService.sendMessage({
        userId: req.session.userId,
        body
      });
      const item = created ? toLegacyChatMessageItem(created) : null;
      if (item) {
        broadcastChatMessage(item);
      }
      scheduleEngagementRecalculation('chat_message_created');
      return res.json({ ok: true, id: created?.id, item });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('chat.sendMessage failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function updateMessage(req, res) {
    try {
      const messageId = Number(req.params.id || 0);
      const rawMessage = String(req.body?.message || '').slice(0, 5000);
      const message = formatUserText(rawMessage);
      const body = isFormattedContentEmpty(message) ? '' : message;

      const updated = await chatService.updateMessage({
        messageId,
        body,
        canManage: (item) => canManageChatMessage(req, { id: item.id, user_id: item.authorId })
      });

      const item = updated ? toLegacyChatMessageItem(updated) : null;
      if (item) {
        broadcastChatUpdate(item);
      }
      return res.json({ ok: true, item });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('chat.updateMessage failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function deleteMessage(req, res) {
    try {
      const messageId = Number(req.params.id || 0);
      await chatService.deleteMessage({
        messageId,
        canManage: (item) => canManageChatMessage(req, { id: item.id, user_id: item.authorId })
      });
      broadcastChatDelete(messageId);
      scheduleEngagementRecalculation('chat_message_deleted');
      return res.json({ ok: true });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('chat.deleteMessage failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  return {
    listMessages,
    sendMessage,
    updateMessage,
    deleteMessage
  };
}
