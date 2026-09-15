# Zameel 051

Corrective release based on the approved 049 visual identity.

- Restores the royal-blue/indigo visual system and existing gradients.
- Keeps contextual white text on dark colored surfaces and dark text on light surfaces.
- Shows the English `Zameel` home title in the official primary color.
- Removes white blocks behind stories and public clips without flattening the app identity.
- Uses portrait public clip cards.
- Shows the media publisher below full-screen photos and videos with profile navigation.
- Sends direct messages through a server-confirmed RPC, with a temporary compatible fallback.
- Reconciles the conversation from persistent storage after every successful send.

Apply `supabase/migrations/051_restore_brand_and_reliable_chat.sql` before
testing chat on two real accounts.
