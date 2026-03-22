import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminPreviewDialog from '../../../components/admin/AdminPreviewDialog.jsx';
import { useI18n } from '../../../utils/i18n.jsx';

function ConfirmModal({ modal, onConfirm, onCancel }) {
  const { t } = useI18n();
  if (!modal) return null;
  return (
    <AdminPreviewDialog
      title={modal.title}
      onClose={onCancel}
      closeLabel={t('İptal')}
      compact
      footer={(
        <div className="ops-inline-actions">
          <button className="btn" onClick={onConfirm}>{modal.confirmLabel || t('Onayla')}</button>
          <button className="btn ghost" onClick={onCancel}>{t('İptal')}</button>
        </div>
      )}
    >
      <div className="stack admin-preview-copy">
        {(modal.lines || []).map((line, i) => (
          <div key={i} className={line.muted ? 'muted' : ''}>{line.text}</div>
        ))}
      </div>
    </AdminPreviewDialog>
  );
}

function formatDate(value) {
  return value ? new Date(value).toLocaleString('tr-TR') : '-';
}

export default function SystemSection({ isAdmin = false }) {
  const { t } = useI18n();
  const [status, setStatus] = useState('');

  const [logType, setLogType] = useState('app');
  const [logFiles, setLogFiles] = useState([]);
  const [selectedLogFile, setSelectedLogFile] = useState('');
  const [logQuery, setLogQuery] = useState('');
  const [logContent, setLogContent] = useState('');
  const [logMeta, setLogMeta] = useState({ total: 0, matched: 0, returned: 0 });

  const [tables, setTables] = useState([]);
  const [selectedTable, setSelectedTable] = useState('');
  const [tableColumns, setTableColumns] = useState([]);
  const [tableRows, setTableRows] = useState([]);
  const [tableMeta, setTableMeta] = useState({ page: 1, pages: 1, limit: 50, total: 0 });

  const [backups, setBackups] = useState([]);
  const [backupLabel, setBackupLabel] = useState('manual');
  const [dbPath, setDbPath] = useState('');
  const [dbDriver, setDbDriver] = useState('');
  const [driverSwitch, setDriverSwitch] = useState(null);
  const [driverSwitchBusy, setDriverSwitchBusy] = useState(false);
  const [driverSwitchConfirm, setDriverSwitchConfirm] = useState('');
  const [driverSwitchAckDrift, setDriverSwitchAckDrift] = useState(false);
  const [driverSwitchCopyData, setDriverSwitchCopyData] = useState(false);

  const [copyOnlySrc, setCopyOnlySrc] = useState('sqlite');
  const [copyOnlyTgt, setCopyOnlyTgt] = useState('postgres');
  const [copyOnlyBusy, setCopyOnlyBusy] = useState(false);
  const [copyOnlyResult, setCopyOnlyResult] = useState(null);

  const [confirmModal, setConfirmModal] = useState(null);

  const loadLogFiles = useCallback(async () => {
    try {
      const data = await adminClient.get(withQuery('/api/admin/logs', { type: logType }));
      const files = data.files || [];
      setLogFiles(files);
      if (!files.some((item) => item.name === selectedLogFile)) {
        setSelectedLogFile(files[0]?.name || '');
      }
    } catch (err) {
      setStatus(err.message || t('Log dosyaları yüklenemedi.'));
    }
  }, [logType, selectedLogFile, t]);

  const loadLogContent = useCallback(async (name) => {
    if (!name) {
      setLogContent('');
      setLogMeta({ total: 0, matched: 0, returned: 0 });
      return;
    }
    try {
      const data = await adminClient.get(withQuery('/api/admin/logs', {
        type: logType,
        file: name,
        q: logQuery,
        limit: 700,
        offset: 0
      }));
      setLogContent(data.content || '');
      setLogMeta({ total: data.total || 0, matched: data.matched || 0, returned: data.returned || 0 });
    } catch (err) {
      setStatus(err.message || t('Log içeriği yüklenemedi.'));
    }
  }, [logQuery, logType, t]);

  const loadTables = useCallback(async () => {
    try {
      const data = await adminClient.get('/api/new/admin/db/tables');
      const list = data.items || [];
      setTables(list);
      if (!list.some((item) => item.name === selectedTable)) {
        setSelectedTable(list[0]?.name || '');
      }
    } catch (err) {
      setStatus(err.message || t('Veritabanı tabloları yüklenemedi.'));
    }
  }, [selectedTable, t]);

  const loadTableData = useCallback(async (tableName, page = 1) => {
    if (!tableName) {
      setTableColumns([]);
      setTableRows([]);
      return;
    }
    try {
      const data = await adminClient.get(withQuery(`/api/new/admin/db/table/${encodeURIComponent(tableName)}`, {
        page,
        limit: tableMeta.limit
      }));
      setSelectedTable(data.table || tableName);
      setTableColumns(data.columns || []);
      setTableRows(data.rows || []);
      setTableMeta({
        page: data.page || page,
        pages: data.pages || 1,
        limit: data.limit || 50,
        total: data.total || 0
      });
    } catch (err) {
      setStatus(err.message || t('Tablo satırları yüklenemedi.'));
    }
  }, [tableMeta.limit, t]);

  const loadBackups = useCallback(async () => {
    try {
      const data = await adminClient.get('/api/new/admin/db/backups');
      setBackups(data.items || []);
      setDbPath(data.dbPath || '');
      setDbDriver(data.dbDriver || '');
    } catch (err) {
      setStatus(err.message || t('Yedekler yüklenemedi.'));
    }
  }, [t]);

  const loadDbDriverSwitchStatus = useCallback(async () => {
    try {
      const data = await adminClient.get('/api/new/admin/db/driver/status');
      setDriverSwitch(data || null);
      setDriverSwitchConfirm('');
      setDriverSwitchAckDrift(false);
      setDriverSwitchCopyData(false);
    } catch (err) {
      setDriverSwitch(null);
      setStatus(err.message || t('Veritabanı geçiş durumu yüklenemedi.'));
    }
  }, [t]);

  const loadAll = useCallback(async () => {
    setStatus('');
    await Promise.all([loadLogFiles(), loadTables(), loadBackups(), loadDbDriverSwitchStatus()]);
  }, [loadBackups, loadDbDriverSwitchStatus, loadLogFiles, loadTables]);

  useEffect(() => {
    if (!isAdmin) return;
    loadAll();
  }, [isAdmin, loadAll]);

  useEffect(() => {
    if (!isAdmin) return;
    loadLogFiles();
  }, [isAdmin, loadLogFiles]);

  useEffect(() => {
    if (!isAdmin) return;
    loadLogContent(selectedLogFile);
  }, [isAdmin, loadLogContent, selectedLogFile]);

  useEffect(() => {
    if (!isAdmin) return;
    loadTableData(selectedTable, tableMeta.page || 1);
  }, [isAdmin, loadTableData, selectedTable]);

  const createBackup = useCallback(async () => {
    try {
      await adminClient.post('/api/new/admin/db/backups', { label: backupLabel || 'manual' });
      setStatus(t('Yedek oluşturuldu.'));
      await loadBackups();
    } catch (err) {
      setStatus(err.message || t('Yedek oluşturma başarısız.'));
    }
  }, [backupLabel, loadBackups, t]);

  const requestSwitchDbDriver = useCallback(() => {
    if (!driverSwitch?.targetDriver) return;
    const lines = [
      { text: t('{current} → {target} veritabanı sürücüsüne geç.', { current: driverSwitch.currentDriver, target: driverSwitch.targetDriver }) },
      { text: driverSwitchCopyData ? t('Geçişten önce veri hedef sürücüye kopyalanacak.') : t('Veri kopyalanmayacak, sadece sürücü ayarı değişecek.'), muted: true },
      { text: t('Geçişten sonra sunucu otomatik olarak yeniden başlayacak.'), muted: true },
    ];
    if ((driverSwitch.warnings || []).length) {
      lines.push({ text: driverSwitch.warnings.join(' '), muted: true });
    }
    setConfirmModal({ type: 'switch', title: t('Veritabanı Sürücüsü Geçişini Onayla'), lines, confirmLabel: t('{target} sürücüsüne geç', { target: driverSwitch.targetDriver }) });
  }, [driverSwitch, driverSwitchCopyData, t]);

  const executeSwitchDbDriver = useCallback(async () => {
    setConfirmModal(null);
    if (!driverSwitch?.targetDriver) return;
    try {
      setDriverSwitchBusy(true);
      const payload = {
        targetDriver: driverSwitch.targetDriver,
        confirmText: driverSwitchConfirm,
        challengeToken: driverSwitch.challengeToken,
        acknowledgeSqliteDrift: driverSwitchAckDrift,
        copyData: driverSwitchCopyData
      };
      const data = await adminClient.post('/api/new/admin/db/driver/switch', payload);
      setStatus(data?.message || t('Veritabanı sürücüsü geçişi kabul edildi. Sunucu yeniden başlıyor.'));
      await loadDbDriverSwitchStatus();
    } catch (err) {
      const message = String(err?.message || t('Veritabanı geçişi başarısız.'));
      if (/failed to fetch/i.test(message)) {
        setStatus(t('Veritabanı sürücü geçişi gönderildi. Sunucu yeniden başladığı için bağlantı koptu.'));
      } else {
        setStatus(message);
      }
      await loadDbDriverSwitchStatus();
    } finally {
      setDriverSwitchBusy(false);
    }
  }, [driverSwitch, driverSwitchAckDrift, driverSwitchConfirm, driverSwitchCopyData, loadDbDriverSwitchStatus]);

  const requestCopyOnlyData = useCallback(() => {
    if (copyOnlySrc === copyOnlyTgt) {
      setStatus(t('Kaynak ve hedef sürücü farklı olmalı.'));
      return;
    }
    setConfirmModal({
      type: 'copy',
      title: t('Veri Kopyalamayı Onayla'),
      lines: [
        { text: t('Tüm veriyi {src} → {tgt} yönünde kopyala.', { src: copyOnlySrc, tgt: copyOnlyTgt }) },
        { text: t('Bu işlem hedef sürücüdeki mevcut verilerin üzerine yazacak.'), muted: true },
        { text: t('Aktif sürücü değişmeyecek; sadece veri kopyalanacak.'), muted: true },
      ],
      confirmLabel: t('{src} → {tgt} kopyala', { src: copyOnlySrc, tgt: copyOnlyTgt })
    });
  }, [copyOnlySrc, copyOnlyTgt, t]);

  const executeCopyOnlyData = useCallback(async () => {
    setConfirmModal(null);
    try {
      setCopyOnlyBusy(true);
      setCopyOnlyResult(null);
      const data = await adminClient.post('/api/new/admin/db/driver/copy-data', {
        sourceDriver: copyOnlySrc,
        targetDriver: copyOnlyTgt
      });
      setCopyOnlyResult(data?.stats || {});
      setStatus(t('Veri kopyalama tamamlandı: {src} → {tgt}.', { src: copyOnlySrc, tgt: copyOnlyTgt }));
    } catch (err) {
      setStatus(err?.message || t('Veri kopyalama başarısız.'));
    } finally {
      setCopyOnlyBusy(false);
    }
  }, [copyOnlySrc, copyOnlyTgt, t]);

  const handleConfirmModalConfirm = useCallback(() => {
    if (confirmModal?.type === 'switch') executeSwitchDbDriver();
    else if (confirmModal?.type === 'copy') executeCopyOnlyData();
    else setConfirmModal(null);
  }, [confirmModal, executeSwitchDbDriver, executeCopyOnlyData]);

  const tableColumnsConfig = useMemo(() => {
    return (tableColumns || []).map((column) => ({
      key: column.name,
      label: column.name,
      render: (row) => String(row?.[column.name] ?? '-')
    }));
  }, [tableColumns]);

  if (!isAdmin) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">{t('Sistem işlemlerine sadece yöneticiler erişebilir.')}</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <ConfirmModal
        modal={confirmModal}
        onConfirm={handleConfirmModalConfirm}
        onCancel={() => setConfirmModal(null)}
      />

      <div className="ops-head-row">
        <h3>{t('Sistem')}</h3>
        <button className="btn ghost" onClick={loadAll}>{t('Yenile')}</button>
      </div>

      {status ? <div className="muted">{status}</div> : null}

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Loglar')}</h3>
          <div className="ops-inline-actions">
            <select className="input" value={logType} onChange={(e) => setLogType(e.target.value)}>
              <option value="app">{t('Uygulama')}</option>
              <option value="member">{t('Üye')}</option>
              <option value="error">{t('Hata')}</option>
              <option value="page">{t('Sayfa')}</option>
            </select>
            <input className="input" value={logQuery} onChange={(e) => setLogQuery(e.target.value)} placeholder={t('Seçili log dosyasında ara')} />
            <button className="btn ghost" onClick={() => loadLogContent(selectedLogFile).catch(() => {})}>{t('Uygula')}</button>
          </div>

          <div className="ops-log-layout">
            <div className="ops-log-files">
              {logFiles.map((file) => (
                <button
                  key={file.name}
                  className={`ops-log-file ${selectedLogFile === file.name ? 'active' : ''}`}
                  onClick={() => setSelectedLogFile(file.name)}
                >
                  <div>{file.name}</div>
              <div className="meta">{formatDate(file.mtime)} • {Number(file.size || 0)} B</div>
                </button>
              ))}
              {!logFiles.length ? <div className="muted">{t('Log dosyası yok.')}</div> : null}
            </div>
            <div className="ops-log-content">
              <div className="meta">{t('Eşleşen')} {logMeta.matched} / {t('Toplam')} {logMeta.total}</div>
              <pre>{logContent || t('İncelemek için bir log dosyası seç.')}</pre>
            </div>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Veritabanı İnceleyici')}</h3>
          <div className="meta">{t('Sürücü')}: {dbDriver || '-'} | {t('Yol')}: {dbPath || '-'}</div>
          <div className="ops-inline-actions">
            <select className="input" value={selectedTable} onChange={(e) => setSelectedTable(e.target.value)}>
              {tables.map((table) => (
                <option key={table.name} value={table.name}>{table.name} ({table.rowCount || 0})</option>
              ))}
            </select>
            <button className="btn ghost" onClick={() => loadTableData(selectedTable, 1).catch(() => {})}>{t('Tabloyu yükle')}</button>
          </div>

          <AdminDataTable
            columns={tableColumnsConfig}
            rows={tableRows}
            loading={false}
            pagination={tableMeta}
            onPageChange={(page) => loadTableData(selectedTable, page).catch(() => {})}
            emptyText={t('Satır yok.')}
          />
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Veritabanı Sürücü Geçişi')}</h3>
          <div className="meta">
            {t('Mevcut')}: <strong>{driverSwitch?.currentDriver || dbDriver || '-'}</strong>
            {' → '}
            {t('Hedef')}: <strong>{driverSwitch?.targetDriver || '-'}</strong>
          </div>

          <input
            className="input"
            value={driverSwitchConfirm}
            onChange={(e) => setDriverSwitchConfirm(e.target.value)}
            placeholder={t('Onaylamak için "{text}" yaz', { text: driverSwitch?.expectedConfirmText || '' })}
          />

          {driverSwitch?.dataCopySupported ? (
            <label className="ops-check-row">
              <input
                type="checkbox"
                checked={driverSwitchCopyData}
                onChange={(e) => setDriverSwitchCopyData(e.target.checked)}
              />
              <span>{t('Geçmeden önce mevcut sürücüden hedefe veri kopyala')}</span>
            </label>
          ) : null}

          {driverSwitch?.requiresSqliteDriftAck && !driverSwitchCopyData ? (
            <label className="ops-check-row">
              <input
                type="checkbox"
                checked={driverSwitchAckDrift}
                onChange={(e) => setDriverSwitchAckDrift(e.target.checked)}
              />
              <span>{t('PostgreSQL → SQLite geçişinin veri kopyalanmadan yapılması durumunda eski bir SQLite anlık görüntüsü kullanılabileceğini anlıyorum.')}</span>
            </label>
          ) : null}

          {(driverSwitch?.blockers || []).length ? (
            <div className="muted">{t('Engeller')}: {(driverSwitch.blockers || []).join(' | ')}</div>
          ) : null}
          {(driverSwitch?.warnings || []).length ? (
            <div className="muted">{t('Uyarılar')}: {(driverSwitch.warnings || []).join(' | ')}</div>
          ) : null}

          <div className="ops-inline-actions">
            <button
              className="btn"
              onClick={requestSwitchDbDriver}
              disabled={
                driverSwitchBusy
                || !driverSwitch?.switchEnabled
                || !driverSwitch?.targetDriver
                || driverSwitchConfirm !== driverSwitch?.expectedConfirmText
                || (driverSwitch?.requiresSqliteDriftAck && !driverSwitchCopyData && !driverSwitchAckDrift)
              }
            >
              {driverSwitchBusy ? t('Geçiliyor...') : t('{target} sürücüsüne geç', { target: driverSwitch?.targetDriver || t('hedef') })}
            </button>
            <button className="btn ghost" onClick={() => loadDbDriverSwitchStatus().catch(() => {})}>{t('Yenile')}</button>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Veritabanı Verisi Kopyala')}</h3>
          <div className="muted">{t('Aktif sürücüyü değiştirmeden sürücüler arasında veri kopyala.')}</div>
          <div className="ops-inline-actions">
            <label className="admin-field-stack">
              <span className="meta">{t('Kaynak')}</span>
              <select className="input" value={copyOnlySrc} onChange={(e) => { setCopyOnlySrc(e.target.value); setCopyOnlyResult(null); }}>
                <option value="sqlite">SQLite</option>
                <option value="postgres">PostgreSQL</option>
              </select>
            </label>
            <span className="admin-copy-arrow">→</span>
            <label className="admin-field-stack">
              <span className="meta">{t('Hedef')}</span>
              <select className="input" value={copyOnlyTgt} onChange={(e) => { setCopyOnlyTgt(e.target.value); setCopyOnlyResult(null); }}>
                <option value="postgres">PostgreSQL</option>
                <option value="sqlite">SQLite</option>
              </select>
            </label>
            <button
              className="btn admin-self-end"
              onClick={requestCopyOnlyData}
              disabled={copyOnlyBusy || copyOnlySrc === copyOnlyTgt}
            >
              {copyOnlyBusy ? t('Kopyalanıyor...') : t('Veriyi kopyala')}
            </button>
          </div>
          {copyOnlyResult ? (
            <div className="muted">
              {t('Kopyalama tamamlandı.')}
              {copyOnlyResult.tables !== undefined ? ` ${t('Tablolar')}: ${copyOnlyResult.tables}.` : ''}
              {copyOnlyResult.rows !== undefined ? ` ${t('Satırlar')}: ${copyOnlyResult.rows}.` : ''}
              {(copyOnlyResult.errors || []).length ? ` ${t('Hatalar')}: ${copyOnlyResult.errors.map(e => e.table ? `${e.table}: ${e.message}` : JSON.stringify(e)).join(', ')}.` : ''}
            </div>
          ) : null}
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Yedekler')}</h3>
          <div className="ops-inline-actions">
            <input className="input" value={backupLabel} onChange={(e) => setBackupLabel(e.target.value)} placeholder={t('Yedek etiketi')} />
            <button className="btn" onClick={createBackup}>{t('Yedek oluştur')}</button>
          </div>
          <div className="ops-list-grid">
            {backups.map((item) => (
              <div key={item.name} className="ops-list-row">
                <div>
                  <strong>{item.name}</strong>
                  <div className="meta">{formatDate(item.mtime)} • {Number(item.size || 0)} B</div>
                </div>
                <a className="btn ghost" href={`/api/new/admin/db/backups/${encodeURIComponent(item.name)}/download`}>{t('İndir')}</a>
              </div>
            ))}
            {!backups.length ? <div className="muted">{t('Kullanılabilir yedek yok.')}</div> : null}
          </div>
        </div>
      </div>
    </section>
  );
}
