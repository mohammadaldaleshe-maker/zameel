import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lets a person choose whether people who have their number are told when
/// they join Zameel. On by default; the choice is stored on the server.
class ContactJoinToggle165 extends StatefulWidget {
  const ContactJoinToggle165({super.key, required this.arabic});
  final bool arabic;

  @override
  State<ContactJoinToggle165> createState() => _ContactJoinToggle165State();
}

class _ContactJoinToggle165State extends State<ContactJoinToggle165> {
  bool _visible = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await Supabase.instance.client
          .rpc('zameel_get_contact_join_visible165');
      if (mounted) {
        setState(() {
          _visible = value != false;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _change(bool value) async {
    if (_saving) return;
    setState(() {
      _visible = value;
      _saving = true;
    });
    try {
      await Supabase.instance.client.rpc(
        'zameel_set_contact_join_visible165',
        params: <String, dynamic>{'p_visible': value},
      );
    } catch (_) {
      if (mounted) {
        setState(() => _visible = !value);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.arabic
                ? 'تعذر حفظ الإعداد. حاول مرة أخرى.'
                : 'Could not save the setting. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        key: const ValueKey('contactJoinVisibility165'),
        secondary: const Icon(Icons.person_add_alt_1_rounded),
        title: Text(widget.arabic
            ? 'إعلام معارفي بانضمامي'
            : 'Tell my contacts when I join'),
        subtitle: Text(widget.arabic
            ? 'يصل إشعار لمن يحتفظ برقمك عند تسجيلك في زميل'
            : 'People who saved your number get a notice when you sign up'),
        value: _visible,
        onChanged: _loaded && !_saving ? _change : null,
      ),
    );
  }
}
