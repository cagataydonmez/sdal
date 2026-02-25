import React, { useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { useAuth } from '../utils/auth.jsx';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }
  return res.json();
}

const yearOptions = (() => {
  const out = [];
  for (let y = 1970; y <= new Date().getFullYear(); y += 1) out.push(String(y));
  out.push('Dışarıdan');
  return out;
})();

export default function TournamentRegisterPage() {
  const { user } = useAuth();
  const [form, setForm] = useState({
    tisim: '',
    tktelefon: '',
    boyismi: '',
    boymezuniyet: '',
    ioyismi: '',
    ioymezuniyet: '',
    uoyismi: '',
    uoymezuniyet: '',
    doyismi: '',
    doymezuniyet: ''
  });
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  async function submit(e) {
    e.preventDefault();
    setError('');
    setStatus('');
    try {
      await apiJson('/api/tournament/register', { method: 'POST', body: JSON.stringify(form) });
      setStatus('Kayıt işleminiz başarıyla tamamlandı!');
      setForm({
        tisim: '',
        tktelefon: '',
        boyismi: '',
        boymezuniyet: '',
        ioyismi: '',
        ioymezuniyet: '',
        uoyismi: '',
        uoymezuniyet: '',
        doyismi: '',
        doymezuniyet: ''
      });
    } catch (err) {
      setError(err.message);
    }
  }

  if (!user) {
    return (
      <LegacyLayout pageTitle="Futbol Turnuvası Kayıt Formu">
        Giriş yapmalısınız.
      </LegacyLayout>
    );
  }

  return (
    <LegacyLayout pageTitle="Futbol Turnuvası Kayıt Formu">
      <table border="0" cellPadding="3" cellSpacing="2" width="100%">
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: 'white' }}>
              <table border="0" cellPadding="3" cellSpacing="1" width="100%">
                <tbody>
                  <tr>
                    <td style={{ border: '1px solid #663300', background: '#660000', color: 'white' }} align="left">
                      <b>SDAL Mezunlar Derneği Futbol Turnuvası</b>
                    </td>
                  </tr>
                  <tr>
                    <td style={{ border: '1px solid #663300', color: '#000033' }} align="left" valign="middle">
                      <font style={{ color: 'red', fontFamily: 'Tahoma', fontSize: 20 }}>
                        15-16 Aralıkta SDAL spor salonunda düzenlenecek turnuva için siz de takımınızı kurun!
                      </font>
                      <br /><br />
                      <font style={{ color: 'black', fontFamily: 'Tahoma', fontSize: 15 }}>
                        Turnuvaya katılmak için aşağıdaki form ile kayıt yaptırmanız gerekmektedir.
                        <br />Takımlar 1 takım kaptanı ve 4 oyuncu olmak üzere toplam 5 kişiden oluşacaktır.
                        <br />Takım kaptanının kayıt yaptırması yeterlidir.
                        <br />Ayrıca SDAL dışından bir kişi takıma dahil edilebilir.
                      </font>
                      <br /><br />
                      <font style={{ color: 'red', fontFamily: 'Tahoma', fontSize: 15 }}>
                        <b>Son Başvuru Tarihi : 12 Aralık 2007<br />
                        Maç Programı Duyuru Tarihi : 13 Aralık 2007</b>
                        <br /><br />* Sorularınız için irtibat telefonları anasayfada bulunmaktadır.
                      </font>
                      <br /><br />
                      <font style={{ color: 'black', fontFamily: 'Tahoma', fontSize: 15 }}>
                        <b>Not :</b> Şehir dışında bulunan arkadaşlarımız için turnuva tarihi bir hafta ileriye alınmıştır.
                      </font>
                    </td>
                  </tr>
                  <tr>
                    <td style={{ border: '1px solid #663300', background: '#660000', color: 'white' }} align="left">
                      <b>Futbol Turnuvası Kayıt Formu</b>
                    </td>
                  </tr>
                  <tr>
                    <td style={{ border: '1px solid #663300', color: '#000033' }} align="left" valign="middle">
                      <form onSubmit={submit}>
                        <div>Takım İsmi</div>
                        <input className="inptxt" value={form.tisim} onChange={(e) => setForm({ ...form, tisim: e.target.value })} />
                        <div>Takım Kaptanı Telefon</div>
                        <input className="inptxt" value={form.tktelefon} onChange={(e) => setForm({ ...form, tktelefon: e.target.value })} />
                        <hr className="sdal-hr" />
                        <div>1. Oyuncu</div>
                        <input className="inptxt" placeholder="İsim" value={form.boyismi} onChange={(e) => setForm({ ...form, boyismi: e.target.value })} />
                        <select className="inptxt" value={form.boymezuniyet} onChange={(e) => setForm({ ...form, boymezuniyet: e.target.value })}>
                          <option value="">Mezuniyet</option>
                          {yearOptions.map((y) => <option key={`b-${y}`} value={y}>{y}</option>)}
                        </select>
                        <div>2. Oyuncu</div>
                        <input className="inptxt" placeholder="İsim" value={form.ioyismi} onChange={(e) => setForm({ ...form, ioyismi: e.target.value })} />
                        <select className="inptxt" value={form.ioymezuniyet} onChange={(e) => setForm({ ...form, ioymezuniyet: e.target.value })}>
                          <option value="">Mezuniyet</option>
                          {yearOptions.map((y) => <option key={`i-${y}`} value={y}>{y}</option>)}
                        </select>
                        <div>3. Oyuncu</div>
                        <input className="inptxt" placeholder="İsim" value={form.uoyismi} onChange={(e) => setForm({ ...form, uoyismi: e.target.value })} />
                        <select className="inptxt" value={form.uoymezuniyet} onChange={(e) => setForm({ ...form, uoymezuniyet: e.target.value })}>
                          <option value="">Mezuniyet</option>
                          {yearOptions.map((y) => <option key={`u-${y}`} value={y}>{y}</option>)}
                        </select>
                        <div>4. Oyuncu</div>
                        <input className="inptxt" placeholder="İsim" value={form.doyismi} onChange={(e) => setForm({ ...form, doyismi: e.target.value })} />
                        <select className="inptxt" value={form.doymezuniyet} onChange={(e) => setForm({ ...form, doymezuniyet: e.target.value })}>
                          <option value="">Mezuniyet</option>
                          {yearOptions.map((y) => <option key={`d-${y}`} value={y}>{y}</option>)}
                        </select>
                        <br />
                        <button className="sub" type="submit">Gönder</button>
                      </form>
                      {status ? <div style={{ color: 'red', fontSize: 20 }}>{status}</div> : null}
                      {error ? <div className="hatamsg1">{error}</div> : null}
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
