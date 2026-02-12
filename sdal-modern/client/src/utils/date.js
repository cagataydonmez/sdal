export function tarihduz(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';

  const aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  const gunler = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'];

  const trh = `${date.getDate()} ${aylar[date.getMonth()]} ${date.getFullYear()} ${gunler[date.getDay()]}`;
  const hasTime = value.includes('T') || value.includes(':');
  if (!hasTime) return trh;

  const saat = String(date.getHours()).padStart(2, '0');
  const dakika = String(date.getMinutes()).padStart(2, '0');
  return `${trh} Saat ${saat}:${dakika}`;
}
