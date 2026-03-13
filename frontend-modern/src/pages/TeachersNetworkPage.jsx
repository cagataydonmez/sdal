import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { readApiPayload } from '../utils/api.js';

const RELATIONSHIP_TYPES = [
  { value: 'taught_in_class', label: 'Aynı sınıfta ders aldım' },
  { value: 'mentor', label: 'Mentor' },
  { value: 'advisor', label: 'Danışman' }
];

const RELATIONSHIP_HELPERS = {
  taught_in_class: 'Dersi doğrudan bu öğretmenden aldıysan kullan. Mezuniyet yılı ile birlikte girildiğinde bağ daha okunabilir olur.',
  mentor: 'Resmi veya gayriresmi mentorluk, proje yönlendirmesi ya da kariyer rehberliği aldıysan seç.',
  advisor: 'Kulüp, bölüm, proje veya akademik danışmanlık ilişkisini belirtmek için uygundur.'
};

function relationshipLabel(value) {
  return RELATIONSHIP_TYPES.find((item) => item.value === value)?.label || value;
}

function teacherOptionLabel(teacher) {
  const fullName = [teacher?.isim, teacher?.soyisim].filter(Boolean).join(' ').trim();
  return fullName ? `@${teacher.kadi} · ${fullName}` : `@${teacher.kadi || 'ogretmen'}`;
}

