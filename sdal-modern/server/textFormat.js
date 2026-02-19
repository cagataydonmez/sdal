const smileyMap = [
  ':)', ':@', ':))', '8)', ":'(", ':$', ':D', ':*', ':)))', ':#', '*-)', ':(', ':o', ':P', '(:/', ';)' 
];
const smileyAlt = [
  ':y1:', ':y2:', ':y3:', ':y4:', ':y5:', ':y6:', ':y7:', ':y8:', ':y9:', ':y10:', ':y11:', ':y12:', ':y13:', ':y14:', ':y15:', ':y16:'
];

export function metinDuzenle(input) {
  if (input == null) return '';
  let metin = String(input);
  metin = metin.replace(/</g, '&lt;').replace(/>/g, '&gt;');
  metin = metin.replace(/\r?\n/g, '<br>');

  // links
  const parts = metin.split(' ');
  for (let i = 0; i < parts.length; i += 1) {
    let token = parts[i];
    const lines = token.split('<br>');
    for (let j = 0; j < lines.length; j += 1) {
      const word = lines[j];
      if (word.includes('http://')) {
        lines[j] = `<a href="${word}" class=link target="_blank">${word}</a>`;
      } else if (word.includes('www.')) {
        lines[j] = `<a href="http://${word}" class=link target="_blank">${word}</a>`;
      } else if (/\.(com|net|org|edu|tr)/i.test(word)) {
        lines[j] = `<a href="http://www.${word}" class=link target="_blank">${word}</a>`;
      }
    }
    parts[i] = lines.join('<br>');
  }
  metin = parts.join(' ');

  metin = metin.replace(/\t/g, '   ').replace(/  /g, '&nbsp;&nbsp;');

  let mesaj = metin
    .replace(/\[b\]/g, '<b>').replace(/\[\/b\]/g, '</b>')
    .replace(/\[i\]/g, '<i>').replace(/\[\/i\]/g, '</i>')
    .replace(/\[u\]/g, '<u>').replace(/\[\/u\]/g, '</u>')
    .replace(/\[s\]/g, '<s>').replace(/\[\/s\]/g, '</s>')
    .replace(/\[strike\]/g, '<s>').replace(/\[\/strike\]/g, '</s>')
    .replace(/\[ul\]/g, '<ul>').replace(/\[\/ul\]/g, '</ul>')
    .replace(/\[ol\]/g, '<ol>').replace(/\[\/ol\]/g, '</ol>')
    .replace(/\[li\]/g, '<li>').replace(/\[\/li\]/g, '</li>')
    .replace(/\[sagayasla\]/g, '<div align=right>').replace(/\[\/sagayasla\]/g, '</div>')
    .replace(/\[solayasla\]/g, '<div align=left>').replace(/\[\/solayasla\]/g, '</div>')
    .replace(/\[ortala\]/g, '<center>').replace(/\[\/ortala\]/g, '</center>')
    .replace(/\[left\]/g, '<div style="text-align:left;">').replace(/\[\/left\]/g, '</div>')
    .replace(/\[center\]/g, '<div style="text-align:center;">').replace(/\[\/center\]/g, '</div>')
    .replace(/\[right\]/g, '<div style="text-align:right;">').replace(/\[\/right\]/g, '</div>')
    .replace(/\[justify\]/g, '<div style="text-align:justify;">').replace(/\[\/justify\]/g, '</div>')
    .replace(/\[listele\]/g, '<li>')
    .replace(/\[quote\]/g, '<blockquote>').replace(/\[\/quote\]/g, '</blockquote>')
    .replace(/\[code\]/g, '<pre><code>').replace(/\[\/code\]/g, '</code></pre>')
    .replace(/\[mavi\]/g, '<font style=color:blue;>').replace(/\[\/mavi\]/g, '</font>')
    .replace(/\[sari\]/g, '<font style=color:yellow;>').replace(/\[\/sari\]/g, '</font>')
    .replace(/\[yesil\]/g, '<font style=color:green;>').replace(/\[\/yesil\]/g, '</font>')
    .replace(/\[lacivert\]/g, '<font style=color:darkblue;>').replace(/\[\/lacivert\]/g, '</font>')
    .replace(/\[kayfe\]/g, '<font style=color:brown;>').replace(/\[\/kayfe\]/g, '</font>')
    .replace(/\[pembe\]/g, '<font style=color:pink;>').replace(/\[\/pembe\]/g, '</font>')
    .replace(/\[kirmizi\]/g, '<font style=color:red;>').replace(/\[\/kirmizi\]/g, '</font>')
    .replace(/\[portakal\]/g, '<font style=color:orange;>').replace(/\[\/portakal\]/g, '</font>');

  mesaj = mesaj.replace(/\[size=(\d{1,3})\]([\s\S]*?)\[\/size\]/gi, (_m, size, text) => {
    const px = Math.max(10, Math.min(72, Number(size || 14)));
    return `<span style="font-size:${px}px;line-height:1.45;">${text}</span>`;
  });
  mesaj = mesaj.replace(/\[color=([#a-zA-Z0-9(),.\s%-]{1,30})\]([\s\S]*?)\[\/color\]/gi, (_m, color, text) => {
    const safe = String(color || '').replace(/"/g, '').trim();
    return `<span style="color:${safe};">${text}</span>`;
  });

  for (let i = 0; i < smileyMap.length; i += 1) {
    const img = `<img src=/smiley/${i + 1}.gif border=0 width=19 height=19>`;
    if (i !== 0 && i !== 2) {
      mesaj = mesaj.split(smileyMap[i]).join(img);
    }
    mesaj = mesaj.split(smileyAlt[i]).join(img);
  }
  mesaj = mesaj.split(smileyMap[2]).join('<img src=/smiley/3.gif border=0 width=19 height=19>');
  mesaj = mesaj.split(smileyMap[0]).join('<img src=/smiley/1.gif border=0 width=19 height=19>');

  return mesaj;
}
