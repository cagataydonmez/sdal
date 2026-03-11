import React, { useCallback, useEffect, useMemo, useState } from 'react';
import Layout from '../components/Layout.jsx';

const RELATIONSHIP_TYPES = [
  { value: 'taught_in_class', label: 'Aynı sınıfta ders aldım' },
  { value: 'mentor', label: 'Mentor' },
  { value: 'advisor', label: 'Danışman' }
];

function relationshipLabel(value) {
  return RELATIONSHIP_TYPES.find((item) => item.value === value)?.label || value;
}

export default function TeachersNetworkPage() {
  const [direction, setDirection] = useState('my_teachers');
  const [relationshipType, setRelationshipType] = useState('');
  const [classYear, setClassYear] = useState('');
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [offset, setOffset] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [teacherOptions, setTeacherOptions] = useState([]);
  const [teacherSearch, setTeacherSearch] = useState('');

  const [form, setForm] = useState({
    teacherId: '',
    relationship_type: 'taught_in_class',
    class_year: '',
    notes: ''
  });

  const years = useMemo(() => {
    const now = new Date().getFullYear();
    const all = [];
    for (let y = now; y >= 1999; y -= 1) all.push(String(y));
    return all;
  }, []);

  const loadTeacherOptions = useCallback(async (term = '') => {
    try {
      const params = new URLSearchParams();
      params.set('limit', '30');
      if (term) params.set('term', term);
      const res = await fetch(`/api/new/teachers/options?${params.toString()}`, { credentials: 'include' });
      if (!res.ok) throw new Error(await res.text());
      const payload = await res.json();
      setTeacherOptions(payload.items || []);
    } catch {
      setTeacherOptions([]);
    }
  }, []);

  const load = useCallback(async (nextOffset = 0, append = false) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams();
      params.set('direction', direction);
      params.set('limit', '20');
      params.set('offset', String(nextOffset));
      if (relationshipType) params.set('relationship_type', relationshipType);
      if (classYear) params.set('class_year', classYear);
      const res = await fetch(`/api/new/teachers/network?${params.toString()}`, { credentials: 'include' });
      if (!res.ok) throw new Error(await res.text());
      const payload = await res.json();
      const nextItems = payload.items || [];
      setItems((prev) => (append ? [...prev, ...nextItems] : nextItems));
      setOffset(nextOffset + nextItems.length);
      setHasMore(Boolean(payload.hasMore));
    } catch (err) {
      setError(err.message || 'Öğretmen ağı yüklenemedi.');
    } finally {
      setLoading(false);
    }
  }, [direction, relationshipType, classYear]);

  useEffect(() => {
    loadTeacherOptions('');
  }, [loadTeacherOptions]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadTeacherOptions(teacherSearch);
    }, 250);
    return () => clearTimeout(timer);
  }, [teacherSearch, loadTeacherOptions]);

  useEffect(() => {
    load(0, false);
  }, [load]);

  async function submitLink(e) {
    e.preventDefault();
    setError('');
    setStatus('');
    const teacherId = Number(form.teacherId || 0);
    if (!teacherId) {
      setError('Lütfen listeden bir öğretmen seçin.');
      return;
    }
    const body = {
      relationship_type: form.relationship_type,
      notes: String(form.notes || '').trim()
    };
    const selectedClassYear = Number(form.class_year || 0);
    if (selectedClassYear >= 1950 && selectedClassYear <= 2100) body.class_year = selectedClassYear;

    const res = await fetch(`/api/new/teachers/network/link/${teacherId}`, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setStatus('Öğretmen bağlantısı eklendi.');
    setForm({ teacherId: '', relationship_type: 'taught_in_class', class_year: '', notes: '' });
    load(0, false);
  }

  return (
    <Layout title="Öğretmen Ağı">
      <div className="panel">
        <h3>Öğretmen bağlantısı ekle</h3>
        <div className="panel-body">
          <form onSubmit={submitLink}>
            <div className="form-row">
              <label>Öğretmen ara</label>
              <input
                className="input"
                placeholder="Kullanıcı adı veya ad soyad"
                value={teacherSearch}
                onChange={(e) => setTeacherSearch(e.target.value)}
              />
            </div>
            <div className="form-row">
              <label>Öğretmen seç</label>
              <select
                className="input"
                value={form.teacherId}
                onChange={(e) => setForm((prev) => ({ ...prev, teacherId: e.target.value }))}
                required
              >
                <option value="">Öğretmen seçiniz</option>
                {teacherOptions.map((teacher) => (
                  <option key={teacher.id} value={teacher.id}>
                    @{teacher.kadi} · {teacher.isim || ''} {teacher.soyisim || ''}
                  </option>
                ))}
              </select>
            </div>
            <div className="form-row">
              <label>İlişki türü</label>
              <select
                className="input"
                value={form.relationship_type}
                onChange={(e) => setForm((prev) => ({ ...prev, relationship_type: e.target.value }))}
              >
                {RELATIONSHIP_TYPES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
              </select>
            </div>
            <div className="form-row">
              <label>Sınıf yılı (opsiyonel)</label>
              <select className="input" value={form.class_year} onChange={(e) => setForm((prev) => ({ ...prev, class_year: e.target.value }))}>
                <option value="">Seçiniz</option>
                {years.map((y) => <option key={y} value={y}>{y}</option>)}
              </select>
            </div>
            <div className="form-row">
              <label>Not (opsiyonel)</label>
              <textarea className="input" value={form.notes} onChange={(e) => setForm((prev) => ({ ...prev, notes: e.target.value }))} maxLength={500} />
            </div>
            <button className="btn primary" type="submit">Bağlantıyı Kaydet</button>
          </form>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="panel">
        <h3>Bağlantı geçmişi</h3>
        <div className="panel-body">
          <div className="composer-actions" style={{ marginBottom: 12 }}>
            <select className="input" value={direction} onChange={(e) => setDirection(e.target.value)}>
              <option value="my_teachers">Öğretmenlerim</option>
              <option value="my_students">Öğrencilerim</option>
            </select>
            <select className="input" value={relationshipType} onChange={(e) => setRelationshipType(e.target.value)}>
              <option value="">Tüm ilişki türleri</option>
              {RELATIONSHIP_TYPES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
            </select>
            <select className="input" value={classYear} onChange={(e) => setClassYear(e.target.value)}>
              <option value="">Tüm yıllar</option>
              {years.map((y) => <option key={y} value={y}>{y}</option>)}
            </select>
            <button className="btn ghost" type="button" onClick={() => load(0, false)} disabled={loading}>Filtreyi Uygula</button>
          </div>

          {!items.length && !loading ? <div className="muted">Henüz öğretmen ağı bağlantısı bulunmuyor.</div> : null}
          {items.map((item) => (
            <article key={item.id} className="card" style={{ marginBottom: 10 }}>
              <div className="meta"><strong>@{item.kadi || 'uye'}</strong> · {item.isim || ''} {item.soyisim || ''}</div>
              <div className="meta">İlişki: {relationshipLabel(item.relationship_type)}</div>
              {item.class_year ? <div className="meta">Sınıf yılı: {item.class_year}</div> : null}
              {item.notes ? <div>{item.notes}</div> : null}
            </article>
          ))}

          {hasMore ? (
            <button className="btn ghost" type="button" onClick={() => load(offset, true)} disabled={loading}>
              {loading ? 'Yükleniyor...' : 'Daha Fazla'}
            </button>
          ) : null}
        </div>
      </div>
    </Layout>
  );
}
