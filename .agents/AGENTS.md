# Rules

- **Country & Language**: The target country is Kyrgyzstan (Кыргызстан). Do not confuse it with Kazakhstan.
- **Terminology**: Use Kyrgyz language terminology for local names (e.g. "Ашкана" instead of "Асхана").
- **Ecosystem Architecture & Isolation**:
  - We develop the kitchen/cafe app in `apps/kitchen`, which is independent of `apps/warehouse`.
  - Do NOT modify files in `packages/` in a way that breaks `apps/warehouse`.
  - Database schema changes in Supabase must remain backward compatible to ensure `apps/warehouse` is not broken.
