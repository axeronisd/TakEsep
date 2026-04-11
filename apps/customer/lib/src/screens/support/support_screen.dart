import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/akjol_theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// Support Screen — Поддержка Ак Жол
///
/// FAQ + контакты + быстрые действия
/// ═══════════════════════════════════════════════════════════════

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final mutedColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Поддержка'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3498DB).withValues(alpha: 0.12),
                  const Color(0xFF3498DB).withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF3498DB).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3498DB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.support_agent, color: Color(0xFF3498DB), size: 32),
                ),
                const SizedBox(height: 14),
                Text('Как мы можем помочь?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 6),
                Text(
                  'Ответим на вопросы о заказах,\nдоставке и работе приложения',
                  style: TextStyle(fontSize: 14, color: mutedColor, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Quick Actions ──
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.call_outlined,
                  label: 'Позвонить',
                  color: AkJolTheme.primary,
                  isDark: isDark,
                  onTap: () => _launch('tel:+996555000000'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.telegram,
                  label: 'Telegram',
                  color: const Color(0xFF0088CC),
                  isDark: isDark,
                  onTap: () => _launch('https://t.me/akjol_support'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  isDark: isDark,
                  onTap: () => _launch('https://wa.me/996555000000'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── FAQ ──
          Text('Частые вопросы',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 12),

          _FaqItem(
            question: 'Как оформить заказ?',
            answer: 'Выберите магазин, добавьте товары в корзину, укажите адрес доставки и нажмите «Оформить заказ».',
            isDark: isDark,
          ),
          _FaqItem(
            question: 'Сколько стоит доставка?',
            answer: 'Стоимость доставки зависит от расстояния и магазина. Обычно от 100 до 300 сом. Вы увидите точную стоимость при оформлении.',
            isDark: isDark,
          ),
          _FaqItem(
            question: 'Как отследить заказ?',
            answer: 'После оформления заказа вы можете отслеживать его статус в разделе "Заказы". Когда курьер заберёт заказ, вы увидите его на карте в реальном времени.',
            isDark: isDark,
          ),
          _FaqItem(
            question: 'Как отменить заказ?',
            answer: 'Вы можете отменить заказ пока он не был отправлен. Зайдите в детали заказа и нажмите «Отменить». Если заказ уже в пути — свяжитесь с поддержкой.',
            isDark: isDark,
          ),
          _FaqItem(
            question: 'Какие способы оплаты?',
            answer: 'Наличными курьеру при получении, а также банковской картой через приложение.',
            isDark: isDark,
          ),
          _FaqItem(
            question: 'Можно ли заказать на другой адрес?',
            answer: 'Да, при оформлении заказа вы можете указать любой адрес доставки в пределах города.',
            isDark: isDark,
          ),

          const SizedBox(height: 24),

          // ── Info ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule, color: mutedColor),
                  title: Text('Время работы', style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                  subtitle: Text('Пн-Вс: 08:00 – 23:00', style: TextStyle(color: mutedColor, fontSize: 13)),
                ),
                Divider(color: borderColor, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.email_outlined, color: mutedColor),
                  title: Text('Email', style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                  subtitle: Text('support@akjol.kg', style: TextStyle(color: mutedColor, fontSize: 13)),
                  onTap: () => _launch('mailto:support@akjol.kg'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _launch(String url) {
    try {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF374151),
            )),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;
  final bool isDark;

  const _FaqItem({
    required this.question,
    required this.answer,
    required this.isDark,
  });

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF111827);
    final mutedColor = widget.isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.question,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
            trailing: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _expanded ? 0.5 : 0,
              child: Icon(Icons.expand_more, color: mutedColor),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(widget.answer,
                  style: TextStyle(fontSize: 13, color: mutedColor, height: 1.5)),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
