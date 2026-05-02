const APP_SCHEME = 'sdalflutter';
const APP_NAME = 'SDAL';

function buildDeepLink(path = '/notifications') {
  return `${APP_SCHEME}:/${path}`;
}

function buildHtmlWrapper(bodyContent) {
  return `<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${APP_NAME}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 0; }
    .container { max-width: 580px; margin: 32px auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,0.08); }
    .header { background: #1a237e; padding: 32px 36px 24px; }
    .header-logo { color: #ffffff; font-size: 22px; font-weight: 700; letter-spacing: 1px; margin: 0; }
    .header-subtitle { color: #c5cae9; font-size: 13px; margin: 6px 0 0; }
    .badge { display: inline-block; background: #4caf50; color: #ffffff; font-size: 12px; font-weight: 600; padding: 4px 12px; border-radius: 20px; margin-top: 12px; }
    .body { padding: 32px 36px; }
    .greeting { font-size: 20px; font-weight: 700; color: #1a237e; margin: 0 0 16px; }
    .text { font-size: 15px; color: #424242; line-height: 1.7; margin: 0 0 14px; }
    .highlight-box { background: #e8eaf6; border-left: 4px solid #3f51b5; border-radius: 0 8px 8px 0; padding: 14px 18px; margin: 20px 0; }
    .highlight-box p { margin: 0 0 6px; font-size: 14px; color: #283593; }
    .highlight-box p:last-child { margin: 0; }
    .feature-list { list-style: none; padding: 0; margin: 20px 0; }
    .feature-list li { padding: 8px 0 8px 28px; position: relative; font-size: 14px; color: #424242; line-height: 1.6; border-bottom: 1px solid #f0f0f0; }
    .feature-list li:last-child { border-bottom: none; }
    .feature-list li::before { content: '✓'; position: absolute; left: 0; color: #3f51b5; font-weight: 700; }
    .cta-container { text-align: center; margin: 28px 0; }
    .cta-button { display: inline-block; background: #1a237e; color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-size: 15px; font-weight: 600; letter-spacing: 0.3px; }
    .cta-note { font-size: 12px; color: #9e9e9e; margin: 10px 0 0; }
    .divider { border: none; border-top: 1px solid #eeeeee; margin: 24px 0; }
    .footer { background: #f5f5f5; padding: 20px 36px; text-align: center; }
    .footer p { font-size: 12px; color: #9e9e9e; margin: 0; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <p class="header-logo">${APP_NAME}</p>
      <p class="header-subtitle">Sosyal Ağ Platformu</p>
      <span class="badge">✓ Doğrulama Onaylandı</span>
    </div>
    <div class="body">
      ${bodyContent}
    </div>
    <div class="footer">
      <p>Bu e-posta SDAL platformu tarafından otomatik olarak gönderilmiştir.<br>
      Sorularınız için destek ekibimize ulaşabilirsiniz.</p>
    </div>
  </div>
</body>
</html>`;
}

export function buildAlumniApprovalEmail({ firstName = '', appDeepLink = null } = {}) {
  const deepLink = appDeepLink || buildDeepLink('/notifications');
  const greeting = firstName ? `Sevgili SDAL Mezunumuz ${firstName},` : 'Sevgili SDAL Mezunumuz,';

  const bodyContent = `
    <p class="greeting">${greeting}</p>
    <p class="text">
      Profil doğrulama talebiniz onaylandı! SDAL ailesine resmi olarak hoş geldiniz.
      Artık mezunlar ve öğretmenlerimizden oluşan bu özel topluluğun tam üyesisiniz.
    </p>
    <div class="highlight-box">
      <p>🎓 Hesabınız doğrulandı ve tüm özelliklere erişiminiz açıldı.</p>
      <p>Uygulamayı açmak için aşağıdaki butona tıklayabilirsiniz.</p>
    </div>
    <p class="text">
      SDAL, mezunlarımızın birbirini bulduğu, deneyimlerini ve bilgilerini paylaştığı,
      hep birlikte büyüdüğü bir platform. Sizi burada görmek bizim için çok değerli.
    </p>
    <p class="text">Uygulamada yapabileceklerinizden bazıları:</p>
    <ul class="feature-list">
      <li>Mezun ve öğretmenlerimizle bağlantı kurun, eski arkadaşlarınızı bulun</li>
      <li>Kariyer fırsatlarını ve ilanlarını keşfedin, deneyimlerinizi paylaşın</li>
      <li>Etkinliklere, gruplara ve topluluklara katılın</li>
      <li>Öğrencilere mentorluk yapın veya profesyonellerden tavsiye alın</li>
      <li>Fotoğraf albümlerimizde okul anılarına göz atın ve yeni anılar ekleyin</li>
      <li>Doğrudan mesajlaşma ile eski ve yeni bağlantılarınızla iletişimde kalın</li>
    </ul>
    <p class="text">
      Öğretmenlerimiz de bu platformda sizinle. Onlarla yeniden bağ kurmak,
      teşekkürlerinizi iletmek veya sadece merhaba demek için bu eşsiz fırsatı kaçırmayın.
    </p>
    <div class="cta-container">
      <a href="${deepLink}" class="cta-button">Uygulamayı Aç</a>
      <p class="cta-note">Uygulama yüklü değilse App Store veya Google Play üzerinden indirebilirsiniz.</p>
    </div>
    <hr class="divider">
    <p class="text" style="font-size:13px; color:#757575;">
      Tekrar hoş geldiniz! SDAL topluluğuna katkılarınızı sabırsızlıkla bekliyoruz.
      Herhangi bir sorunuz olursa uygulama içindeki destek bölümünden bize ulaşabilirsiniz.
    </p>
  `;

  return {
    subject: `${APP_NAME} - Profil Doğrulamanız Onaylandı 🎉`,
    html: buildHtmlWrapper(bodyContent),
    text: `${greeting}\n\nProfil doğrulama talebiniz onaylandı! SDAL ailesine hoş geldiniz.\n\nUygulamayı açmak için: ${deepLink}\n\nMezunlar ve öğretmenlerimizle bağlantı kurun, kariyer fırsatlarını keşfedin ve topluluğumuza katılın.\n\nSorularınız için uygulama içindeki destek bölümünü kullanabilirsiniz.`
  };
}

