# SDAL New Server Endpoint & API Inventory

Source: `sdal-modern/server/index.js`

Total extracted routes: **218**

## Implementation Gate
- All endpoints and behaviors listed here are considered in-scope parity targets.
- Finalization rule: after feature implementation is complete, ensure Xcode project metadata remains synchronized (project file/build phases/file references).

## Legacy ASP / compatibility routes (29)
- [x] `GET /aspcaptcha.asp` (server compatibility route; non-native parity target)
- [x] `GET /textimage.asp` (server compatibility route; non-native parity target)
- [x] `GET /uyelerkadiresimyap.asp` (server compatibility route; non-native parity target)
- [x] `GET /tid.asp` (server compatibility route; non-native parity target)
- [x] `GET /grayscale.asp` (server compatibility route; non-native parity target)
- [x] `GET /threshold.asp` (server compatibility route; non-native parity target)
- [x] `GET /kucukresim.asp` (server compatibility route; non-native parity target)
- [x] `GET /kucukresim2.asp` (server compatibility route; non-native parity target)
- [x] `GET /kucukresim3.asp` (server compatibility route; non-native parity target)
- [x] `GET /kucukresim4.asp` (server compatibility route; non-native parity target)
- [x] `GET /kucukresim5.asp` (server compatibility route; non-native parity target)
- [x] `GET /kucukresim6.asp` (server compatibility route; non-native parity target)
- [x] `GET /kucukresim7.asp` (server compatibility route; non-native parity target)
- [x] `GET /kucukresim8.asp` (server compatibility route; non-native parity target)
- [x] `GET /resimler_xml.asp` (server compatibility route; non-native parity target)
- [x] `GET /aihepsi.asp` (server compatibility route; non-native parity target)
- [x] `GET /aihepsigor.asp` (server compatibility route; non-native parity target)
- [x] `GET /ayax.asp` (server compatibility route; non-native parity target)
- [x] `GET /hmesisle.asp` (server compatibility route; non-native parity target)
- [x] `GET /onlineuyekontrol.asp` (server compatibility route; non-native parity target)
- [x] `GET /onlineuyekontrol2.asp` (server compatibility route; non-native parity target)
- [x] `GET /mesajsil.asp` (server compatibility route; non-native parity target)
- [x] `POST /albumyorumekle.asp` (server compatibility route; non-native parity target)
- [x] `GET /fizikselyol.asp` (server compatibility route; non-native parity target)
- [x] `GET /abandon.asp` (server compatibility route; non-native parity target)
- [x] `GET /logout` (server compatibility route; non-native parity target)
- [x] `GET /admincikis.asp` (server compatibility route; non-native parity target)
- [x] `GET /hirsiz.asp` (server compatibility route; non-native parity target)
- [x] `GET /hirsiz2.asp` (server compatibility route; non-native parity target)

## Media routes (2)
- [x] `GET /api/media/vesikalik/:file`
- [x] `GET /api/media/kucukresim`

## Core auth/session/profile (15)
- [x] `GET /api/health`
- [x] `GET /api/captcha`
- [x] `GET /api/session`
- [x] `POST /api/auth/login`
- [x] `POST /api/auth/logout`
- [x] `POST /api/register/preview`
- [x] `POST /api/register`
- [x] `GET /api/activate`
- [x] `POST /api/activation/resend`
- [x] `POST /api/password-reset`
- [x] `POST /api/mail/test`
- [x] `GET /api/profile`
- [x] `PUT /api/profile`
- [x] `POST /api/profile/password`
- [x] `POST /api/profile/photo`

## Legacy core data APIs (25)
- [x] `GET /api/menu`
- [x] `GET /api/sidebar`
- [x] `GET /api/members`
- [x] `GET /api/members/:id`
- [x] `GET /api/messages`
- [x] `GET /api/messages/recipients`
- [x] `GET /api/messages/:id`
- [x] `POST /api/messages`
- [x] `DELETE /api/messages/:id`
- [x] `GET /api/albums`
- [x] `GET /api/album/categories/active`
- [x] `POST /api/album/upload`
- [x] `GET /api/albums/:id`
- [x] `GET /api/photos/:id`
- [x] `GET /api/photos/:id/comments`
- [x] `POST /api/photos/:id/comments`
- [x] `GET /api/album/latest`
- [x] `GET /api/members/latest`
- [x] `POST /api/tournament/register`
- [x] `GET /api/panolar`
- [x] `POST /api/panolar`
- [x] `DELETE /api/panolar/:id`
- [x] `GET /api/quick-access`
- [x] `POST /api/quick-access/add`
- [x] `POST /api/quick-access/remove`

