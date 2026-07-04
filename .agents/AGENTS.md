# Rules

- **Country & Language**: The target country is Kyrgyzstan (Кыргызстан). Do not confuse it with Kazakhstan.
- **Terminology**: Use Kyrgyz language terminology for local names (e.g. "Ашкана" instead of "Асхана").
- **Ecosystem Architecture & Isolation**:
  - We develop the kitchen/cafe app in `apps/kitchen`, which is independent of `apps/warehouse`.
  - Do NOT modify files in `packages/` in a way that breaks `apps/warehouse`.
  - Database schema changes in Supabase must remain backward compatible to ensure `apps/warehouse` is not broken.
  - For kitchen/cafe features, we must create completely separate, new tables in Supabase (e.g., prefixing them with `kitchen_` or using new standalone models). We do NOT modify, reuse, or break existing schemas (such as `sales`, `products`, `stocks`, etc.) that are used by `apps/warehouse`.
- **Page Access Control & Roles**: Waiter/sales screen (`apps/kitchen/lib/src/screens/sales/sales_screen.dart`) should never show administrative or layout configuration screens/buttons, as access to pages is determined strictly by roles/permissions. Do not add shortcuts to designer canvas or settings pages on screens meant for waiters.

