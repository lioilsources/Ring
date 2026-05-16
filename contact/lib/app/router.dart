import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/auth/auth_page.dart';
import '../features/friends/friends_page.dart';
import '../features/lobby/lobby_page.dart';
import '../features/game/game_page.dart';
import '../features/game/game_bloc.dart';
import '../shared/supabase_client.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = supabase.auth.currentSession;
    final onAuth = state.matchedLocation == '/auth';
    if (session == null && !onAuth) return '/auth';
    if (session != null && onAuth) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/auth',
      builder: (_, _) => const AuthPage(),
    ),
    GoRoute(
      path: '/',
      builder: (_, _) => const FriendsPage(),
    ),
    GoRoute(
      path: '/lobby',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BlocProvider(
          create: (_) => GameBloc(),
          child: LobbyPage(
            roomId: extra['roomId'] as String,
            isHost: extra['isHost'] as bool,
          ),
        );
      },
    ),
    GoRoute(
      path: '/game',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return GamePage(
          roomId: extra['roomId'] as String,
          isHost: extra['isHost'] as bool,
        );
      },
    ),
    // Deep link: contact.ol1n.com/invite/{token}
    GoRoute(
      path: '/invite/:token',
      builder: (context, state) {
        final token = state.pathParameters['token']!;
        return _InviteRedirectPage(token: token);
      },
    ),
  ],
);

// Zpracuje invite token a přesměruje do lobby
class _InviteRedirectPage extends StatefulWidget {
  final String token;
  const _InviteRedirectPage({required this.token});

  @override
  State<_InviteRedirectPage> createState() => _InviteRedirectPageState();
}

class _InviteRedirectPageState extends State<_InviteRedirectPage> {
  @override
  void initState() {
    super.initState();
    _redeem();
  }

  Future<void> _redeem() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      context.go('/auth');
      return;
    }

    final row = await supabase
        .from('invites')
        .select('room_id, expires_at, used')
        .eq('token', widget.token)
        .maybeSingle();

    if (!mounted) return;

    if (row == null || row['used'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pozvánka je neplatná nebo již použitá.')),
      );
      context.go('/');
      return;
    }

    await supabase.from('invites').update({'used': true}).eq('token', widget.token);
    await supabase
        .from('rooms')
        .update({'guest_id': userId})
        .eq('id', row['room_id']);

    if (!mounted) return;
    context.go('/lobby', extra: {'roomId': row['room_id'], 'isHost': false});
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0F),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
