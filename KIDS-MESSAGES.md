# ConfigKit Kids Messages

## Audience and permissions
- Children can message their parent/guardian and teachers explicitly approved by their parent.
- A teacher must be linked to the child's Education student record. A parent links the record using the Student ID supplied by the teacher, then separately approves the teacher's messaging request.
- Classmate chats require both families' approvals and approval from a teacher linked to both student records.
- No public child directory, stranger requests, or open direct messages.

## Child-facing content
- Text, emoji/sticker messages, and bounded drawing payloads.
- Photo, video, and document uploads are disabled for Kids Messages. Database constraints reject media fields and Storage blocks new uploads to the legacy chat bucket.
- Existing parent-controlled voice/video calling is separate from message attachments and remains subject to the existing call permissions.

## Parent transparency
Children are told before using the feature that their parent/guardian can review all their messages, including classmate and teacher conversations. Parents can review peer conversations and all adult conversations from the Family & Teacher Message Centre. Parents can send in the family conversation; they cannot impersonate a teacher in a teacher thread.

## Teacher boundaries
Teachers see only linked students whose parent has approved messaging. They can send and receive in their own student conversation, and approve classmate connections only when linked to both students. Teachers cannot read family or peer conversations.

## Database and server controls
- kids_teacher_contacts: parent-approved teacher access.
- kids_education_links: parent-authorised link between a family child and an Education student record; direct client writes are not granted.
- kids_adult_conversations / kids_adult_messages: private parent/teacher conversations.
- Existing kids_friendships / kids_messages: classmate conversations, now requiring parent and linked-teacher approval.
- Row Level Security and private helper functions enforce access; the Edge Function verifies caller identity before privileged parent and teacher actions.
- kids_messages_safe_content_only and kids_adult_messages_safe_content restrict payloads to text, stickers, or bounded drawing JSON.
- Report and remove-friend controls reuse the existing Kids safety tables and parent inbox.

## Entry points
- Child: Kids Zone → Kids Messages.
- Parent: Family Dashboard → Kids Messages Centre.
- Teacher: Education Dashboard → Kids Messages for linked students.

## First-use setup
1. Parent enables Kids Messages and sets the child's six-digit PIN in Family Dashboard.
2. Parent links the child's Education student record using the Student ID supplied by the teacher (if teacher messaging or classmate chats are wanted).
3. Teacher requests messaging permission from the Teacher Centre.
4. Parent approves the teacher.
5. Classmate connections still require both parents and a shared linked teacher to approve.

## QA limitations
Database migrations and the Kids Messaging Edge Function were deployed and checked. The authenticated multi-account workflow has not been exercised in a real iPhone Safari session. Test parent, child, and teacher accounts before using this with real children; in particular test link/unlink, contact revocation, both-family approval, teacher approval, and parent transcript access.
