import React, { useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useNetworkingHubState } from '../hooks/useNetworkingHubState.js';
import { useI18n } from '../utils/i18n.jsx';
import { useNotificationNavigationTracking } from '../utils/notificationNavigation.js';
import { NETWORKING_TELEMETRY_EVENTS, sendNetworkingTelemetry } from '../utils/networkingTelemetry.js';

function daysSince(value) {
  if (!value) return null;
  const ts = new Date(value).getTime();
  if (!Number.isFinite(ts)) return null;
  return Math.floor((Date.now() - ts) / (24 * 60 * 60 * 1000));
}

function staleHint(value, t) {
  const age = daysSince(value);
  if (age == null || age < 7) return null;
  if (age >= 30) return t('network_hub_stale_30d');
  return t('network_hub_stale_7d');
}

function readConnectionUserField(item, legacyKey, modernKey) {
  return item?.[legacyKey] || item?.[modernKey] || '';
}

function avatarUrl(photo) {
  return photo ? `/api/media/vesikalik/${photo}` : '/legacy/vesikalik/nophoto.jpg';
}

function PersonLink({ href, photo, name, handle, meta }) {
  return (
    <div className="network-person-block">
      <a href={href} className="network-avatar-link">
        <img src={avatarUrl(photo)} alt="" />
      </a>
      <div className="network-person-copy">
        <div className="network-person-name">{name}</div>
        <div className="network-person-handle">@{handle}</div>
        {meta ? <div className="network-person-meta">{meta}</div> : null}
      </div>
    </div>
  );
}

function SectionCard({ sectionId, title, kicker, description, count, actions, children }) {
  return (
    <section id={sectionId} className="panel network-section-card">
      <div className="network-section-head">
        <div>
          <span className="network-section-kicker">{kicker}</span>
          <h3>{title}</h3>
          {description ? <p>{description}</p> : null}
        </div>
        <div className="network-section-tools">
          {typeof count === 'number' ? <span className="chip">{count}</span> : null}
          {actions}
        </div>
      </div>
      <div className="panel-body network-section-body">{children}</div>
    </section>
  );
}

function LoadingState({ label = 'Yükleniyor...' }) {
  return (
    <div className="network-empty-state network-loading-state">
      <strong>{label}</strong>
      <span>Veriler arka planda hazırlanıyor.</span>
    </div>
  );
}

function EmptyState({ title, description, actionLabel, actionHref }) {
  return (
    <div className="network-empty-state">
      <strong>{title}</strong>
      <span>{description}</span>
      {actionLabel && actionHref ? <a className="btn ghost" href={actionHref}>{actionLabel}</a> : null}
    </div>
  );
}

function PriorityCard({ label, count, title, description, actionLabel, actionHref, tone = 'neutral' }) {
  return (
    <article className={`network-priority-card network-priority-card-${tone}`}>
      <div className="network-priority-head">
        <span className="network-priority-label">{label}</span>
        <span className="chip">{count}</span>
      </div>
      <strong>{title}</strong>
      <p>{description}</p>
      <a className="btn ghost" href={actionHref}>{actionLabel}</a>
    </article>
  );
}

