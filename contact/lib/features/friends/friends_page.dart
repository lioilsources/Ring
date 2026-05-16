import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../shared/supabase_client.dart';
import 'invite_service.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final rows = await supabase
        .from('friendships')
        .select('*, user_a:users!user_a(id, name, avatar_url), user_b:users!user_b(id, name, avatar_url)')
        .or('user_a.eq.$userId,user_b.eq.$userId')
        .eq('status', 'accepted');

    setState(() {
      _friends = rows.map((r) {
        final isA = r['user_a']['id'] == userId;
        return isA ? r['user_b'] as Map<String, dynamic> : r['user_a'] as Map<String, dynamic>;
      }).toList();
      _loading = false;
    });
  }

  Future<void> _invite() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final link = await InviteService.createInviteLink(userId);
    await Clipboard.setData(ClipboardData(text: 'https://$link'));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link zkopírován do schránky')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Přátelé', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.link, color: Colors.white70),
            tooltip: 'Pozvat hráče',
            onPressed: _invite,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? const Center(
                  child: Text(
                    'Zatím žádní přátelé.\nPošli pozvánku!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: _friends.length,
                  itemBuilder: (context, i) {
                    final f = _friends[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: f['avatar_url'] != null
                            ? NetworkImage(f['avatar_url'] as String)
                            : null,
                        backgroundColor: const Color(0xFF1E1E2E),
                        child: f['avatar_url'] == null
                            ? Text(
                                (f['name'] as String).substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      title: Text(
                        f['name'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => context.push('/lobby', extra: {
                        'friendId': f['id'],
                        'isHost': true,
                      }),
                    );
                  },
                ),
    );
  }
}
