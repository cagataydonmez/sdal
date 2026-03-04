/**
 * Modern domain entities used internally during migration from legacy table/field names.
 * API response shapes are adapted at the controller boundary.
 */

/** @typedef {{
 * id:number,
 * username:string,
 * firstName:string,
 * lastName:string,
 * email:string|null,
 * avatarUrl:string|null,
 * banned:boolean,
 * active:boolean,
 * role:string,
 * admin:boolean,
 * verified:boolean,
 * profileCompleted:boolean,
 * graduationYear:number|null,
 * legacy?:Record<string, any>
 * }} User */

/** @typedef {{
 * id:number,
 * authorId:number,
 * content:string,
 * imageUrl:string|null,
 * imageRecordId:string|null,
 * createdAt:string,
 * groupId:number|null,
 * author?:User|null,
 * likeCount?:number,
 * commentCount?:number,
 * likedByViewer?:boolean,
 * legacy?:Record<string, any>
 * }} Post */

/** @typedef {{
 * id:number,
 * postId:number,
 * authorId:number,
 * body:string,
 * createdAt:string,
 * author?:User|null,
 * legacy?:Record<string, any>
 * }} Comment */

/** @typedef {{
 * id:number,
 * authorId:number,
 * body:string,
 * createdAt:string,
 * author?:User|null,
 * legacy?:Record<string, any>
 * }} Message */

/** @typedef {{
 * id:number,
 * userId:number,
 * expiresAt:string|null,
 * createdAt:string,
 * legacy?:Record<string, any>
 * }} Story */

/** @typedef {{ id:number, userId:number, type:string, createdAt:string, legacy?:Record<string, any> }} Notification */
/** @typedef {{ id:number, ownerId:number, createdAt:string, legacy?:Record<string, any> }} Conversation */
/** @typedef {{ id:number, ownerId:number, name:string, legacy?:Record<string, any> }} Group */
/** @typedef {{ id:number, creatorId:number, title:string, legacy?:Record<string, any> }} Event */
/** @typedef {{ id:number, creatorId:number, title:string, legacy?:Record<string, any> }} Announcement */
/** @typedef {{ id:number, posterId:number, title:string, legacy?:Record<string, any> }} Job */
/** @typedef {{ id:string, ownerId:number, kind:string, url:string, legacy?:Record<string, any> }} MediaAsset */
/** @typedef {{ key:string, value:any, legacy?:Record<string, any> }} AdminSetting */

export function toDomainUser(row) {
  if (!row) return null;
  return {
    id: Number(row.id),
    username: String(row.kadi || ''),
    firstName: String(row.isim || ''),
    lastName: String(row.soyisim || ''),
    email: row.email || null,
    avatarUrl: row.resim || null,
    banned: Number(row.yasak || 0) === 1,
    active: Number(row.aktiv ?? 1) === 1,
    role: String(row.role || '').trim().toLowerCase() || (Number(row.admin || 0) === 1 ? 'admin' : 'user'),
    admin: Number(row.admin || 0) === 1,
    verified: Number(row.verified || 0) === 1,
    profileCompleted: Number(row.ilkbd || 0) === 1,
    graduationYear: row.mezuniyetyili ? Number(row.mezuniyetyili) || null : null,
    legacy: row
  };
}

export function toDomainPost(row) {
  if (!row) return null;
  return {
    id: Number(row.id),
    authorId: Number(row.user_id),
    content: String(row.content || ''),
    imageUrl: row.image || null,
    imageRecordId: row.image_record_id || null,
    createdAt: String(row.created_at || ''),
    groupId: row.group_id == null ? null : Number(row.group_id),
    author: row.kadi || row.isim || row.soyisim || row.resim
      ? {
        id: Number(row.user_id),
        username: String(row.kadi || ''),
        firstName: String(row.isim || ''),
        lastName: String(row.soyisim || ''),
        email: null,
        avatarUrl: row.resim || null,
        banned: false,
        active: true,
        role: 'user',
        admin: false,
        verified: Number(row.verified || 0) === 1,
        profileCompleted: true,
        graduationYear: null,
        legacy: row
      }
      : null,
    likeCount: Number(row.like_count || 0),
    commentCount: Number(row.comment_count || 0),
    likedByViewer: Number(row.liked_by_viewer || 0) === 1,
    legacy: row
  };
}

export function toDomainComment(row) {
  if (!row) return null;
  return {
    id: Number(row.id),
    postId: Number(row.post_id),
    authorId: Number(row.user_id),
    body: String(row.comment || ''),
    createdAt: String(row.created_at || ''),
    author: row.kadi || row.isim || row.soyisim || row.resim
      ? {
        id: Number(row.user_id),
        username: String(row.kadi || ''),
        firstName: String(row.isim || ''),
        lastName: String(row.soyisim || ''),
        email: null,
        avatarUrl: row.resim || null,
        banned: false,
        active: true,
        role: 'user',
        admin: false,
        verified: Number(row.verified || 0) === 1,
        profileCompleted: true,
        graduationYear: null,
        legacy: row
      }
      : null,
    legacy: row
  };
}

export function toDomainMessage(row) {
  if (!row) return null;
  return {
    id: Number(row.id),
    authorId: Number(row.user_id),
    body: String(row.message || ''),
    createdAt: String(row.created_at || ''),
    author: row.kadi || row.isim || row.soyisim || row.resim
      ? {
        id: Number(row.user_id),
        username: String(row.kadi || ''),
        firstName: String(row.isim || ''),
        lastName: String(row.soyisim || ''),
        email: null,
        avatarUrl: row.resim || null,
        banned: false,
        active: true,
        role: 'user',
        admin: false,
        verified: Number(row.verified || 0) === 1,
        profileCompleted: true,
        graduationYear: null,
        legacy: row
      }
      : null,
    legacy: row
  };
}