export default function TeachersNetworkPage() {
  const [searchParams] = useSearchParams();
  const deepLinkedTeacherId = Math.max(parseInt(searchParams.get('teacherId') || '0', 10), 0);
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
  const [submitting, setSubmitting] = useState(false);

  const [form, setForm] = useState({
    teacherId: deepLinkedTeacherId > 0 ? String(deepLinkedTeacherId) : '',
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

  const selectedTeacher = teacherOptions.find((teacher) => String(teacher.id) === String(form.teacherId));
  const activeHistoryTitle = direction === 'my_teachers' ? 'Eklediğin öğretmen bağlantıları' : 'Sana bağlı öğrenciler';
  const activeHistorySubtitle = direction === 'my_teachers'
    ? 'Bu görünüm mezun olarak ilişkilendirdiğin öğretmenleri ve geçmiş bağlarını gösterir.'
    : 'Bu görünüm öğretmen hesabına bağlanan öğrencileri ve ilişki bağlamını listeler.';
  const relationshipHelper = RELATIONSHIP_HELPERS[form.relationship_type] || RELATIONSHIP_HELPERS.taught_in_class;

  const loadTeacherOptions = useCallback(async (term = '') => {
    try {
      const params = new URLSearchParams();
      params.set('limit', '30');
      if (term) params.set('term', term);
      if (deepLinkedTeacherId > 0) params.set('include_id', String(deepLinkedTeacherId));
      const res = await fetch(`/api/new/teachers/options?${params.toString()}`, { credentials: 'include' });
      const { data, message } = await readApiPayload(res, 'Öğretmen listesi alınamadı.');
      if (!res.ok) throw new Error(message);
      const nextItems = data?.items || [];
      setTeacherOptions(nextItems);
      if (deepLinkedTeacherId > 0) {
        const hasDeepLinkedTeacher = nextItems.some((teacher) => Number(teacher.id) === deepLinkedTeacherId);
        if (hasDeepLinkedTeacher) {
          setForm((prev) => (prev.teacherId ? prev : { ...prev, teacherId: String(deepLinkedTeacherId) }));
        }
      }
    } catch {
      setTeacherOptions([]);
    }
  }, [deepLinkedTeacherId]);

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
      const { message, data } = await readApiPayload(res, 'Öğretmen ağı yüklenemedi.');
      if (!res.ok) throw new Error(message);
      const nextItems = data?.items || [];
      setItems((prev) => (append ? [...prev, ...nextItems] : nextItems));
      setOffset(nextOffset + nextItems.length);
      setHasMore(Boolean(data?.hasMore));
    } catch (err) {
      setError(err.message || 'Öğretmen ağı yüklenemedi.');
    } finally {
      setLoading(false);
    }
  }, [classYear, direction, relationshipType]);

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

    setSubmitting(true);
    try {
      const res = await fetch(`/api/new/teachers/network/link/${teacherId}`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
      const { message } = await readApiPayload(res, 'Öğretmen bağlantısı kaydedilemedi.');
      if (!res.ok) {
        setError(message);
        return;
      }
      setStatus(message || 'Öğretmen bağlantısı başarıyla kaydedildi.');
      setForm((prev) => ({
        ...prev,
        teacherId: '',
        relationship_type: 'taught_in_class',
        class_year: '',
        notes: ''
      }));
      await Promise.all([load(0, false), loadTeacherOptions(teacherSearch)]);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Layout title="Öğretmen Ağı">
      <section className="network-hero network-hero-teachers">
        <div className="network-hero-copy">
          <span className="network-eyebrow">Teacher network graph</span>
          <h2>Öğretmen bağlantılarını tek merkezden yönet</h2>
          <p>
            Mezun-öğretmen ilişkilerini doğrula, geçmiş bağları kayıt altına al ve öğretmen ekosistemini
            daha okunabilir bir yapıda büyüt.
          </p>
          <div className="network-inline-stats">
            <div className="network-inline-stat">
              <strong>{teacherOptions.length}</strong>
              <span>Erişilebilir öğretmen profili</span>
            </div>
            <div className="network-inline-stat">
              <strong>{items.length}</strong>
              <span>Aktif görünümdeki bağlantı</span>
            </div>
            <div className="network-inline-stat">
              <strong>{hasMore ? `${offset}+` : offset}</strong>
              <span>Yüklenen kayıt</span>
            </div>
          </div>
        </div>
        <div className="network-hero-actions">
          <a className="btn primary" href="/new/network/hub">Networking merkezine dön</a>
          <a className="btn ghost" href="/new/explore">Yeni mezun keşfet</a>
        </div>
      </section>

      <div className="network-dashboard network-dashboard-tight">
        <div className="panel network-panel-emphasis">
          <div className="network-section-head">
            <div>
              <span className="network-section-kicker">Yeni ilişki ekle</span>
              <h3>Öğretmen bağlantısı oluştur</h3>
              <p>Bu form, mezun-öğretmen bağını kayıt altına alır ve teacher graph içine doğrulanabilir bir ilişki ekler.</p>
            </div>
            {deepLinkedTeacherId > 0 ? <span className="chip">Profil üzerinden ön seçim geldi</span> : null}
          </div>
          <div className="panel-body">
            <form className="network-form-grid" onSubmit={submitLink}>
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
                      {teacherOptionLabel(teacher)}
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
                <span className="network-field-hint">{relationshipHelper}</span>
              </div>
              <div className="form-row">
                <label>Sınıf yılı</label>
                <select
                  className="input"
                  value={form.class_year}
                  onChange={(e) => setForm((prev) => ({ ...prev, class_year: e.target.value }))}
                >
                  <option value="">Seçiniz</option>
                  {years.map((y) => <option key={y} value={y}>{y}</option>)}
                </select>
              </div>
              <div className="form-row network-form-wide">
                <label>Not</label>
                <textarea
                  className="input"
                  value={form.notes}
                  onChange={(e) => setForm((prev) => ({ ...prev, notes: e.target.value }))}
                  maxLength={500}
                  placeholder="Bu ilişkiyi hangi bağlamda eklediğini kısaca yaz."
                />
              </div>
              <div className="network-form-footer">
                <button className="btn primary" type="submit" disabled={submitting}>
                  {submitting ? 'Kaydediliyor...' : 'Bağlantıyı Kaydet'}
                </button>
                <span className="muted">Doğrulanmış bir kayıt öğretmen ağı görünürlüğünü güçlendirir.</span>
              </div>
            </form>
            {status ? <div className="ok">{status}</div> : null}
            {error ? <div className="error">{error}</div> : null}
          </div>
        </div>

        <div className="network-column">
          <div className="panel">
            <div className="network-section-head">
              <div>
                <span className="network-section-kicker">Bu kayıt ne işe yarar?</span>
                <h3>Teacher Network değer paneli</h3>
                <p>Bu alan sadece form doldurmak için değil, platformun güven graph'ını büyütmek için vardır.</p>
              </div>
            </div>
            <div className="panel-body stack">
              <div className="network-value-list">
                <div className="network-value-card">
                  <strong>Profil güven sinyali üretir</strong>
                  <span>Teacher link kayıtları suggestion motoru ve trust badge sistemi için güçlü ek bağlam oluşturur.</span>
                </div>
                <div className="network-value-card">
                  <strong>Öğretmene görünürlük sağlar</strong>
                  <span>Bağ eklendiğinde öğretmen hesabına bildirim gider; böylece graph iki taraf için de görünür hale gelir.</span>
                </div>
                <div className="network-value-card">
                  <strong>Geçmiş bağı okunabilir kılar</strong>
                  <span>Sınıf yılı, ilişki türü ve not alanı birlikte girildiğinde sadece isim değil bağlam da kayda geçer.</span>
                </div>
                <div className="network-value-card">
                  <strong>Ağ kalitesini artırır</strong>
                  <span>Teacher Network genişledikçe öneri kartları, güven sinyalleri ve topluluk haritası daha isabetli çalışır.</span>
                </div>
              </div>
              <div className="network-guidance-list">
                <div className="network-guidance-item">
                  <strong>Ne zaman eklemelisin?</strong>
                  <span>Ders aldığın, mentorluk aldığın veya danışmanlık ilişkisi yaşadığın öğretmenlerde bu form doğru yerdir.</span>
                </div>
                <div className="network-guidance-item">
                  <strong>Öğretmene ne yansır?</strong>
                  <span>Kayıt eklendiğinde networking merkezindeki teacher graph bildirim akışına düşer ve görünürlük oluşur.</span>
                </div>
              </div>
            </div>
          </div>

          <div className="panel">
            <div className="network-section-head">
              <div>
                <span className="network-section-kicker">Seçili profil</span>
                <h3>Bağlantı önizlemesi</h3>
                <p>Kaydetmeden önce doğru öğretmeni seçtiğini ve ilişki bağlamının mantıklı olduğunu bu alanda kontrol edebilirsin.</p>
              </div>
            </div>
            <div className="panel-body stack">
              {selectedTeacher ? (
                <div className="network-highlight-card">
                  <div className="network-highlight-title">{teacherOptionLabel(selectedTeacher)}</div>
                  <div className="network-highlight-meta">
                    <span className="chip">Öğrenci sayısı: {selectedTeacher.student_count || 0}</span>
                    {selectedTeacher.mezuniyetyili ? <span className="chip">Kohort: {selectedTeacher.mezuniyetyili}</span> : null}
                  </div>
                  <p className="muted">
                    Bu öğretmen için bağlantı eklediğinde öğretmen hesabına bildirim gider ve networking merkezi
                    üzerinden izlenebilir hale gelir.
                  </p>
                </div>
              ) : (
                <div className="network-empty-state">
                  <strong>Henüz bir öğretmen seçilmedi.</strong>
                  <span>Bir profilden geldiysen seçim otomatik doldurulur; aksi durumda listeden bir öğretmen seç.</span>
                </div>
              )}
              <div className="network-guidance-list">
                <div className="network-guidance-item">
                  <strong>Derin link desteği</strong>
                  <span>Profil kartından gelen `teacherId` parametresi artık forma doğrudan taşınıyor.</span>
                </div>
                <div className="network-guidance-item">
                  <strong>Daha güvenli seçim</strong>
                  <span>Arama sonucu eşleşmese bile seçili öğretmen opsiyon listesinde korunuyor.</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="network-section-head">
          <div>
            <span className="network-section-kicker">İlişki geçmişi</span>
            <h3>{activeHistoryTitle}</h3>
            <p>{activeHistorySubtitle}</p>
          </div>
          <span className="chip">{items.length} kayıt</span>
        </div>
        <div className="panel-body">
          <div className="network-filter-bar">
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
            <button className="btn ghost" type="button" onClick={() => load(0, false)} disabled={loading}>
              {loading ? 'Yenileniyor...' : 'Filtreyi Uygula'}
            </button>
          </div>

          {!items.length && !loading ? (
            <div className="network-empty-state network-empty-state-wide">
              <strong>Henüz öğretmen ağı bağlantısı yok.</strong>
              <span>Soldaki formu kullanarak ilk doğrulanmış öğretmen bağını eklediğinde hem graph görünürlüğü hem güven sinyali güçlenir.</span>
            </div>
          ) : null}

          <div className="network-history-list">
            {items.map((item) => (
              <article key={item.id} className="network-history-card">
                <div className="network-history-main">
                  <div className="network-history-title">
                    <strong>@{item.kadi || 'uye'}</strong>
                    <span>{item.isim || ''} {item.soyisim || ''}</span>
                  </div>
                  <div className="network-history-meta">
                    <span className="chip">{relationshipLabel(item.relationship_type)}</span>
                    {item.class_year ? <span className="chip">Sınıf yılı {item.class_year}</span> : null}
                    {item.verified ? <span className="chip">Doğrulanmış profil</span> : null}
                  </div>
                </div>
                {item.notes ? <p className="muted">{item.notes}</p> : <p className="muted">Not eklenmemiş.</p>}
              </article>
            ))}
          </div>

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