## Modern social APIs (/api/new/*, non-admin) (72)
- [x] `GET /api/new/feed`
- [x] `POST /api/new/posts`
- [x] `POST /api/new/posts/upload`
- [x] `PATCH /api/new/posts/:id`
- [x] `POST /api/new/posts/:id/edit`
- [x] `DELETE /api/new/posts/:id`
- [x] `POST /api/new/posts/:id/delete`
- [x] `POST /api/new/posts/:id/like`
- [x] `GET /api/new/posts/:id/comments`
- [x] `POST /api/new/posts/:id/comments`
- [x] `GET /api/new/notifications`
- [x] `POST /api/new/notifications/read`
- [x] `POST /api/new/translate`
- [x] `GET /api/new/stories`
- [x] `GET /api/new/stories/mine`
- [x] `GET /api/new/stories/user/:id`
- [x] `POST /api/new/stories/upload`
- [x] `PATCH /api/new/stories/:id`
- [x] `DELETE /api/new/stories/:id`
- [x] `POST /api/new/stories/:id/edit`
- [x] `POST /api/new/stories/:id/delete`
- [x] `POST /api/new/stories/:id`
- [x] `POST /api/new/stories/:id/remove`
- [x] `POST /api/new/stories/:id/repost`
- [x] `POST /api/new/stories/:id/view`
- [x] `POST /api/new/follow/:id`
- [x] `GET /api/new/follows`
- [x] `GET /api/new/explore/suggestions`
- [x] `GET /api/new/messages/unread`
- [x] `GET /api/new/online-members`
- [x] `GET /api/new/groups`
- [x] `POST /api/new/groups`
- [x] `POST /api/new/groups/:id/join`
- [x] `GET /api/new/groups/:id/requests`
- [x] `POST /api/new/groups/:id/requests/:requestId`
- [x] `GET /api/new/groups/:id/invitations`
- [x] `POST /api/new/groups/:id/invitations`
- [x] `POST /api/new/groups/:id/invitations/respond`
- [x] `POST /api/new/groups/:id/settings`
- [x] `POST /api/new/groups/:id/cover`
- [x] `POST /api/new/groups/:id/role`
- [x] `GET /api/new/groups/:id`
- [x] `POST /api/new/groups/:id/posts`
- [x] `POST /api/new/groups/:id/posts/upload`
- [x] `GET /api/new/groups/:id/events`
- [x] `POST /api/new/groups/:id/events`
- [x] `DELETE /api/new/groups/:id/events/:eventId`
- [x] `GET /api/new/groups/:id/announcements`
- [x] `POST /api/new/groups/:id/announcements`
- [x] `DELETE /api/new/groups/:id/announcements/:announcementId`
- [x] `GET /api/new/events`
- [x] `POST /api/new/events`
- [x] `POST /api/new/events/upload`
- [x] `POST /api/new/events/:id/approve`
- [x] `DELETE /api/new/events/:id`
- [x] `POST /api/new/events/:id/respond`
- [x] `POST /api/new/events/:id/response-visibility`
- [x] `GET /api/new/events/:id/comments`
- [x] `POST /api/new/events/:id/comments`
- [x] `POST /api/new/events/:id/notify`
- [x] `GET /api/new/announcements`
- [x] `POST /api/new/announcements`
- [x] `POST /api/new/announcements/upload`
- [x] `POST /api/new/announcements/:id/approve`
- [x] `DELETE /api/new/announcements/:id`
- [x] `GET /api/new/chat/messages`
- [x] `POST /api/new/chat/send`
- [x] `PATCH /api/new/chat/messages/:id`
- [x] `POST /api/new/chat/messages/:id/edit`
- [x] `DELETE /api/new/chat/messages/:id`
- [x] `POST /api/new/chat/messages/:id/delete`
- [x] `POST /api/new/verified/request`

