import React from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../utils/auth.jsx';
import { useMenu } from '../utils/menu.jsx';
import { useSidebar } from '../utils/sidebar.jsx';

export default function LegacyLayout({ pageTitle, pageImage, children, showLeftColumn = true }) {
  const { user } = useAuth();
  const { menu } = useMenu();
  const { data: sidebar } = useSidebar();
  const isLoggedIn = Boolean(user);

  return (
    <div className="sdal-root">
      <table className="sdal-outer-table" border="0" cellPadding="0" cellSpacing="0">
        <tbody>
          <tr>
            <td width="100%" height="100%" bgcolor="#663300" align="center" valign="center">
              <table className="sdal-inner-table" border="0" cellPadding="0" cellSpacing="0">
                <tbody>
                  <tr>
                    <td width="100%" height="50" align="left" valign="bottom" className="sdal-header">
                      <Link to="/" title="Anasayfaya gider...">
                        <img src="/legacy/logo.gif" alt="SDAL" border="0" />
                      </Link>
                      <span style={{ float: 'right', marginTop: 10, marginRight: 10 }}>
                        <a href="/new" className="menulink" style={{ textDecoration: 'none' }}>Yeni Tasarım</a>
                      </span>
                      {pageTitle && (
                        <span className="sdal-page-title">
                          {pageImage ? (
                            <img src={pageImage} alt="" border="0" />
                          ) : (
                            <> - {pageTitle}</>
                          )}
                        </span>
                      )}
                    </td>
                  </tr>
                  <tr>
                    <td className="sdal-strip" />
                  </tr>

                  {isLoggedIn && (
                    <tr>
                      <td className="sdal-menu-wrap">
                        <table className="sdal-menu-table" border="0" cellPadding="0" cellSpacing="0">
                          <tbody>
                            <tr>
                              <td width="58">
                                <img src="/legacy/menu.gif" border="0" alt="Menu" />
                              </td>
                              <td valign="middle">
                                {menu.map((item, idx) => (
                                  <React.Fragment key={item.url}>
                                    <Link
                                      to={item.url}
                                      className="menulink"
                                      style={{ textDecoration: 'none', ...(item.active ? { background: '#663300', color: 'white', padding: 3 } : {}) }}
                                      title={`Nereye --> ${item.label}`}
                                    >
                                      {item.label}
                                    </Link>
                                    {idx < menu.length - 1 ? ' | ' : ''}
                                  </React.Fragment>
                                ))}
                                {menu.length > 0 ? ' | ' : ''}
                                <Link to="/logout" className="menulink">Güvenli Çıkış</Link>
                                {' | '}
                                <a href="/new" className="menulink">Yeni Tasarım</a>
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </td>
                    </tr>
                  )}

                  <tr>
                    <td className="sdal-main" align="center" valign="center">
                      {isLoggedIn && sidebar.newMessagesCount > 0 ? (
                        <div className="sdal-alert" style={{ margin: '8px 12px' }}>
                          <img src="/legacy/arrow-orange.gif" border="0" alt="" />{' '}
                          <a href="/mesajlar" style={{ color: 'blue' }}>
                            <b>{sidebar.newMessagesCount}</b> yeni mesajınız var!
                          </a>
                        </div>
                      ) : null}
                      {isLoggedIn && showLeftColumn ? (
                        <table className="sdal-inner-table" border="0" cellPadding="3" cellSpacing="0">
                          <tbody>
                            <tr>
                              <td className="sdal-left-column" width="150" valign="top">
                                <LeftColumn sidebar={sidebar} />
                              </td>
                              <td className="sdal-content-column" align="center" valign="top">
                                {children}
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      ) : (
                        <div style={{ padding: 12 }}>{children}</div>
                      )}
                    </td>
                  </tr>

                  <tr>
                    <td className="sdal-strip-bottom" />
                  </tr>

                  <tr>
                    <td className="sdal-breadcrumb">
                      <table className="sdal-inner-table" border="0" cellPadding="0" cellSpacing="0">
                        <tbody>
                          <tr>
                            <td className="sdal-breadcrumb-title">
                              <img src="/legacy/neredeyim.gif" border="0" alt="Neredeyim" />
                            </td>
                            <td className="sdal-breadcrumb-body">
                              <Breadcrumb pageTitle={pageTitle} />
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </td>
                  </tr>

                  <tr>
                    <td className="sdal-footer" align="left" valign="bottom">
                      <center>
                        <hr color="#ffffcc" size="1" />
                        {menu.map((item, idx) => (
                          <React.Fragment key={`${item.url}-footer`}>
                            {idx > 0 ? ' | ' : ''}
                            <Link to={item.url}>{item.label}</Link>
                          </React.Fragment>
                        ))}
                        {' | '}
                        <a href="/new">Yeni Tasarım</a>
                        <hr color="#ffffcc" size="1" />
                      </center>
                      <br />
                      <br />
                      <b>&nbsp; <a href="https://www.sdal.org">sdal.org</a> bir SDAL kuruluşudur.</b>
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}

function LeftColumn({ sidebar }) {
  const { user } = useAuth();
  return (
    <div>
      <table border="0" cellPadding="3" cellSpacing="2" width="100%">
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300' }}>
              <img
                src={user?.photo ? `/api/media/vesikalik/${user.photo}` : '/legacy/vesikalik/nophoto.jpg'}
                border="0"
                width="138"
                alt="Vesikalık"
              />
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300' }}>
              <Link to="/profil/fotograf" style={{ color: '#660000', textDecoration: 'none', fontSize: 10 }}>
                <b>Fotoğraf Ekle/Düzenle</b>
              </Link>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300', textAlign: 'center' }}>
              <a href="/new" style={{ color: '#660000', textDecoration: 'none', fontSize: 11 }}>
                <b>Yeni Tasarıma Geç</b>
              </a>
            </td>
          </tr>
        </tbody>
      </table>

      <hr className="sdal-hr" />
      <Panel title="Kimler Sitede?">
        {sidebar.onlineUsers.length === 0 ? (
          <div>Şu an sitede online üye bulunmamaktadır.</div>
        ) : (
          sidebar.onlineUsers.map((u) => (
            <div key={u.id}>
              <img src="/legacy/arrow-orange.gif" border="0" alt="" />{' '}
              <a href={`/uyeler/${u.id}`} style={{ color: '#663300' }}>{u.kadi}</a>
            </div>
          ))
        )}
      </Panel>

      <hr className="sdal-hr" />
      <Panel title="En Yeni Üyelerimiz">
        {sidebar.newMembers.map((u) => (
          <div key={u.id}>
            <img src="/legacy/arrow-orange.gif" border="0" alt="" />{' '}
            <a href={`/uyeler/${u.id}`} style={{ color: '#663300' }}>{u.kadi}</a>
          </div>
        ))}
      </Panel>

      <hr className="sdal-hr" />
      <Panel title="En Yeni Fotoğraflar">
        <div style={{ textAlign: 'center' }}>
          {sidebar.newPhotos.map((p) => (
            <a key={p.id} href={`/album/foto/${p.id}`}>
              <img src={`/api/media/kucukresim?width=50&file=${encodeURIComponent(p.dosyaadi)}`} border="1" alt="" />
            </a>
          ))}
        </div>
        <hr className="sdal-hr" />
        <a href="/album/yeni">Yeni Fotoğraf Ekle</a>
      </Panel>

      <hr className="sdal-hr" />
      <Panel title="En Yüksek Puan - Yılan">
        {sidebar.topSnake.map((row, idx) => (
          <div key={`${row.isim}-${idx}`}>
            <b>{idx + 1}. </b>
            <span style={{ color: '#663300' }}>{row.isim}</span>
            <small> ({row.skor})</small>
          </div>
        ))}
      </Panel>

      <hr className="sdal-hr" />
      <Panel title="En Yüksek Puan - Tetris">
        {sidebar.topTetris.map((row, idx) => (
          <div key={`${row.isim}-${idx}`}>
            <b>{idx + 1}. </b>
            <span style={{ color: '#663300' }}>{row.isim}</span>
            <small> ({row.puan})</small>
          </div>
        ))}
      </Panel>
    </div>
  );
}

function Panel({ title, children }) {
  return (
    <table border="0" cellPadding="2" cellSpacing="0" width="100%">
      <tbody>
        <tr>
          <td className="sdal-panel-title">{title}</td>
        </tr>
        <tr>
          <td className="sdal-panel-body">{children}</td>
        </tr>
      </tbody>
    </table>
  );
}

function Breadcrumb({ pageTitle }) {
  return (
    <span>
      <Link to="/" style={{ color: '#663300', textDecoration: 'none' }}>
        {pageTitle ? 'Anasayfa' : <b>Anasayfa</b>}
      </Link>
      {pageTitle ? ` >> ${pageTitle}` : ''}
    </span>
  );
}
