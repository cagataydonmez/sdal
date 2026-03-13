export function unwrapApiData(payload) {
  if (payload && typeof payload === 'object' && Object.prototype.hasOwnProperty.call(payload, 'data')) {
    return payload.data;
  }
  return payload;
}

export async function readApiPayload(res, fallbackMessage = '') {
  const text = await res.text();
  if (!text) {
    return { payload: null, data: null, message: fallbackMessage, code: '' };
  }
  try {
    const payload = JSON.parse(text);
    return {
      payload,
      data: unwrapApiData(payload),
      message: payload?.message || payload?.error || fallbackMessage,
      code: String(payload?.code || '')
    };
  } catch {
    return { payload: null, data: null, message: text || fallbackMessage, code: '' };
  }
}
