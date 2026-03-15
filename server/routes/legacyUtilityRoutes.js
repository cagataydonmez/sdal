import path from 'path';

export function registerLegacyUtilityRoutes(app, deps) {
  const {
    legacyMediaDir,
    legacyRoot,
    issueCaptcha,
    resolveMediaFile,
    sendImage,
    sendSvg,
    svgTextImage,
    parseLegacyBool,
    sqlAll,
    sqlGet,
    sqlRun,
    sqlGetAsync,
    sqlAllAsync,
    sqlRunAsync,
    toLocalDateParts,
    getCurrentUser,
    formatUserText
  } = deps;

  app.get('/api/media/vesikalik/:file', (req, res) => {
    const filePath = resolveMediaFile(req.params.file) || path.join(legacyMediaDir, 'vesikalik', 'nophoto.jpg');
    res.setHeader('Cache-Control', 'public, max-age=3600, stale-while-revalidate=86400');
    res.setHeader('Vary', 'Accept-Encoding');
    res.sendFile(filePath);
  });

  app.get('/api/media/kucukresim', async (req, res) => {
    const width = parseInt(req.query.width || req.query.iwidth || '0', 10);
    const height = parseInt(req.query.height || req.query.iheight || '0', 10);
    const file = req.query.file || req.query.r;
    const filePath = resolveMediaFile(file);
    if (!filePath) return res.status(404).send('File not found');

    const resize = width || height ? { width: width || null, height: height || null, fit: 'inside' } : null;
    await sendImage(res, filePath, { resize });
  });

  app.get('/aspcaptcha.asp', (req, res) => issueCaptcha(req, res));

  app.get('/textimage.asp', (req, res) => {
    const text = req.query.t || req.query.text || 'cagatay';
    sendSvg(res, svgTextImage(text));
  });

  app.get('/uyelerkadiresimyap.asp', (req, res) => {
    const text = req.query.kadi || '';
    sendSvg(res, svgTextImage(text));
  });

  app.get('/tid.asp', (_req, res) => {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send('<body bgcolor="#ffffcc"><img src="/textimage.asp" /></body>');
  });

  app.get('/grayscale.asp', (req, res) => {
    req.session.grayscale = parseLegacyBool(req.session.grayscale) ? '' : 'evet';
    res.redirect(302, '/');
  });

  app.get('/threshold.asp', (req, res) => {
    req.session.threshold = parseLegacyBool(req.session.threshold) ? '' : 'evet';
    res.redirect(302, '/');
  });

  app.get('/kucukresim.asp', async (req, res) => {
    const width = parseInt(req.query.iwidth || '0', 10);
    const height = parseInt(req.query.iheight || '0', 10);
    const file = req.query.r;
    const filePath = resolveMediaFile(file);
    if (!filePath) return res.status(404).send('File not found');
    let resize = null;
    if (width) resize = { width, height: null, fit: 'inside' };
    if (height) {
      resize = { width: width || null, height: height || null, fit: 'inside' };
      if (!width && height) {
        resize = { width: 150, height, fit: 'inside' };
      }
    }
    await sendImage(res, filePath, { resize });
  });

  app.get('/kucukresim2.asp', async (req, res) => {
    const width = parseInt(req.query.iwidth || '138', 10) || 138;
    const file = req.query.r;
    const filePath = resolveMediaFile(file);
    if (!filePath) return res.status(404).send('File not found');
    const grayscale = parseLegacyBool(req.session.grayscale);
    const threshold = parseLegacyBool(req.session.threshold) ? 80 : null;
    await sendImage(res, filePath, { resize: { width, height: null, fit: 'inside' }, grayscale, threshold });
  });

  app.get('/kucukresim3.asp', async (req, res) => {
    const file = req.query.r;
    const filePath = resolveMediaFile(file);
    if (!filePath) return res.status(404).send('File not found');
    await sendImage(res, filePath, { resize: { width: 1300, height: null, fit: 'inside' } });
  });

  app.get('/kucukresim4.asp', async (req, res) => {
    const file = req.query.r;
    const filePath = resolveMediaFile(file);
    if (!filePath) return res.status(404).send('File not found');
    await sendImage(res, filePath);
  });

  app.get('/kucukresim5.asp', async (req, res) => {
    const file = req.query.r;
    const filePath = resolveMediaFile(file);
    if (!filePath) return res.status(404).send('File not found');
    await sendImage(res, filePath, { resize: { width: 50, height: 50, fit: 'inside' } });
  });

  app.get('/kucukresim6.asp', async (req, res) => {
    const width = parseInt(req.query.iwidth || '0', 10);
    const height = parseInt(req.query.iheight || '0', 10);
    const file = req.query.r;
    const filePath = resolveMediaFile(file);
    if (!filePath) return res.status(404).send('File not found');
    const resize = width || height ? { width: width || null, height: height || null, fit: 'inside' } : null;
    await sendImage(res, filePath, { resize });
  });

  app.get('/kucukresim7.asp', async (req, res) => {
    const file = req.query.r;
    const filePath = resolveMediaFile(file);
    if (!filePath) return res.status(404).send('File not found');
    await sendImage(res, filePath, { resize: { width: 1300, height: null, fit: 'inside' } });
  });

  app.get('/kucukresim8.asp', async (req, res) => {
    const file = req.query.r;
    const filePath = resolveMediaFile(file);
    if (!filePath) return res.status(404).send('File not found');
    await sendImage(res, filePath, { resize: { width: 800, height: 554, fit: 'inside' } });
  });

  app.get('/resimler_xml.asp', async (_req, res) => {
    try {
      const rows = await sqlAllAsync('SELECT dosyaadi, baslik FROM album_foto WHERE katid = ? AND aktif = 1 ORDER BY hit', ['5']);
      const escapeXml = (value) =>
        String(value || '')
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;')
          .replace(/"/g, '&quot;');
      let body = '<?xml version="1.0" encoding="utf-8" standalone="yes"?>\n<images>\n';
      rows.forEach((row) => {
        body += `  <pic>\n    <image>kucukresim8.asp?r=${encodeURIComponent(row.dosyaadi || '')}</image>\n    <caption>${escapeXml(row.baslik)}</caption>\n  </pic>\n`;
      });
      body += '</images>';
      res.setHeader('Content-Type', 'application/xml; charset=utf-8');
      res.send(body);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/aihepsi.asp', async (_req, res) => {
    try {
      const rows = await sqlAllAsync('SELECT kadi, metin, tarih FROM hmes ORDER BY id DESC');
      let html = '<table border="0" cellpadding="3" cellspacing="0" width="100%" height="100%"><tr><td valign="top" style="border:1px solid #000033;background:white;font-family:tahoma;font-size:11;color:#000033;">';
      if (!rows.length) {
        html += 'Henüz mesaj yazılmamış.';
      } else {
        rows.forEach((row, idx) => {
          html += `${idx + 1} - <b>${row.kadi || ''}</b> - ${row.metin || ''} - ${row.tarih || ''}<br>`;
        });
      }
      html += '</td></tr></table>';
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.send(html);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/aihepsigor.asp', (_req, res) => {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(
      `<script language="javascript">
function createRequest(){var r=false;try{r=new XMLHttpRequest();}catch(t){try{r=new ActiveXObject("Msxml2.XMLHTTP");}catch(o){try{r=new ActiveXObject("Microsoft.XMLHTTP");}catch(f){r=false;}}}if(!r)alert("Error initializing XMLHttpRequest!");return r;}
function aihepsicek(){request=createRequest();var url="aihepsi.asp";url=url+"?sid="+Math.random();request.onreadystatechange=updatePage;request.open("GET",url,true);request.send(null);}
function updatePage(){if(request.readyState==4||request.readyState=="complete")if(request.status==200)document.getElementById("aihep").innerHTML=request.responseText;else if(request.status==404)alert("Request URL does not exist");else alert("Error: status code is "+request.status);}
aihepsicek();
</script>
<div id="aihep"><center><b>Lütfen bekleyiniz..<br><br><img src="yukleniyor.gif" border="0"></b></center></div>`
    );
  });

  app.get('/ayax.asp', async (req, res) => {
    try {
      const user = await sqlGetAsync('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId]);
      const kadi = user?.kadi || '';
      res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
      res.send(
        `var xmlHttp;
function hmesajisle(str){xmlHttp=GetXmlHttpObject();if(xmlHttp==null){document.getElementById("hmkutusu").innerHTML="Baglanti kurulamadi..";return;}
var url="hmesisle.asp";var kimden=${JSON.stringify(kadi)};
url=url+"?mes="+encodeURI(str);url=url+"&sid="+Math.random();url=url+"&kimden="+encodeURI(kimden);
xmlHttp.onreadystatechange=stateChanged;xmlHttp.open("GET",url,true);xmlHttp.send(null);}
function stateChanged(){if(xmlHttp.readyState==4||xmlHttp.readyState=="complete"){if(request.status==200)document.getElementById("hmkutusu").innerHTML=xmlHttp.responseText;else if(request.status==12007)document.getElementById("hmkutusu").innerHTML="Internet baglantisi kurulamadi..";else document.getElementById("hmkutusu").innerHTML="Error: status code is "+request.status;}}
function GetXmlHttpObject(){var objXMLHttp=null;if(window.XMLHttpRequest){objXMLHttp=new XMLHttpRequest();}else if(window.ActiveXObject){objXMLHttp=new ActiveXObject("Microsoft.XMLHTTP");}return objXMLHttp;}`
      );
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/hmesisle.asp', async (req, res) => {
    try {
      if (!req.session.userId) {
        return res.status(403).send('Üye Girişi Yapılmamış!');
      }

      const kimden = req.query.kimden || '';
      const mesaj = String(req.query.mes || '').substring(0, 60);
      if (mesaj && mesaj !== 'ilkgiris2222tttt') {
        const rows = await sqlAllAsync('SELECT id, kadi FROM uyeler WHERE id = ?', [req.session.userId]);
        if (rows.length) {
          const localParts = toLocalDateParts(new Date());
          await sqlRunAsync('UPDATE uyeler SET sonislemtarih = ?, sonislemsaat = ?, sonip = ?, online = 1 WHERE id = ?', [
            localParts.date,
            localParts.time,
            req.ip,
            req.session.userId
          ]);
        }
        await sqlRunAsync('INSERT INTO hmes (kadi, metin, tarih) VALUES (?, ?, ?)', [kimden || rows[0]?.kadi || '', mesaj, new Date().toISOString()]);
      }

      const list = await sqlAllAsync('SELECT kadi, metin FROM hmes ORDER BY id DESC LIMIT 20');
      let html = '<table border="0" cellpadding="3" cellspacing="0" width="100%" height="100%"><tr><td valign="top" style="border:1px solid #000033;background:white;font-family:tahoma;font-size:11;color:#000033;">';
      if (!list.length) {
        html += 'Henüz mesaj yazılmamış.';
      } else {
        list.forEach((row) => {
          html += `<b>${row.kadi || ''}</b> - ${row.metin || ''}<br>`;
        });
      }
      html += '</td></tr></table>';
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.send(html);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/onlineuyekontrol.asp', async (req, res) => {
    try {
      const rows = await sqlAllAsync("SELECT id, kadi FROM uyeler WHERE online = 1 AND (role IS NULL OR LOWER(role) != 'root') ORDER BY kadi");
      if (!rows.length) return res.send(' Şu an sitede online üye bulunmamaktadır.');
      let html = '<br>&nbsp;Şu anda sitede dolaşanlar : ';
      rows.forEach((row, idx) => {
        if (idx > 0) html += ',';
        if (req.session.userId) {
          html += `<a href="uyedetay.asp?id=${row.id}" title="Üye Detayları" style="color:#ffffcc;">${row.kadi}</a>`;
        } else {
          html += row.kadi;
        }
      });
      res.send(html);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/onlineuyekontrol2.asp', async (req, res) => {
    try {
      const rows = await sqlAllAsync("SELECT id, kadi, resim, mezuniyetyili, isim, soyisim, sonislemtarih, sonislemsaat, online FROM uyeler WHERE online = 1 AND (role IS NULL OR LOWER(role) != 'root') ORDER BY kadi");
      if (!rows.length) return res.send(' Şu an sitede online üye bulunmamaktadır.');
      const now = new Date();
      let html = '';
      for (const row of rows) {
        const ts = row.sonislemtarih && row.sonislemsaat ? new Date(`${row.sonislemtarih}T${row.sonislemsaat}`) : null;
        if (ts && Number.isFinite(ts.getTime())) {
          const diffMin = Math.floor((now - ts) / 60000);
          if (diffMin > 20) {
            await sqlRunAsync('UPDATE uyeler SET online = 0 WHERE id = ?', [row.id]);
            continue;
          }
          html += `<img src="arrow-orange.gif" border="0"><a href="uyedetay.asp?id=${row.id}" class="hintanchor" style="color:#663300;">${row.kadi}</a><br>`;
        }
      }
      res.send(html || ' Şu an sitede online üye bulunmamaktadır.');
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.all('/oyunyilanislem.asp', async (req, res) => {
    try {
      if (req.query.naap === '2222tttt') {
        await sqlRunAsync('DELETE FROM oyun_yilan');
        return res.send('Hepsi silindi!');
      }
      const islem = req.body.islem || req.query.islem || '';
      if (islem === 'puanekle') {
        const user = getCurrentUser(req);
        const name = user?.kadi || req.cookies.kadi || 'Misafir';
        const score = Number(req.body.puan || req.query.puan || 0);
        const existing = await sqlGetAsync('SELECT * FROM oyun_yilan WHERE isim = ?', [name]);
        if (!existing) {
          await sqlRunAsync('INSERT INTO oyun_yilan (isim, skor, tarih) VALUES (?, ?, ?)', [name, score, new Date().toISOString()]);
        } else if (score > Number(existing.skor || 0)) {
          await sqlRunAsync('UPDATE oyun_yilan SET skor = ?, tarih = ? WHERE isim = ?', [score, new Date().toISOString(), name]);
        }
      }
      const rows = await sqlAllAsync('SELECT isim, skor FROM oyun_yilan ORDER BY skor DESC LIMIT 25');
      let html = '<table border="0" width="100%" cellpadding="1" cellspacing="0"><tr><td colspan="2" style="font-family:arial;font-size:11;background:#660000;color:white;border:1 solid #660000;"><b>En Yüksek Puanlar</b></td></tr>';
      rows.forEach((row, idx) => {
        const stripe = idx % 2 === 0 ? 'background:#ededed;' : '';
        html += `<tr><td width="50%" style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-right:0;${stripe}"><b>${idx + 1}. </b>${String(row.isim || '').substring(0, 15)}</td><td width="50%" style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;${stripe}" align="right">${row.skor || 0}</td></tr>`;
      });
      html += '</table>';
      res.send(html);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.all('/oyuntetrisislem.asp', async (req, res) => {
    try {
      if (req.query.naap === '2222tttt') {
        await sqlRunAsync('DELETE FROM oyun_tetris');
        return res.send('Hepsi silindi!');
      }
      const islem = req.body.islem || req.query.islem || '';
      if (islem === 'puanekle') {
        const user = getCurrentUser(req);
        const name = user?.kadi || req.cookies.kadi || 'Misafir';
        const puan = Number(req.body.puan || req.query.puan || 0);
        const seviye = Number(req.body.seviye || req.query.seviye || 0);
        const satir = Number(req.body.satir || req.query.satir || 0);
        const existing = await sqlGetAsync('SELECT * FROM oyun_tetris WHERE isim = ?', [name]);
        if (!existing) {
          await sqlRunAsync('INSERT INTO oyun_tetris (isim, puan, seviye, satir, tarih) VALUES (?, ?, ?, ?, ?)', [name, puan, seviye, satir, new Date().toISOString()]);
        } else if (puan > Number(existing.puan || 0)) {
          await sqlRunAsync('UPDATE oyun_tetris SET puan = ?, seviye = ?, satir = ?, tarih = ? WHERE isim = ?', [puan, seviye, satir, new Date().toISOString(), name]);
        }
      }
      const rows = await sqlAllAsync('SELECT isim, puan, seviye, satir FROM oyun_tetris ORDER BY puan DESC LIMIT 25');
      let html = '<table border="0" width="100%" cellpadding="1" cellspacing="0"><tr><td colspan="4" style="font-family:arial;font-size:11;background:#660000;color:white;border:1 solid #660000;border-top:1 solid white;"><b>En Yüksek Puanlar</b></td></tr>';
      html += '<tr><td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">İsim</td><td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">Puan</td><td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">Seviye</td><td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">Satır</td></tr>';
      rows.forEach((row, idx) => {
        const stripe = idx % 2 === 0 ? 'background:#ededed;' : '';
        html += `<tr><td style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;${stripe}"><b>${idx + 1}. </b>${String(row.isim || '').substring(0, 15)}</td><td style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;${stripe}" align="left">${row.puan || 0}</td><td style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;${stripe}" align="left">${row.seviye || 0}</td><td style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;${stripe}" align="left">${row.satir || 0}</td></tr>`;
      });
      html += '</table>';
      res.send(html);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/mesajsil.asp', async (req, res) => {
    try {
      if (!req.session.userId) return res.redirect(302, '/login');
      const mesid = req.query.mid;
      const k = req.query.kk || '0';
      if (!mesid) return res.redirect(302, '/');
      const row = await sqlGetAsync('SELECT * FROM gelenkutusu WHERE id = ?', [mesid]);
      if (!row) return res.redirect(302, `/mesajlar?k=${k}`);
      if (String(row.kime) === String(req.session.userId)) {
        await sqlRunAsync('UPDATE gelenkutusu SET aktifgelen = 0 WHERE id = ?', [mesid]);
      }
      if (String(row.kimden) === String(req.session.userId)) {
        await sqlRunAsync('UPDATE gelenkutusu SET aktifgiden = 0 WHERE id = ?', [mesid]);
      }
      res.redirect(302, `/mesajlar?k=${k}`);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/albumyorumekle.asp', async (req, res) => {
    try {
      if (!req.session.userId) return res.redirect(302, '/login');
      const fid = req.body.fid;
      if (!fid) return res.redirect(302, '/album');
      const yorum = formatUserText(req.body.yorum || '');
      if (!yorum) return res.status(400).send('Yorum girmedin');
      const user = getCurrentUser(req);
      await sqlRunAsync('INSERT INTO album_fotoyorum (fotoid, uyeadi, yorum, tarih) VALUES (?, ?, ?, ?)', [
        fid,
        user?.kadi || 'Misafir',
        yorum,
        new Date().toISOString()
      ]);
      res.redirect(302, `/album/foto/${fid}`);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/fizikselyol.asp', (_req, res) => {
    res.send(legacyRoot);
  });

  app.get('/abandon.asp', (req, res) => {
    req.session.destroy(() => {
      res.redirect(302, '/');
    });
  });

  app.get('/logout', async (req, res) => {
    try {
      if (req.session.userId) {
        await sqlRunAsync('UPDATE uyeler SET online = 0 WHERE id = ?', [req.session.userId]);
      }
      req.session.destroy(() => {
        res.clearCookie('uyegiris');
        res.clearCookie('uyeid');
        res.clearCookie('kadi');
        res.clearCookie('admingiris');
        res.redirect(302, '/new/login');
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/admincikis.asp', (req, res) => {
    req.session.adminOk = false;
    res.redirect(302, '/admin');
  });
}
