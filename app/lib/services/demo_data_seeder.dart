// Generated Demo Data Seeder for WorkChat UI testing
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/attachment.dart';
import '../models/user.dart';

class DemoDataSeeder {
  static List<User> getUsers(String currentUserId, String currentUserName) {
    return [
      User(id: currentUserId, username: currentUserName.toLowerCase(), displayName: currentUserName, role: 'admin'),
      User(id: 'u_alice', username: 'alice', displayName: 'Alice Walker', role: 'member'),
      User(id: 'u_bob', username: 'bob', displayName: 'Bob Chen', role: 'member'),
      User(id: 'u_clara', username: 'clara', displayName: 'Clara Oswald', role: 'member'),
      User(id: 'u_david', username: 'david', displayName: 'David Miller', role: 'member'),
      User(id: 'u_elena', username: 'elena', displayName: 'Elena Rostova', role: 'member'),
      User(id: 'u_frank', username: 'frank', displayName: 'Frank Zhang', role: 'member'),
      User(id: 'u_grace', username: 'grace', displayName: 'Grace Hopper', role: 'member'),
      User(id: 'u_henry', username: 'henry', displayName: 'Henry Ford', role: 'member'),
      User(id: 'u_isabella', username: 'isabella', displayName: 'Isabella Rossi', role: 'member'),
      User(id: 'u_jack', username: 'jack', displayName: 'Jack Ryan', role: 'member'),
    ];
  }

  static List<Conversation> getConversations(String currentUserId) {
    return [
      Conversation(
        id: 'c_gen',
        kind: 'channel',
        name: 'general',
        topic: 'Company-wide announcements & general discussions 🌍',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
        isPinned: true,
        pinOrder: 0,
      ),
      Conversation(
        id: 'c_ann',
        kind: 'channel',
        name: 'announcements',
        topic: 'Official workplace updates and release bulletins 📢',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
        isPinned: true,
        pinOrder: 1,
      ),
      Conversation(
        id: 'c_eng',
        kind: 'channel',
        name: 'engineering',
        topic: 'Software architecture, backend, frontend, code reviews 🛠️',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_ds',
        kind: 'channel',
        name: 'design-system',
        topic: 'UI/UX patterns, Figma components, token guidelines 🎨',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_pm',
        kind: 'channel',
        name: 'product-roadmap',
        topic: 'Quarterly priorities, user stories, feature requests 🗺️',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_rel',
        kind: 'channel',
        name: 'releases',
        topic: 'Deployment notifications, changelogs, build tags 🚀',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_rnd',
        kind: 'channel',
        name: 'random',
        topic: 'Casual banter, weekend plans, funny memes & coffee ☕',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_ops',
        kind: 'channel',
        name: 'devops-infra',
        topic: 'Kubernetes, Docker containers, server health & CI/CD 🐳',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_mob',
        kind: 'channel',
        name: 'mobile-app',
        topic: 'Flutter client, Android APKs, iOS builds, animations 📱',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_sec',
        kind: 'channel',
        name: 'security-audit',
        topic: 'Vulnerability assessments, penetration testing, compliance 🔒',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_fb',
        kind: 'channel',
        name: 'customer-feedback',
        topic: 'User bug reports, praise, enterprise feature inquiries 💬',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_mkt',
        kind: 'channel',
        name: 'marketing-growth',
        topic: 'Campaign analytics, community expansion, social posts 📊',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_ai',
        kind: 'channel',
        name: 'ai-experiments',
        topic: 'Local LLMs, embeddings, bot integrations, workflows 🤖',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_back',
        kind: 'channel',
        name: 'backend-architecture',
        topic: 'Go SQLite WAL engine, WebSocket scalability, FTS5 ⚡',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_cof',
        kind: 'channel',
        name: 'coffee-break',
        topic: 'Virtual watercooler, favorite brews, lunch spots 🥐',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_mus',
        kind: 'channel',
        name: 'music-and-vibes',
        topic: 'Coding playlists, synthwave recommendations, lo-fi tracks 🎧',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_qa',
        kind: 'channel',
        name: 'qa-bugs',
        topic: 'Regression test results, edge-case tracking, issue repros 🐛',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_game',
        kind: 'channel',
        name: 'gaming-hub',
        topic: 'Team multiplayer sessions, game nights, chess tournaments 🎮',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_sales',
        kind: 'channel',
        name: 'sales-pipeline',
        topic: 'Enterprise deals, client onboarding, revenue milestones 💼',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'c_met',
        kind: 'channel',
        name: 'server-metrics',
        topic: 'Live resource dashboards: CPU < 1%, RAM < 35 MB 📈',
        createdMs: 1731236000000,
        lastSeq: 35,
        lastTs: 1732099940000,
        unreadCount: 2,
      ),
      Conversation(
        id: 'dm_u_alice',
        kind: 'dm',
        name: 'Alice Walker',
        topic: 'Senior Product Designer 🎨',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'dm_u_bob',
        kind: 'dm',
        name: 'Bob Chen',
        topic: 'Lead Infrastructure Engineer ⚙️',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'dm_u_clara',
        kind: 'dm',
        name: 'Clara Oswald',
        topic: 'Security Lead 🛡️',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'dm_u_david',
        kind: 'dm',
        name: 'David Miller',
        topic: 'VP of Engineering 🚀',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'dm_u_elena',
        kind: 'dm',
        name: 'Elena Rostova',
        topic: 'Mobile Architect 📱',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'dm_u_frank',
        kind: 'dm',
        name: 'Frank Zhang',
        topic: 'QA Automation Specialist 🧪',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'dm_u_grace',
        kind: 'dm',
        name: 'Grace Hopper',
        topic: 'Core Systems Dev 💻',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'dm_u_henry',
        kind: 'dm',
        name: 'Henry Ford',
        topic: 'Operations Manager 📊',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'dm_u_isabella',
        kind: 'dm',
        name: 'Isabella Rossi',
        topic: 'Marketing Lead 📈',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'dm_u_jack',
        kind: 'dm',
        name: 'Jack Ryan',
        topic: 'DevOps Engineer 🐳',
        createdMs: 1731236000000,
        lastSeq: 32,
        lastTs: 1732099880000,
        unreadCount: 1,
      ),
      Conversation(
        id: 'g_core',
        kind: 'group_dm',
        name: 'Core Platform Team',
        topic: 'Architectural leadership & core engine developers 🏛️',
        createdMs: 1731236000000,
        lastSeq: 34,
        lastTs: 1732099820000,
        unreadCount: 3,
      ),
      Conversation(
        id: 'g_mobile',
        kind: 'group_dm',
        name: 'Mobile UI/UX Guild',
        topic: 'Flutter engineers and design leads 🌟',
        createdMs: 1731236000000,
        lastSeq: 34,
        lastTs: 1732099820000,
        unreadCount: 3,
      ),
      Conversation(
        id: 'g_hack',
        kind: 'group_dm',
        name: 'Weekend Hackathon 2026',
        topic: 'Rapid prototyping and experimental bots ⚡',
        createdMs: 1731236000000,
        lastSeq: 34,
        lastTs: 1732099820000,
        unreadCount: 3,
      ),
      Conversation(
        id: 'g_sec',
        kind: 'group_dm',
        name: 'Security Strike Force',
        topic: 'Zero-trust hardening and audit triage 🛡️',
        createdMs: 1731236000000,
        lastSeq: 34,
        lastTs: 1732099820000,
        unreadCount: 3,
      ),
      Conversation(
        id: 'g_launch',
        kind: 'group_dm',
        name: 'WorkChat Launch Taskforce',
        topic: 'Cross-functional go-to-market squad 🎯',
        createdMs: 1731236000000,
        lastSeq: 34,
        lastTs: 1732099820000,
        unreadCount: 3,
      ),
    ];
  }

