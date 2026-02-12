import React, { useState } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { useAuth } from '../utils/auth.jsx';

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [kadi, setKadi] = useState('');
  const [sifre, setSifre] = useState('');
  const [error, setError] = useState('');
  const next = new URLSearchParams(location.search).get('next') || '/';

  async function onSubmit(e) {
    e.preventDefault();
    setError('');
    try {
      const data = await login({ kadi, sifre });
      if (data.needsProfile) {
        navigate('/profil');
      } else {
        navigate(next);
      }
    } catch (err) {
      setError(err.message || 'Giriş başarısız.');
    }
  }

  return (
    <LegacyLayout pageTitle="Anasayfa" showLeftColumn={false}>
      <table border="0" cellPadding="0" cellSpacing="0" width="100%">
        <tbody>
          <tr>
            <td valign="top">
              <table border="0" cellPadding="3" cellSpacing="1" width="100%">
                <tbody>
                  <tr>
                    <td style={{ border: '1px solid #663300', background: '#660000', color: 'white' }} align="left">
                      <b>Üye Girişi</b>
                    </td>
                  </tr>
                  <tr>
                    <td style={{ border: '1px solid #663300', color: '#000033' }} align="left" valign="middle">
                      <form onSubmit={onSubmit}>
                        <table border="0" cellPadding="2" cellSpacing="2">
                          <caption align="top">
                            <span className="inptxt" style={{ color: 'red', fontSize: 12, border: 0 }}>
                              Lütfen kullanıcı adınızı ve şifrenizi giriniz.
                            </span>
                          </caption>
                          <tbody>
                            <tr>
                              <td align="right"><b>Kullanıcı Adı :</b></td>
                              <td align="left">
                                <input className="inptxt" type="text" value={kadi} onChange={(e) => setKadi(e.target.value)} size="20" />
                              </td>
                            </tr>
                            <tr>
                              <td align="right"><b>Şifre :</b></td>
                              <td align="left">
                                <input className="inptxt" type="password" value={sifre} onChange={(e) => setSifre(e.target.value)} size="20" />
                              </td>
                            </tr>
                            <tr>
                              <td align="right" colSpan="2">
                                <input type="submit" className="sub" value="Giriş" />
                              </td>
                            </tr>
                            <tr>
                              <td align="center" colSpan="2">
                                {error ? <div className="hatamsg1">{error}</div> : null}
                                <br />
                                <Link to="/sifre-hatirla" title="Şifremi Unuttum :(">Şifrenizi veya kullanıcı adınızı unuttuysanız buraya tıklayın.</Link>
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </form>
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
            <td valign="top">
              <table border="0" cellPadding="3" cellSpacing="1" width="100%">
                <tbody>
                  <tr>
                    <td style={{ border: '1px solid #663300', background: '#660000', color: 'white' }} align="left">
                      <b>Siteye Giriş Yapmadan Önce Unutmayınız ki;</b>
                    </td>
                  </tr>
                  <tr>
                    <td style={{ border: '1px solid #663300', color: '#000033' }} align="left" valign="top">
                      <ul>
                        <li>Sitedeki bilgiler sadece mezunlar içindir.</li>
                        <li>Şifre güvenliğinizden siz sorumlusunuz.</li>
                        <li>Yardım için yönetim ile iletişime geçebilirsiniz.</li>
                      </ul>
                      <div>
                        <Link to="/uye-kayit">Yeni Üyelik</Link>
                      </div>
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
