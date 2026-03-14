# Bildirim Sistemi Foundation Baseline

Bu doküman Sprint A kapsamındaki `NTF0-S1`, `NTF0-S2` ve `NTF0-S3` çıktısını tek yerde toplar.

## 1. Notification Type Inventory

### Social

- `like`
- `comment`
- `mention_post`
- `mention_photo`
- `photo_comment`
- `follow`

### Messaging

- `mention_message`

### Groups

- `mention_group`
- `group_join_request`
- `group_join_approved`
- `group_join_rejected`
- `group_invite`

### Events

- `mention_event`
- `event_comment`
- `event_invite`

### Networking

- `connection_request`
- `connection_accepted`
- `mentorship_request`
- `mentorship_accepted`
- `teacher_network_linked`

### Jobs

- `job_application`

## 2. Canonical Routing Matrix

- `like`, `comment`, `mention_post` -> `/new?post=:id&notification=:notificationId`
- `mention_photo`, `photo_comment` -> `/new/albums/photo/:id?notification=:notificationId`
- `mention_message` -> `/new/messages/:id?notification=:notificationId`
- `follow` -> `/new/members/:sourceUserId?notification=:notificationId&context=follow`
- `mention_group` -> `/new/groups/:id?tab=posts&notification=:notificationId`
- `group_join_request` -> `/new/groups/:id?tab=requests&notification=:notificationId`
- `group_join_approved`, `group_join_rejected` -> `/new/groups/:id?tab=members&notification=:notificationId`
- `group_invite` -> `/new/groups/:id?tab=invite&notification=:notificationId`
- `mention_event`, `event_comment` -> `/new/events?event=:id&focus=comments&notification=:notificationId`
- `event_invite` -> `/new/events?event=:id&focus=response&notification=:notificationId`
- `connection_request` -> `/new/network/hub?section=incoming-connections&request=:requestId&notification=:notificationId`
- `connection_accepted` -> `/new/members/:sourceUserId?notification=:notificationId&context=connection_accepted`
- `mentorship_request` -> `/new/network/hub?section=incoming-mentorship&request=:requestId&notification=:notificationId`
- `mentorship_accepted` -> `/new/members/:sourceUserId?notification=:notificationId&context=mentorship_accepted`
- `teacher_network_linked` -> `/new/network/hub?section=teacher-notifications&notification=:notificationId&link=:linkId`
- `job_application` -> `/new/jobs?job=:jobId&tab=applications&notification=:notificationId`

## 3. Category and Priority Model

### `social`

- `like` -> `informational`
- `comment` -> `important`
- `mention_post` -> `important`
- `mention_photo` -> `important`
- `photo_comment` -> `important`
- `follow` -> `informational`

### `messaging`

- `mention_message` -> `important`

### `groups`

- `mention_group` -> `important`
- `group_join_request` -> `actionable`
- `group_join_approved` -> `important`
- `group_join_rejected` -> `important`
- `group_invite` -> `actionable`

### `events`

- `mention_event` -> `important`
- `event_comment` -> `important`
- `event_invite` -> `important`

### `networking`

- `connection_request` -> `actionable`
- `connection_accepted` -> `important`
- `mentorship_request` -> `actionable`
- `mentorship_accepted` -> `important`
- `teacher_network_linked` -> `important`

### `jobs`

- `job_application` -> `actionable`

## 4. Sprint A Notes

- Networking notification entity ids request/link id bazına geçirildi.
- Notification API artık type-derived target ve priority bilgisi üretir.
- Frontend target resolution tek registry dosyasında toplandı.