  static Map<String, List<Message>> getMessages(String currentUserId) {
    final Map<String, List<Message>> map = {};

    final allConvs = getConversations(currentUserId);
    for (final c in allConvs) {
      final List<Message> list = [];
      final baseTs = DateTime.now().millisecondsSinceEpoch - (32 * 180000);

      for (int i = 0; i < 32; i++) {
        final seq = i + 1;
        final ts = baseTs + (i * 180000);
        final isMe = (i % 3 == 0);
        final senderId = isMe ? currentUserId : 'u_alice';
        
        List<Attachment> atts = [];
        // Attach files to specific message indexes
        if (i == 2) {
          atts = [Attachment(id: 'att_img1', uploaderId: 'u_alice', name: 'architecture_overview.png', contentType: 'image/png', size: 245800, sha256: 'a1b2c3', createdMs: ts)];
        } else if (i == 5) {
          atts = [Attachment(id: 'att_docx', uploaderId: 'u_bob', name: 'Q4_Project_Scope_and_Objectives.docx', contentType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', size: 125400, sha256: 'd4e5f6', createdMs: ts)];
        } else if (i == 12) {
          atts = [Attachment(id: 'att_xlsx', uploaderId: 'u_david', name: 'Team_Resource_Allocation_and_Budget.xlsx', contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', size: 98300, sha256: 'g7h8i9', createdMs: ts)];
        } else if (i == 13) {
          atts = [Attachment(id: 'att_vid', uploaderId: 'u_elena', name: 'demo_preview.mp4', contentType: 'video/mp4', size: 52400, sha256: 'j1k2l3', createdMs: ts)];
        } else if (i == 14) {
          atts = [Attachment(id: 'att_img2', uploaderId: 'u_alice', name: 'team_photo.jpg', contentType: 'image/jpeg', size: 182300, sha256: 'm4n5o6', createdMs: ts)];
        } else if (i == 23) {
          atts = [Attachment(id: 'att_pdf', uploaderId: 'u_clara', name: 'WorkChat_Architecture_Whitepaper.pdf', contentType: 'application/pdf', size: 450120, sha256: 'p7q8r9', createdMs: ts)];
        }

        final reactions = [
          if (i % 2 == 0) Reaction(emoji: '🔥', userId: 'u_bob'),
          if (i % 3 == 0) Reaction(emoji: '🚀', userId: 'u_alice'),
          if (i % 4 == 0) Reaction(emoji: '👍', userId: 'u_david'),
          if (i % 5 == 0) Reaction(emoji: '❤️', userId: 'u_clara'),
        ];

        final isThreadRoot = (i == 1 || i == 6 || i == 15);
        final replyCount = isThreadRoot ? 4 : 0;

        final body = _getSampleText(i, c.name ?? 'chat');

        final labels = <String>[
          if (i == 1) ...['Important', 'Action Item'],
          if (i == 4) 'Important',
          if (i == 8) 'Reference',
          if (i == 15) 'Idea',
          if (i == 20) 'Follow Up',
        ];

        list.insert(0, Message(
          id: '${c.id}_msg_$seq',
          convId: c.id,
          seq: seq,
          senderId: senderId,
          body: body,
          ts: ts,
          attachments: atts,
          reactions: reactions,
          replyCount: replyCount,
          lastReplyAt: isThreadRoot ? ts + 60000 : null,
          labels: labels,
          isSaved: (i == 1 || i == 15),
        ));
      }
      map[c.id] = list;
    }
    return map;
  }

  static String _getSampleText(int index, String chatName) {
    switch (index) {
      case 0: return 'Welcome to **$chatName**! 🚀 Let us know if you need anything.';
      case 1: return 'Did you check the new benchmarks? **Under 35MB RAM** on idle Go SQLite WAL! ⚡\n\n- Zero CPU spin\n- Monotonic seq_id delta sync\n- Pure Go without CGO';
      case 2: return 'Here is the updated architecture diagram for review: 👇';
      case 3: return 'Great progress! The mobile client idle memory is sitting right around `45 MB` on Android arm64! 📱';
      case 4: return 'Please verify the latest release notes:\n1. Fixed adaptive icons\n2. Added Slack-style formatting toolbar\n3. Delta sync support 🎉';
      case 5: return 'I have attached the quarterly project scope and objectives document: 📄';
      case 6: return 'Can we review the thread on push notification relays? Self-hosted `ntfy` on Docker vs FCM/APNs. 💡';
      case 7: return 'Looks solid! 👍 Everything is running smoothly.';
      case 8: return '```go\nfunc HandleMessage(w http.ResponseWriter, r *http.Request) {\n    // Monotonic seq_id delta sync\n    db.Exec("PRAGMA journal_mode = WAL;")\n}\n```';
      case 9: return 'Coffee time 🥐 Who wants an espresso? Meet in the pantry!';
      case 10: return 'Don\'t forget to test hidden chats with PIN protection! 🔒 Notifications are masked automatically.';
      case 11: return 'Local contact avatar overrides are working 100% offline in local SQLite! ✨ Customize any peer avatar locally.';
      case 12: return 'Here is the team budget and resource allocation spreadsheet for Q4: 📊';
      case 13: return 'Video walkthrough of the new adaptive 3-pane layout attached below! Tap to play: 🎥';
      case 14: return 'Check out our team offsite snapshot from last week: 📸';
      case 15: return 'Has anyone tested the dark OLED theme on Samsung AMOLED screens? High-contrast slate navy with zero purple hues! 🖤';
      case 16: return 'Merged PR #42: Added CommonMark markdown rendering without heavy WebViews! 📝';
      case 17: return 'All universal file extensions (*PDF, DOCX, XLSX, MP4, PNG*) open directly in the OS default viewer. 📂';
      case 18: return 'Sprint retrospectives start in 10 minutes in the main voice room. ⏰';
      case 19: return 'What a milestone! **WorkChat v1.1** is ready for production rollout. 🏆';
      case 20: return 'Reactions counter tested: multiple users can react with Telegram-style emojis 🔥🚀❤️👍';
      case 21: return 'Quick question: should we enable biometric unlock (*FaceID / Fingerprint*) by default? 👆';
      case 22: return 'Confirmed: SQLite in WAL mode has zero lock contention under 100 concurrent users. 🛡️';
      case 23: return 'Here is the complete WorkChat architecture whitepaper: 📑';
      case 24: return 'Let me know if anyone notices any UI alignment issues on small Android screens! 📲';
      case 25: return 'The Slack-style formatting toolbar makes typing **bold**, *italic*, bullet lists, and code blocks effortless. ⌨️';
      case 26: return 'Everything is passing CI: 0 issues on flutter analyze, 100% tests passing! 💚';
      case 27: return 'Don\'t forget to check out the repo on GitHub! ⭐';
      case 28: return 'Awesome work everyone! Let us wrap up today\'s milestones. 🥂';
      case 29: return 'Final check before release: all APK splits (*arm64-v8a, armeabi-v7a, x86_64*) verified! 📦';
      case 30: return 'Ready for testing on physical devices! 🚀 Enjoy testing WorkChat v1.1 on your Android phone!';
      case 31: return 'Latest updates are live! Tap on any chat, message thread, reaction, or attachment to test. 🎯';
      default: return 'Chat message #$index in $chatName 👍';
    }
  }
}
