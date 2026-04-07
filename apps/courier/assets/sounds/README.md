# Audio Assets

Place notification sounds here:
- `new_order.mp3` — Alert when new order arrives (recommended: 1-2 second chime)
- `delivered.mp3` — Delivery complete celebration sound

The app currently uses CDN fallback URLs. When these files are added,
update `OrderAlertService` to use `AssetSource('sounds/new_order.mp3')`.
