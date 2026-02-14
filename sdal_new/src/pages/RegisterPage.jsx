import React, { useMemo, useState } from 'react';
import Layout from '../components/Layout.jsx';

export default function RegisterPage() {
  const [form, setForm] = useState({
    kadi: '',
    sifre: '',
    sifre2: '',
    email: '',
    isim: '',
    soyisim: '',
    mezuniyetyili: ''
  });
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  const years = useMemo(() => {
    const list = [];
    const now = new Date().getFullYear();
    for (let y = now; y >= 1960; y -= 1) list.push(String(y));
    return list;
  }, []);

  async function submit(e) {
    e.preventDefault();
    setError('');
    setStatus('');
    const res = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setStatus('Kayıt tamamlandı. E-posta aktivasyon linkini kontrol edin.');
  }

  return (
    <Layout title="Üyelik">
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <input className="input" placeholder="Kullanıcı adı" value={form.kadi} onChange={(e) => setForm({ ...form, kadi: e.target.value })} />
            <input className="input" type="password" placeholder="Şifre" value={form.sifre} onChange={(e) => setForm({ ...form, sifre: e.target.value })} />
            <input className="input" type="password" placeholder="Şifre tekrar" value={form.sifre2} onChange={(e) => setForm({ ...form, sifre2: e.target.value })} />
            <input className="input" placeholder="Email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            <div className="form-row">
              <label>Mezuniyet Yılı</label>
              <select className="input" value={form.mezuniyetyili} onChange={(e) => setForm({ ...form, mezuniyetyili: e.target.value })}>
                <option value="">Seçiniz</option>
                {years.map((y) => <option key={y} value={y}>{y}</option>)}
              </select>
            </div>
            <input className="input" placeholder="İsim" value={form.isim} onChange={(e) => setForm({ ...form, isim: e.target.value })} />
            <input className="input" placeholder="Soyisim" value={form.soyisim} onChange={(e) => setForm({ ...form, soyisim: e.target.value })} />
            <button className="btn primary" type="submit">Üye Ol</button>
            {status ? <div className="ok">{status}</div> : null}
            {error ? <div className="error">{error}</div> : null}
          </form>
          <div className="muted">
            Aktivasyon e-postası gelmediyse <a href="/new/activation/resend">buradan</a> tekrar gönderebilirsiniz.
          </div>
        </div>
      </div>
    </Layout>
  );
}