export function buildTeacherApprovalEmail({ firstName = '', appDeepLink = null } = {}) {
  const deepLink = appDeepLink || buildDeepLink('/notifications');
  const greeting = firstName ? `Değerli Öğretmenimiz ${firstName},` : 'Değerli Öğretmenimiz,';

  const bodyContent = `
    <p class="greeting">${greeting}</p>
    <p class="text">
      Profil doğrulama talebiniz onaylandı. SDAL platformuna hoş geldiniz;
      sizi burada ağırlamak bizim için büyük bir onurdur.
    </p>
    <div class="highlight-box">
      <p>🏅 Öğretmen hesabınız doğrulandı ve tüm özelliklere erişiminiz açıldı.</p>
      <p>Uygulamayı açmak için aşağıdaki butona tıklayabilirsiniz.</p>
    </div>
    <p class="text">
      SDAL, mezunlarımızın ve öğretmenlerimizin bir araya geldiği, köklü bağları
      canlı tutan özel bir platform. Siz değerli öğretmenlerimiz bu topluluğun
      en kıymetli üyelerindensiniz.
    </p>
    <p class="text">Platform üzerinden yapabileceklerinizden bazıları:</p>
    <ul class="feature-list">
      <li>Mezunlarınızla yeniden bağlantı kurun ve onların gelişimlerini takip edin</li>
      <li>Mesleki deneyimlerinizi, başarılarınızı ve yazılarınızı toplulukla paylaşın</li>
      <li>Öğrencilerinize rehberlik ve mentorluk imkânı sunun</li>
      <li>Diğer öğretmen meslektaşlarınızla iletişim kurun, deneyim paylaşın</li>
      <li>Etkinlik ve duyuruları takip edin, topluluğu bilgilendirin</li>
      <li>Okulun fotoğraf albümlerine katkıda bulunun ve eski anılara göz atın</li>
    </ul>
    <p class="text">
      Uygulamanın üst menüsünden ve keşfet bölümünden tüm özelliklere
      kolayca ulaşabilirsiniz. Herhangi bir konuda yardıma ihtiyaç duyarsanız
      uygulama içindeki destek bölümünü kullanabilirsiniz.
    </p>
    <div class="cta-container">
      <a href="${deepLink}" class="cta-button">Uygulamayı Aç</a>
      <p class="cta-note">Uygulama yüklü değilse App Store veya Google Play üzerinden indirebilirsiniz.</p>
    </div>
    <hr class="divider">
    <p class="text" style="font-size:13px; color:#757575;">
      Saygılarımızla, SDAL ekibi. Sorularınız veya önerileriniz için
      uygulama içindeki destek bölümünden bize ulaşabilirsiniz.
    </p>
  `;

  return {
    subject: `${APP_NAME} - Öğretmen Hesabınız Doğrulandı`,
    html: buildHtmlWrapper(bodyContent),
    text: `${greeting}\n\nProfil doğrulama talebiniz onaylandı. SDAL platformuna hoş geldiniz.\n\nUygulamayı açmak için: ${deepLink}\n\nMezunlarınızla bağlantı kurun, deneyimlerinizi paylaşın ve topluluğumuza katkıda bulunun.\n\nSorularınız için uygulama içindeki destek bölümünü kullanabilirsiniz.`
  };
}

export function buildVerificationApprovalEmail({ isTeacher = false, firstName = '', appDeepLink = null } = {}) {
  return isTeacher
    ? buildTeacherApprovalEmail({ firstName, appDeepLink })
    : buildAlumniApprovalEmail({ firstName, appDeepLink });
}