## Modern admin APIs (/api/new/admin/*) (31)
- [x] `GET /api/new/admin/follows/:userId`
- [x] `GET /api/new/admin/verification-requests`
- [x] `POST /api/new/admin/verification-requests/:id`
- [x] `POST /api/new/admin/verify`
- [x] `GET /api/new/admin/engagement-ab`
- [x] `PUT /api/new/admin/engagement-ab/:variant`
- [x] `POST /api/new/admin/engagement-ab/rebalance`
- [x] `GET /api/new/admin/stats`
- [x] `GET /api/new/admin/engagement-scores`
- [x] `POST /api/new/admin/engagement-scores/recalculate`
- [x] `GET /api/new/admin/live`
- [x] `GET /api/new/admin/groups`
- [x] `DELETE /api/new/admin/groups/:id`
- [x] `GET /api/new/admin/stories`
- [x] `GET /api/new/admin/posts`
- [x] `DELETE /api/new/admin/posts/:id`
- [x] `DELETE /api/new/admin/stories/:id`
- [x] `GET /api/new/admin/chat/messages`
- [x] `DELETE /api/new/admin/chat/messages/:id`
- [x] `GET /api/new/admin/messages`
- [x] `DELETE /api/new/admin/messages/:id`
- [x] `GET /api/new/admin/filters`
- [x] `POST /api/new/admin/filters`
- [x] `PUT /api/new/admin/filters/:id`
- [x] `DELETE /api/new/admin/filters/:id`
- [x] `GET /api/new/admin/db/tables`
- [x] `GET /api/new/admin/db/table/:name`
- [x] `GET /api/new/admin/db/backups`
- [x] `POST /api/new/admin/db/backups`
- [x] `GET /api/new/admin/db/backups/:name/download`
- [x] `POST /api/new/admin/db/restore`

## Legacy admin APIs (/api/admin/*) (34)
- [x] `GET /api/admin/session`
- [x] `POST /api/admin/login`
- [x] `POST /api/admin/logout`
- [x] `GET /api/admin/users/lists`
- [x] `GET /api/admin/users/search`
- [x] `GET /api/admin/users/:id`
- [x] `PUT /api/admin/users/:id`
- [x] `GET /api/admin/pages`
- [x] `POST /api/admin/pages`
- [x] `PUT /api/admin/pages/:id`
- [x] `DELETE /api/admin/pages/:id`
- [x] `GET /api/admin/logs`
- [x] `POST /api/admin/email/send`
- [x] `GET /api/admin/email/categories`
- [x] `POST /api/admin/email/categories`
- [x] `PUT /api/admin/email/categories/:id`
- [x] `DELETE /api/admin/email/categories/:id`
- [x] `GET /api/admin/email/templates`
- [x] `POST /api/admin/email/templates`
- [x] `PUT /api/admin/email/templates/:id`
- [x] `DELETE /api/admin/email/templates/:id`
- [x] `POST /api/admin/email/bulk`
- [x] `GET /api/admin/album/categories`
- [x] `POST /api/admin/album/categories`
- [x] `PUT /api/admin/album/categories/:id`
- [x] `DELETE /api/admin/album/categories/:id`
- [x] `GET /api/admin/album/photos`
- [x] `POST /api/admin/album/photos/bulk`
- [x] `PUT /api/admin/album/photos/:id`
- [x] `DELETE /api/admin/album/photos/:id`
- [x] `GET /api/admin/album/photos/:id/comments`
- [x] `DELETE /api/admin/album/photos/:id/comments/:commentId`
- [x] `GET /api/admin/tournament`
- [x] `DELETE /api/admin/tournament/:id`

## Games APIs (6)
- [x] `GET /api/games/snake/leaderboard`
- [x] `POST /api/games/snake/score`
- [x] `GET /api/games/tetris/leaderboard`
- [x] `POST /api/games/tetris/score`
- [x] `GET /api/games/arcade/:game/leaderboard`
- [x] `POST /api/games/arcade/:game/score`

## Frontend delivery routes (4)
- [x] `GET /sdal_new` (web shell route; non-native parity target)
- [x] `GET /sdal_new/*` (web shell route; non-native parity target)
- [x] `GET /new/*` (web shell route; non-native parity target)
- [x] `GET *` (web fallback route; non-native parity target)

## Notes
- Some routes have alias forms (e.g., PATCH + POST edit aliases). Keep behavior-compatible support in native client implementation.
- Regex and wildcard handlers are not represented as typed API calls in native client.
