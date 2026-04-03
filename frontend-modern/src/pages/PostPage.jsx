import React, { useEffect, useMemo, useState } from 'react';
import { Link, useParams, useSearchParams } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import PostCard from '../components/PostCard.jsx';
import { useI18n } from '../utils/i18n.jsx';
import { useNotificationNavigationTracking } from '../utils/notificationNavigation.js';

export default function PostPage() {
  const { t } = useI18n();
  const { id } = useParams();
  const [searchParams] = useSearchParams();
  const postId = Number(id || 0);
  const notificationId = Number(searchParams.get('notification') || 0);
  const [post, setPost] = useState(null);
  const [loading, setLoading] = useState(true);

  const landingResolved = Boolean(post && Number(post.id || 0) === postId);

  useNotificationNavigationTracking(notificationId, {
    surface: 'post_page',
    resolved: !notificationId || landingResolved
  });

  async function loadPost() {
    if (!postId) return;
    setLoading(true);
    try {
      const res = await fetch(`/api/new/posts/${postId}`, { credentials: 'include' });
      if (!res.ok) {
        setPost(null);
        return;
      }
      const payload = await res.json();
      setPost(payload?.item || null);
    } catch {
      setPost(null);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadPost();
  }, [postId]);

  const body = useMemo(() => {
    if (!postId) return <div className="muted">{t('not_found')}</div>;
    if (loading) return <div className="muted">{t('loading')}</div>;
    if (!post) return <div className="muted">{t('not_found')}</div>;
    return <PostCard post={post} onRefresh={loadPost} defaultCommentsOpen />;
  }, [loading, post, postId, t]);

  return (
    <Layout title="Post">
      <div className="panel" style={{ marginBottom: 12 }}>
        <Link to="/new" className="btn ghost">← {t('nav_feed')}</Link>
      </div>
      {body}
    </Layout>
  );
}
