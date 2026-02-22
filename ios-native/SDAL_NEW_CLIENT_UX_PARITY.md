# SDAL New Client UX/UI Parity Inventory (Exhaustive)

Source references:
- `/Users/cagataydonmez/Desktop/SDAL/sdal_new/src/styles.css`
- `/Users/cagataydonmez/Desktop/SDAL/sdal_new/src/components/*`
- `/Users/cagataydonmez/Desktop/SDAL/sdal_new/src/pages/*`

Rule:
- This file tracks web UX patterns that must be represented natively in iOS (SwiftUI-native equivalents).
- Feature/API parity alone is not sufficient; interaction and visual behavior parity is required.

## 1) Design system & visual language
- [x] Core color system parity (light + dark token families)
- [x] Theme modes parity (light / dark / auto)
- [x] Language switcher parity (TR/EN/DE/FR)
- [x] Typography parity with explicit heading/body hierarchy (Space Grotesk + Manrope intent equivalent)
- [x] Surface system parity (card, card-alt, soft-panel, line, shadow layers)
- [x] Reusable chip/badge/pill styles parity
- [x] Global success/error/empty visual states parity

## 2) App chrome & navigation UX
- [x] Top bar: title/subtitle + actions row
- [x] User chip + dropdown quick actions
- [x] Desktop side navigation information architecture parity
- [x] Mobile hamburger + drawer + overlay parity
- [x] Mobile bottom-nav parity review (web has placeholder; native decision still tracked)
- [x] Unread badge in global nav

## 3) Feed composition & discovery UX
- [x] Feed scope tabs (all/following/popular)
- [x] Feed mobile section tabs parity (posts/notifications/livechat/online/messages/quick)
- [x] Composer with rich-text support
- [x] Post image upload controls
- [x] Filter chips and active-state visuals parity
- [x] "New posts available" sticky refresh action parity
- [x] Infinite scrolling behavior parity
- [x] Side-rail card composition parity (notifications/live/online/quick)

## 4) Post & comment card micro-interactions
- [x] Post header metadata layout parity
- [x] Like/comment action row parity
- [x] Comment list item layout parity (avatar + meta + body)
- [x] Verified mark on author/comment rows
- [x] Post action affordances parity (hover/pressed/active visual behavior)
- [x] Content-focused image sizing rules parity (`contain`, max-height behavior)

## 5) Rich text + translation UX
- [x] Rich text toolbar action set parity
- [x] Rich text placeholder/contenteditable behavior parity
- [x] Mention picker dropdown behavior parity
- [x] In-message/post translation toggle parity
- [x] Rich editor compact mode parity where applicable

## 6) Story UX (Instagram-like grouped viewer)
- [x] Story circles with viewed/unviewed ring state
- [x] Story grouping by author
- [x] Group sort behavior (unviewed first, then latest)
- [x] Full-screen story viewer presentation
- [x] Per-story progress bars
- [x] Timed auto-advance
- [x] Left/right tap zones
- [x] Horizontal swipe navigation
- [x] Vertical swipe-to-close
- [x] Caption overlay + author header
- [x] Mark-as-viewed sync while consuming stories
- [x] Story upload entry from bar
- [x] Story edit/delete/repost/manage flows
- [x] Story preloading/transition polish parity
- [x] Member detail stories use the same grouped full-screen viewer parity as feed stories

## 7) Notifications UX
- [x] Notification list with unread highlighting
- [x] Notification deep-link routing from item target
- [x] Mark-all-read flow
- [x] Invite/action chips visual-state parity (accepted/rejected badges)
- [x] Notification row spacing/visual rhythm parity

## 8) Messages UX (mailbox)
- [x] Inbox/outbox split parity
- [x] Unread filtering parity
- [x] Search within mailbox parity
- [x] 3-pane mailbox structure parity (sidebar/list/preview equivalent)
- [x] Selected message highlight parity
- [x] Message snippet + timestamp layout parity
- [x] Inline preview + fullscreen open parity
- [x] Desktop-density vs mobile-collapse visual parity

## 9) Explore/following/member UX
- [x] Suggestion cards + follow CTA parity
- [x] Explore filter controls parity (relation/sort/year/flags)
- [x] Online and verified markers parity
- [x] Infinite paging parity
- [x] Reason chips and subtle metadata styles parity

## 10) Groups UX
- [x] Groups list card layout parity
- [x] Join/request CTA states parity
- [x] Group detail timeline parity
- [x] Group events/announcements blocks parity
- [x] Role/moderation controls parity
- [x] Group hero cover/media composition parity polish
- [x] Group setting forms visual parity

## 11) Albums UX
- [x] Category chips + latest photos mosaic parity
- [x] Album upload flow parity
- [x] Album photo detail + comment flow parity
- [x] Photo grid sizing and spacing parity across breakpoints
- [x] Photo detail metadata placement parity

## 12) Events/announcements UX
- [x] Event create/suggest forms parity
- [x] RSVP action states parity (attend/decline)
- [x] Attendee visibility controls parity
- [x] Announcement create/suggest + approval controls parity
- [x] Event card information density parity
- [x] Approval moderation CTA grouping parity

## 13) Admin UX shell parity
- [x] Admin login (single-password flow)
- [x] Admin top tabs and content module loading parity
- [x] Admin user-management functional parity
- [x] Admin filters/groups/follows/engagement functional parity
- [x] Admin DB/backup/restore functional parity
- [x] Admin navigation shell parity (desktop sticky + mobile hamburger overlay)
- [x] KPI card styling parity
- [x] DB table browser visual parity (sticky headers/row rhythm)

## 14) Games UX parity
- [x] Game catalog + route-level game container parity
- [x] Score + leaderboard functional parity
- [x] Game board visual parity (Snake/Tetris/2048/memory/tap)
- [x] Mobile control ergonomics parity

## 15) Global interaction polish
- [x] Global action feedback chip parity (`GlobalActionFeedback` behavior)
- [x] Loading/skeleton rhythm parity across pages
- [x] Empty-state copy + spacing parity
- [x] Error-state hierarchy parity (inline vs toast/modal)
- [x] Motion timing parity for overlays/drawers/viewers

## 16) Responsive behavior parity
- [x] 1024px tablet behavior parity
- [x] 760px mobile behavior parity
- [x] 430px/390px compact phone behavior parity
- [x] Large desktop (1367+ / 1721+) density parity

## Implementation order (active)
1. Stories polish parity completion
2. Feed/comment/notification micro-UX parity
3. Messages mailbox visual-density parity
4. Explore/follow/group card rhythm parity
5. Events/announcements visual parity
6. Admin shell + KPI/table visual parity
7. Games board visuals + control ergonomics
8. Responsive breakpoint hardening