export default function NetworkingHubPage() {
  const { t } = useI18n();
  const [searchParams] = useSearchParams();
  const { state, actions } = useNetworkingHubState(t);
  const {
    bootstrapping,
    hubRefreshing,
    discoveryLoading,
    metricsWindow,
    metrics,
    loadError,
    loadNotice,
    feedback,
    incoming,
    outgoing,
    incomingMentorship,
    outgoingMentorship,
    teacherEvents,
    teacherUnreadCount,
    suggestions,
    followingIds,
    incomingConnectionMap,
    outgoingConnectionMap,
    pendingAction
  } = state;
  const actionableCount = incoming.length + incomingMentorship.length + teacherUnreadCount;
  const acceptedConnections = Number(metrics.connections?.accepted || 0);
  const mentorshipWins = Number(metrics.mentorship?.accepted || 0);
  const teacherLinksCreated = Number(metrics.teacherLinks?.created || 0);
  const focusedSection = String(searchParams.get('section') || '').trim();
  const focusedRequestId = Number(searchParams.get('request') || 0);
  const focusedNotificationId = Number(searchParams.get('notification') || 0);
  const notificationLandingResolved = !focusedNotificationId || (
    focusedSection === 'incoming-connections'
      ? incoming.some((item) => Number(item.id || 0) === focusedRequestId)
      : focusedSection === 'incoming-mentorship'
        ? incomingMentorship.some((item) => Number(item.id || 0) === focusedRequestId)
        : focusedSection === 'outgoing-connections'
          ? outgoing.some((item) => Number(item.id || 0) === focusedRequestId)
          : focusedSection === 'outgoing-mentorship'
            ? outgoingMentorship.some((item) => Number(item.id || 0) === focusedRequestId)
            : focusedSection === 'teacher-notifications'
              ? teacherEvents.some((item) => Number(item.id || 0) === focusedNotificationId)
              : Boolean(focusedSection)
  );

  useNotificationNavigationTracking(focusedNotificationId, {
    surface: 'network_hub',
    resolved: notificationLandingResolved
  });

  useEffect(() => {
    void sendNetworkingTelemetry({
      eventName: NETWORKING_TELEMETRY_EVENTS.hubViewed,
      sourceSurface: 'network_hub'
    });
  }, []);

  useEffect(() => {
    if (!focusedSection || typeof document === 'undefined') return;
    const timer = window.setTimeout(() => {
      const node = document.getElementById(focusedSection);
      node?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 180);
    return () => window.clearTimeout(timer);
  }, [focusedSection, bootstrapping]);

  const priorityCards = [
    incoming.length > 0
      ? {
          key: 'incoming',
          tone: 'hot',
          label: 'Bağlantı kuyruğu',
          count: incoming.length,
          title: `${incoming.length} bağlantı isteği seni bekliyor`,
          description: 'Önce bu kuyruğu temizlersen yeni ilişki kararların ve mesaj akışın daha net kalır.',
          actionLabel: 'Şimdi incele',
          actionHref: '#incoming-connections'
        }
      : {
          key: 'incoming',
          tone: 'calm',
          label: 'Bağlantı kuyruğu',
          count: 0,
          title: 'Bağlantı isteği kuyruğun temiz',
          description: 'Yeni kişiler keşfetmek için aşağıdaki öneri kartlarına veya Explore ekranına geçebilirsin.',
          actionLabel: 'Önerilere git',
          actionHref: '#network-suggestions'
        },
    incomingMentorship.length > 0
      ? {
          key: 'mentorship',
          tone: 'warm',
          label: 'Mentorluk kuyruğu',
          count: incomingMentorship.length,
          title: `${incomingMentorship.length} mentorluk talebi cevap bekliyor`,
          description: 'Mentor olarak görünürlüğün bu bölümde somut ilişkiye dönüşür; gecikmeden değerlendirmen faydalı olur.',
          actionLabel: 'Mentorlukları aç',
          actionHref: '#incoming-mentorship'
        }
      : {
          key: 'mentorship',
          tone: 'calm',
          label: 'Mentorluk kuyruğu',
          count: 0,
          title: 'Aktif mentorluk talebi yok',
          description: 'Profilindeki uzmanlık, başlık ve mentorluk alanları güncel kaldıkça yeni talepler burada görünür.',
          actionLabel: 'Profili gözden geçir',
          actionHref: '/new/profile'
        },
    teacherUnreadCount > 0
      ? {
          key: 'teacher',
          tone: 'accent',
          label: 'Öğretmen graph bildirimleri',
          count: teacherUnreadCount,
          title: `${teacherUnreadCount} öğretmen ağı bildirimi yeni`,
          description: 'Mezunların seni graph’a eklediği kayıtları buradan görür, güven sinyalinin nasıl büyüdüğünü izlersin.',
          actionLabel: 'Bildirimleri gör',
          actionHref: '#teacher-notifications'
        }
      : {
          key: 'teacher',
          tone: 'calm',
          label: 'Öğretmen graph bildirimleri',
          count: 0,
          title: 'Yeni teacher network bildirimi yok',
          description: 'Yeni bağlar geldikçe burada görünür; sen de Teacher Network ekranından mevcut öğretmen ilişkilerini güçlendirebilirsin.',
          actionLabel: 'Teacher Network aç',
          actionHref: '/new/network/teachers'
        }
  ];

  return (
    <Layout title={t('network_hub_title')}>
      <section className="network-hero">
        <div className="network-hero-copy">
          <span className="network-eyebrow">Networking command center</span>
          <h2>{t('network_hub_intro_title')}</h2>
          <p>{t('network_hub_intro_subtitle')}</p>
          <div className="network-inline-stats">
            <div className="network-inline-stat">
              <strong>{actionableCount}</strong>
              <span>Aksiyon bekleyen konu</span>
            </div>
            <div className="network-inline-stat">
              <strong>{acceptedConnections}</strong>
              <span>Kabul edilen bağlantı</span>
            </div>
            <div className="network-inline-stat">
              <strong>{mentorshipWins + teacherLinksCreated}</strong>
              <span>Mentorluk ve öğretmen bağı</span>
            </div>
          </div>
        </div>
        <div className="network-hero-actions">
          <a className="btn primary" href="/new/explore">Yeni kişi keşfet</a>
          <a className="btn ghost" href="/new/network/teachers">Öğretmen ağına git</a>
          <a className="btn ghost" href="/new/messages">Mesaj kutusuna git</a>
          {hubRefreshing ? <span className="chip">Arka planda güncelleniyor</span> : null}
        </div>
      </section>

      <section className="panel network-priority-strip">
        <div className="network-section-head">
          <div>
            <span className="network-section-kicker">Şimdi ilgilenmen gerekenler</span>
            <h3>Öncelik şeridi</h3>
            <p>İlk bakışta hangi networking işinin senden aksiyon beklediğini gösterir.</p>
          </div>
          <div className="network-section-tools">
            <span className="chip">{actionableCount} açık konu</span>
          </div>
        </div>
        <div className="panel-body network-section-body">
          <div className="network-priority-grid">
            {priorityCards.map((card) => (
              <PriorityCard key={card.key} {...card} />
            ))}
          </div>
        </div>
      </section>

      <div className="network-feedback-slot">
        {feedback.message ? <div className={feedback.type === 'error' ? 'error' : 'ok'}>{feedback.message}</div> : null}
        {loadError ? <div className="error">{loadError}</div> : null}
        {loadNotice ? <div className="network-soft-alert">{loadNotice}</div> : null}
      </div>

      <section id="health-snapshot" className="panel network-section-card">
        <div className="network-section-head">
          <div>
            <span className="network-section-kicker">Health snapshot</span>
            <h3>{t('network_hub_metrics_title')}</h3>
            <p>Bağlantı, mentorluk ve teacher graph akışının bu periyottaki genel sağlığını gösterir.</p>
          </div>
          <div className="network-section-tools">
            <div className="network-window-tabs">
              {['7d', '30d', '90d'].map((windowValue) => (
                <button
                  key={windowValue}
                  className={`btn ${metricsWindow === windowValue ? 'primary' : 'ghost'}`}
                  onClick={() => actions.setMetricsWindow(windowValue)}
                >
                  {t('network_hub_window_days', { days: windowValue.replace('d', '') })}
                </button>
              ))}
            </div>
          </div>
        </div>
        <div className="panel-body network-section-body">
          {bootstrapping ? <LoadingState label={t('loading')} /> : (
            <div className="network-metric-grid">
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_connections')}</span>
                <strong>{metrics.connections?.accepted || 0}</strong>
                <p>{t('network_hub_metric_requested_short', { count: metrics.connections?.requested || 0 })}</p>
              </div>
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_pending')}</span>
                <strong>{metrics.connections?.pending_incoming || 0}</strong>
                <p>{t('network_hub_metric_outgoing_short', { count: metrics.connections?.pending_outgoing || 0 })}</p>
              </div>
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_mentorship')}</span>
                <strong>{metrics.mentorship?.accepted || 0}</strong>
                <p>{t('network_hub_metric_requested_short', { count: metrics.mentorship?.requested || 0 })}</p>
              </div>
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_teacher_links')}</span>
                <strong>{metrics.teacherLinks?.created || 0}</strong>
                <p>
                  {metrics.time_to_first_network_success_days == null
                    ? t('network_hub_metric_ttf_empty')
                    : t('network_hub_metric_ttf_value', { days: metrics.time_to_first_network_success_days })}
                </p>
              </div>
            </div>
          )}
        </div>
      </section>

      <div className="network-dashboard">
        <div className="network-column">
          <SectionCard
            sectionId="incoming-connections"
            title={t('network_hub_incoming_title')}
            kicker="Priority queue"
            description="Sana gelen yeni bağlantı isteklerini burada kabul eder, yok sayar ve temiz bir çalışma kuyruğu tutarsın."
            count={incoming.length}
          >
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && incoming.length === 0 ? (
              <EmptyState
                title="Şu an bekleyen bağlantı isteğin yok."
                description="Yeni kişiler keşfetmek için öneri kartlarına göz atabilir veya Explore ekranından ağını genişletebilirsin."
                actionLabel="Önerilere git"
                actionHref="#network-suggestions"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {incoming.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'incoming-connections' && focusedRequestId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={item.id}
                  >
                    <PersonLink
                      href={`/new/members/${item.sender_id}`}
                      photo={readConnectionUserField(item, 'user_resim', 'resim')}
                      name={`${readConnectionUserField(item, 'user_isim', 'isim')} ${readConnectionUserField(item, 'user_soyisim', 'soyisim')}`}
                      handle={readConnectionUserField(item, 'user_kadi', 'kadi')}
                    />
                    <div className="network-card-actions">
                      <button className="btn primary" onClick={() => actions.acceptRequest(item.id)} disabled={Boolean(pendingAction[`accept-${item.id}`])}>{t('connection_accept')}</button>
                      <button className="btn ghost" onClick={() => actions.ignoreRequest(item.id)} disabled={Boolean(pendingAction[`ignore-${item.id}`])}>{t('ignore')}</button>
                    </div>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>

          <SectionCard
            sectionId="incoming-mentorship"
            title={t('network_hub_mentorship_incoming_title')}
            kicker="Mentor queue"
            description="Mentor görünürlüğün üzerinden gelen talepler burada toplanır; hızlı cevap güveni ve dönüşümü artırır."
            count={incomingMentorship.length}
          >
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && incomingMentorship.length === 0 ? (
              <EmptyState
                title="Aktif mentorluk talebi yok."
                description="Mentor görünürlüğünü artırmak için profilindeki uzmanlık alanlarını ve mentorluk başlıklarını güncel tutabilirsin."
                actionLabel="Profili aç"
                actionHref="/new/profile"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {incomingMentorship.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'incoming-mentorship' && focusedRequestId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={`mi-${item.id}`}
                  >
                    <PersonLink
                      href={`/new/members/${item.requester_id}`}
                      photo={item.resim}
                      name={`${item.isim} ${item.soyisim}`}
                      handle={item.kadi}
                      meta={item.focus_area || staleHint(item.created_at, t)}
                    />
                    <div className="network-card-actions">
                      <button className="btn primary" onClick={() => actions.acceptMentorship(item.id)} disabled={Boolean(pendingAction[`mentorship-accept-${item.id}`])}>{t('connection_accept')}</button>
                      <button className="btn ghost" onClick={() => actions.declineMentorship(item.id)} disabled={Boolean(pendingAction[`mentorship-decline-${item.id}`])}>{t('network_hub_decline')}</button>
                    </div>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>
        </div>

        <div className="network-column">
          <SectionCard
            sectionId="teacher-notifications"
            title={t('network_hub_teacher_links_title')}
            kicker="Verified graph"
            description="Mezunların seni öğretmen graph’ına eklediği kayıtlar burada görünür; bu panel güven ve ağ derinliği sinyallerini takip etmeni sağlar."
            count={teacherUnreadCount}
            actions={teacherUnreadCount > 0 ? (
              <button className="btn ghost" onClick={() => actions.markTeacherLinksRead()} disabled={Boolean(pendingAction['teacher-links-read'])}>
                {t('network_hub_mark_teacher_links_read')}
              </button>
            ) : null}
          >
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && teacherEvents.length === 0 ? (
              <EmptyState
                title="Henüz öğretmen ağı bildirimi yok."
                description="Mezunlar seni öğretmen graph’ına ekledikçe burada görünür. Mevcut bağlarını güçlendirmek için Teacher Network ekranına geçebilirsin."
                actionLabel="Teacher Network aç"
                actionHref="/new/network/teachers"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {teacherEvents.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'teacher-notifications' && focusedNotificationId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={`tl-${item.id}`}
                  >
                    <PersonLink
                      href={`/new/members/${item.source_user_id}`}
                      photo={item.resim}
                      name={`${item.isim} ${item.soyisim}`}
                      handle={item.kadi}
                      meta={item.message || t('network_hub_teacher_links_default_message')}
                    />
                    {!item.read_at ? <span className="chip">Yeni</span> : null}
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>

          <SectionCard
            sectionId="outgoing-connections"
            title={t('network_hub_outgoing_title')}
            kicker="Pipeline"
            description="Gönderdiğin bağlantı isteklerinin cevap durumunu burada izlersin; bu bölüm aktif ilişki başlatma yükünü gösterir."
            count={outgoing.length}
          >
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && outgoing.length === 0 ? (
              <EmptyState
                title="Şu an cevap bekleyen giden bağlantı isteğin yok."
                description="Yeni bir ilişki başlatmak için aşağıdaki önerilen bağlantılar bölümüne veya Explore ekranına gidebilirsin."
                actionLabel="Yeni kişi keşfet"
                actionHref="/new/explore"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {outgoing.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'outgoing-connections' && focusedRequestId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={item.id}
                  >
                    <PersonLink
                      href={`/new/members/${item.receiver_id}`}
                      photo={readConnectionUserField(item, 'user_resim', 'resim')}
                      name={`${readConnectionUserField(item, 'user_isim', 'isim')} ${readConnectionUserField(item, 'user_soyisim', 'soyisim')}`}
                      handle={readConnectionUserField(item, 'user_kadi', 'kadi')}
                    />
                    <span className="chip">{t('connection_pending')}</span>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>

          <SectionCard
            sectionId="outgoing-mentorship"
            title={t('network_hub_mentorship_outgoing_title')}
            kicker="Outbound mentor asks"
            description="Gönderdiğin mentorluk talepleri burada görünür; doğru kişiye ulaşıp ulaşmadığını bu kuyrukla izlersin."
            count={outgoingMentorship.length}
          >
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && outgoingMentorship.length === 0 ? (
              <EmptyState
                title="Bekleyen mentorluk talebin yok."
                description="Mentor ararken önce öneri kartlarını inceleyebilir, ardından uygun kişiyle mesaj veya bağlantı akışını başlatabilirsin."
                actionLabel="Önerilere git"
                actionHref="#network-suggestions"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {outgoingMentorship.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'outgoing-mentorship' && focusedRequestId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={`mo-${item.id}`}
                  >
                    <PersonLink
                      href={`/new/members/${item.mentor_id}`}
                      photo={item.resim}
                      name={`${item.isim} ${item.soyisim}`}
                      handle={item.kadi}
                      meta={item.focus_area || staleHint(item.created_at, t)}
                    />
                    <a className="btn ghost" href="/new/messages">{t('member_send_message')}</a>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>
        </div>
      </div>

      <SectionCard
        sectionId="network-suggestions"
        title={t('network_hub_suggestions_title')}
        kicker="Discovery engine"
        description="Teacher graph, ortak bağlar ve güven sinyallerine göre önerilen kişileri burada görürsün."
        count={suggestions.length}
      >
        {discoveryLoading ? <LoadingState label="Öneriler hazırlanıyor..." /> : null}
        {!discoveryLoading && suggestions.length === 0 ? (
          <EmptyState
            title="Şimdilik yeni öneri yok."
            description="Teacher Network ve bağlantı geçmişin büyüdükçe burada daha isabetli adaylar görünür. Biraz sonra yeniden dene veya Explore ekranına geç."
            actionLabel="Explore aç"
            actionHref="/new/explore"
          />
        ) : null}
        {!discoveryLoading ? (
          <div className="network-suggestion-grid">
            {suggestions.map((item) => {
              const key = Number(item.id || 0);
              const incomingRequestId = Number(incomingConnectionMap[key] || 0);
              const outgoingRequestId = Number(outgoingConnectionMap[key] || 0);
              const outgoingPending = outgoingRequestId > 0;
              const label = incomingRequestId
                ? t('connection_accept')
                : outgoingPending
                  ? t('connection_withdraw')
                  : t('connection_request');
              return (
                <article className="network-suggestion-card" key={item.id}>
                  <PersonLink
                    href={`/new/members/${item.id}`}
                    photo={item.resim}
                    name={`${item.isim} ${item.soyisim}${item.verified ? ' ✓' : ''}`}
                    handle={item.kadi}
                    meta={Array.isArray(item.reasons) && item.reasons.length > 0 ? item.reasons[0] : ''}
                  />
                  <div className="network-card-actions">
                    <button
                      className="btn ghost"
                      onClick={() => actions.connectUser(item.id)}
                      disabled={Boolean(pendingAction[`connect-${item.id}`])}
                    >
                      {label}
                    </button>
                    <button
                      className="btn ghost"
                      onClick={() => actions.toggleFollow(item.id)}
                      disabled={Boolean(pendingAction[`follow-${item.id}`])}
                    >
                      {followingIds.has(Number(item.id)) ? t('unfollow') : t('follow')}
                    </button>
                  </div>
                </article>
              );
            })}
          </div>
        ) : null}
      </SectionCard>
    </Layout>
  );
}
