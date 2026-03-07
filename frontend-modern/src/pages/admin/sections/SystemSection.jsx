import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';

function formatDate(value) {
  return value ? new Date(value).toLocaleString('tr-TR') : '-';
}

export default function SystemSection({ isAdmin = false }) {
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

  const loadLogFiles = useCallback(async () => {
    try {
      const data = await adminClient.get(withQuery('/api/admin/logs', { type: logType }));
      const files = data.files || [];
      setLogFiles(files);
      if (!files.some((item) => item.name === selectedLogFile)) {
        setSelectedLogFile(files[0]?.name || '');
      }
    } catch (err) {
      setStatus(err.message || 'Log files could not be loaded.');
    }
  }, [logType, selectedLogFile]);

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
      setStatus(err.message || 'Log content could not be loaded.');
    }
  }, [logQuery, logType]);

  const loadTables = useCallback(async () => {
    try {
      const data = await adminClient.get('/api/new/admin/db/tables');
      const list = data.items || [];
      setTables(list);
      if (!list.some((item) => item.name === selectedTable)) {
        setSelectedTable(list[0]?.name || '');
      }
    } catch (err) {
      setStatus(err.message || 'Database tables could not be loaded.');
    }
  }, [selectedTable]);

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
      setStatus(err.message || 'Table rows could not be loaded.');
    }
  }, [tableMeta.limit]);

  const loadBackups = useCallback(async () => {
    try {
      const data = await adminClient.get('/api/new/admin/db/backups');
      setBackups(data.items || []);
      setDbPath(data.dbPath || '');
      setDbDriver(data.dbDriver || '');
    } catch (err) {
      setStatus(err.message || 'Backups could not be loaded.');
    }
  }, []);

  const loadDbDriverSwitchStatus = useCallback(async () => {
    try {
      const data = await adminClient.get('/api/new/admin/db/driver/status');
      setDriverSwitch(data || null);
      setDriverSwitchConfirm('');
      setDriverSwitchAckDrift(false);
    } catch (err) {
      setDriverSwitch(null);
      setStatus(err.message || 'DB switch status could not be loaded.');
    }
  }, []);

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
      setStatus('Backup created.');
      await loadBackups();
    } catch (err) {
      setStatus(err.message || 'Backup create failed.');
    }
  }, [backupLabel, loadBackups]);

  const switchDbDriver = useCallback(async () => {
    if (!driverSwitch?.targetDriver) return;
    try {
      setDriverSwitchBusy(true);
      const payload = {
        targetDriver: driverSwitch.targetDriver,
        confirmText: driverSwitchConfirm,
        challengeToken: driverSwitch.challengeToken,
        acknowledgeSqliteDrift: driverSwitchAckDrift
      };
      const data = await adminClient.post('/api/new/admin/db/driver/switch', payload);
      setStatus(data?.message || 'DB driver switch accepted. Server is restarting.');
      await loadDbDriverSwitchStatus();
    } catch (err) {
      const message = String(err?.message || 'DB switch failed.');
      if (/failed to fetch/i.test(message)) {
        setStatus('DB driver switch sent. Connection dropped because server restarted.');
      } else {
        setStatus(message);
      }
      await loadDbDriverSwitchStatus();
    } finally {
      setDriverSwitchBusy(false);
    }
  }, [driverSwitch, driverSwitchAckDrift, driverSwitchConfirm, loadDbDriverSwitchStatus]);

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
        <div className="panel"><div className="panel-body muted">Only admins can access system operations.</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>System</h3>
        <button className="btn ghost" onClick={loadAll}>Refresh</button>
      </div>

      {status ? <div className="muted">{status}</div> : null}

      <div className="panel">
        <div className="panel-body stack">
          <h3>Logs</h3>
          <div className="ops-inline-actions">
            <select className="input" value={logType} onChange={(e) => setLogType(e.target.value)}>
              <option value="app">App</option>
              <option value="member">Member</option>
              <option value="error">Error</option>
              <option value="page">Page</option>
            </select>
            <input className="input" value={logQuery} onChange={(e) => setLogQuery(e.target.value)} placeholder="Search in selected log file" />
            <button className="btn ghost" onClick={() => loadLogContent(selectedLogFile).catch(() => {})}>Apply</button>
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
              {!logFiles.length ? <div className="muted">No log files.</div> : null}
            </div>
            <div className="ops-log-content">
              <div className="meta">Matched {logMeta.matched} / Total {logMeta.total}</div>
              <pre>{logContent || 'Select a log file to inspect.'}</pre>
            </div>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>Database Inspector</h3>
          <div className="meta">Driver: {dbDriver || '-'} | Path: {dbPath || '-'}</div>
          <div className="ops-inline-actions">
            <select className="input" value={selectedTable} onChange={(e) => setSelectedTable(e.target.value)}>
              {tables.map((table) => (
                <option key={table.name} value={table.name}>{table.name} ({table.rowCount || 0})</option>
              ))}
            </select>
            <button className="btn ghost" onClick={() => loadTableData(selectedTable, 1).catch(() => {})}>Load table</button>
          </div>

          <AdminDataTable
            columns={tableColumnsConfig}
            rows={tableRows}
            loading={false}
            pagination={tableMeta}
            onPageChange={(page) => loadTableData(selectedTable, page).catch(() => {})}
            emptyText="No rows."
          />
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>DB Driver Toggle</h3>
          <div className="meta">
            Current: {driverSwitch?.currentDriver || dbDriver || '-'} | Target: {driverSwitch?.targetDriver || '-'}
          </div>
          <label className="ops-check-row">
            <input type="checkbox" checked={driverSwitch?.targetDriver === 'postgres'} readOnly />
            <span>Target PostgreSQL (unchecked means SQLite)</span>
          </label>
          <input
            className="input"
            value={driverSwitchConfirm}
            onChange={(e) => setDriverSwitchConfirm(e.target.value)}
            placeholder={driverSwitch?.expectedConfirmText || 'Type confirm text'}
          />
          {driverSwitch?.requiresSqliteDriftAck ? (
            <label className="ops-check-row">
              <input
                type="checkbox"
                checked={driverSwitchAckDrift}
                onChange={(e) => setDriverSwitchAckDrift(e.target.checked)}
              />
              <span>I accept PostgreSQL to SQLite may use older SQLite data snapshot.</span>
            </label>
          ) : null}
          {(driverSwitch?.blockers || []).length ? (
            <div className="muted">
              Blockers: {(driverSwitch.blockers || []).join(' | ')}
            </div>
          ) : null}
          {(driverSwitch?.warnings || []).length ? (
            <div className="muted">
              Warnings: {(driverSwitch.warnings || []).join(' | ')}
            </div>
          ) : null}
          <div className="ops-inline-actions">
            <button
              className="btn"
              onClick={switchDbDriver}
              disabled={
                driverSwitchBusy
                || !driverSwitch?.switchEnabled
                || !driverSwitch?.targetDriver
                || driverSwitchConfirm !== driverSwitch?.expectedConfirmText
                || (driverSwitch?.requiresSqliteDriftAck && !driverSwitchAckDrift)
              }
            >
              {driverSwitchBusy ? 'Switching...' : `Switch to ${driverSwitch?.targetDriver || 'target'}`}
            </button>
            <button className="btn ghost" onClick={() => loadDbDriverSwitchStatus().catch(() => {})}>Refresh switch status</button>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>Backups</h3>
          <div className="ops-inline-actions">
            <input className="input" value={backupLabel} onChange={(e) => setBackupLabel(e.target.value)} placeholder="Backup label" />
            <button className="btn" onClick={createBackup}>Create backup</button>
          </div>
          <div className="ops-list-grid">
            {backups.map((item) => (
              <div key={item.name} className="ops-list-row">
                <div>
                  <strong>{item.name}</strong>
                  <div className="meta">{formatDate(item.mtime)} • {Number(item.size || 0)} B</div>
                </div>
                <a className="btn ghost" href={`/api/new/admin/db/backups/${encodeURIComponent(item.name)}/download`}>Download</a>
              </div>
            ))}
            {!backups.length ? <div className="muted">No backups available.</div> : null}
          </div>
        </div>
      </div>
    </section>
  );
}
