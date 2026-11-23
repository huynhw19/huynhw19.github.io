# ConfigKit Kids Messages

## Audience and permissions
- Children can message their parent/guardian and teachers explicitly approved by their parent.
- A teacher must be linked to the child's Education student record. A parent links the record using the Student ID supplied by the teacher, then separately approves the teacher's messaging request.
- Child-to-child friendships require approval from both children's parent/guardian accounts. Teacher approval is not required.
- No public child directory, stranger requests, or open direct messages.
- Families already using ConfigKit can invite another family by sharing a child's private friend code. A family new to ConfigKit must first create a free parent account and child profile; the parents then review and approve the friendship request.

## Child-facing content
- Text, emoji/sticker messages, and bounded drawing payloads.
- Photo, video, and document uploads are disabled for Kids Messages. Database constraints reject media fields and Storage blocks new uploads to the legacy chat bucket.
- Existing parent-controlled voice/video calling is separate from message attachments and remains subject to the existing call permissions. Calls also require both families to approve and both children to have calling enabled.

## Parent transparency and supervision
Children are told before using the feature that their parent/guardian can read all their messages, including child-to-child and teacher conversations. Parents can review peer conversations and all adult conversations from the Kids Messages Parent Centre. Parents can send in the family conversation; they cannot impersonate a teacher in a teacher thread. The current Family Dashboard associates each child with one primary parent account; additional guardian accounts are not automatically granted access.
The Family Dashboard Parent Inbox shows friendship requests and in-app safety reports. Parents can approve or reject requests, remove approved friendships, and review reports. This is an in-app safety inbox, not a push notification or email alert service.

## Teacher boundaries
Teachers see only linked students whose parent has approved messaging. They can send and receive in their own student conversation. Teachers cannot read family or peer conversations and are not required to approve child-to-child friendships.

## Database and server controls
- kids_teacher_contacts: parent-approved teacher access.
- kids_education_links: parent-authorised link between a family child and an Education student record; direct client writes are not granted.
- kids_adult_conversations / kids_adult_messages: private parent/teacher conversations.
- Existing kids_friendships / kids_messages: peer conversations requiring both family approvals.
- Row Level Security and private helper functions enforce access; the Edge Function verifies caller identity before privileged parent and teacher actions.
- A database trigger limits each sender to 20 messages per minute. Changing or removing an Education link revokes teacher contacts but does not revoke an independently parent-approved friendship.
- kids_messages_safe_content_only and kids_adult_messages_safe_content restrict payloads to text, stickers, or bounded drawing JSON.
- Report and remove-friend controls reuse the existing Kids safety tables and parent inbox.

## Entry points
- Child: Kids Zone → Kids Messages.
- Parent: Family Dashboard → Kids Messages Parent Centre.
- Teacher: Education Dashboard → Kids Messages for linked students.

## First-use setup
1. Parent creates a child profile, enables Kids Messages and sets the child's six-digit PIN in Family Dashboard.
2. The other family creates its own parent account and child profile if they are new to ConfigKit.
3. Parents exchange the child's private friend code; the child sends the request.
4. Each child's parent/guardian approves the friendship in the Family Dashboard Parent Inbox.
5. Once both families approve, the children can chat. A linked teacher is optional and is not part of peer-chat approval.

## QA limitations
The parent-only approval migration and Edge Function changes are being deployed alongside the updated pages. The authenticated multi-account workflow has not been exercised in a real browser session. Test with two parent accounts and two child profiles before using this with real children; verify one-sided approval remains pending, both approvals enable chat, a parent can read both sides of the transcript, removing a friendship blocks further messages, and teachers cannot read peer conversations.
