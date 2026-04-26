import 'package:flutter/material.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _waSvg =
    '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
<path d="M12.031 0C5.398 0 0 5.398 0 12.031c0 2.126.549 4.195 1.594 6.015L.031 24l6.111-1.604A11.968 11.968 0 0 0 12.031 24c6.633 0 12.031-5.398 12.031-12.031S18.665 0 12.031 0zm0 22.016a9.964 9.964 0 0 1-5.093-1.391l-.364-.216-3.784.992.997-3.69-.236-.376C2.261 15.143 1.636 13.626 1.636 12.031c0-5.741 4.673-10.413 10.414-10.413 5.74 0 10.413 4.672 10.413 10.413s-4.673 10.413-10.414 10.413zm5.719-7.81c-.314-.157-1.859-.918-2.147-1.024-.288-.105-.497-.157-.707.157-.21.314-.811 1.024-.995 1.233-.183.21-.366.236-.68.079-1.371-.62-2.385-1.125-3.396-2.584-.262-.379.262-.351.865-1.564.08-.157.04-.288-.013-.445-.052-.157-.707-1.704-.969-2.333-.255-.612-.515-.529-.707-.539-.183-.008-.393-.01-.602-.01-.21 0-.55.079-.838.393-.288.314-1.1 1.075-1.1 2.621 0 1.546 1.126 3.039 1.283 3.249.157.21 2.213 3.379 5.358 4.736.75.32 1.334.508 1.789.65.753.238 1.438.204 1.979.124.606-.09 1.859-.76 2.121-1.494.262-.734.262-1.363.183-1.494-.079-.131-.288-.21-.602-.367z"/>
</svg>''';

const _instaSvg =
    '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
<path d="M12 2.16c3.2 0 3.58.01 4.85.07 1.17.05 1.8.25 2.22.41.56.22.96.48 1.38.9.42.42.68.82.9 1.38.16.42.36 1.05.41 2.22.06 1.27.07 1.65.07 4.85s-.01 3.58-.07 4.85c-.05 1.17-.25 1.8-.41 2.22-.22.56-.48.96-.9 1.38-.42.42-.82.68-1.38.9-.42.16-1.05.36-2.22.41-1.27.06-1.65.07-4.85.07s-3.58-.01-4.85-.07c-1.17-.05-1.8-.25-2.22-.41-.56-.22-.96-.48-1.38-.9-.42-.42-.68-.82-.9-1.38-.16-.42-.36-1.05-.41-2.22C2.17 15.58 2.16 15.2 2.16 12s.01-3.58.07-4.85c.05-1.17.25-1.8.41-2.22.22-.56.48-.96.9-1.38.42-.42.82-.68 1.38-.9.42-.16 1.05-.36 2.22-.41C8.42 2.17 8.8 2.16 12 2.16M12 0C8.74 0 8.33.01 7.05.07c-1.27.06-2.14.26-2.9.56-.78.3-1.44.75-2.1 1.41-.66.66-1.11 1.32-1.41 2.1-.3.76-.5 1.63-.56 2.9C.01 8.33 0 8.74 0 12s.01 3.67.07 4.95c.06 1.27.26 2.14.56 2.9.3.78.75 1.44 1.41 2.1.66.66 1.32 1.11 2.1 1.41.76.3 1.63.5 2.9.56C8.33 23.99 8.74 24 12 24s3.67-.01 4.95-.07c1.27-.06 2.14-.26 2.9-.56.78-.3 1.44-.75 2.1-1.41.66-.66 1.11-1.32 1.41-2.1.3-.76.5-1.63.56-2.9C23.99 15.67 24 15.26 24 12s-.01-3.67-.07-4.95c-.06-1.27-.26-2.14-.56-2.9-.3-.78-.75-1.44-1.41-2.1-.66-.66-1.32-1.11-2.1-1.41-.76-.3-1.63-.5-2.9-.56C15.67.01 15.26 0 12 0zm0 5.84A6.16 6.16 0 1 0 18.16 12 6.16 6.16 0 0 0 12 5.84zm0 10.16A4 4 0 1 1 16 12a4 4 0 0 1-4 4zm5.8-9.66a1.44 1.44 0 1 1-2.88 0 1.44 1.44 0 0 1 2.88 0z"/>
</svg>''';

class HelpArticle {
  final IconData icon;
  final String title;
  final String content;

  const HelpArticle({
    required this.icon,
    required this.title,
    required this.content,
  });
}

class HelpCategory {
  final String id;
  final String name;
  final IconData icon;
  final List<HelpArticle> articles;

  const HelpCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.articles,
  });
}

final _helpCategories = [
  const HelpCategory(
    id: 'start',
    name: 'Начало работы',
    icon: Icons.rocket_launch_rounded,
    articles: [
      HelpArticle(
        icon: Icons.login_rounded,
        title: 'Вход в систему и выбор склада',
        content: 'При первом запуске приложения вы увидите экран входа.\n\n'
            'Шаг 1: Имя пользователя\n'
            'Введите ваше имя. Это имя связывается с вашим PIN-кодом, выданным администратором или владельцем бизнеса.\n\n'
            'Шаг 2: PIN-код\n'
            'Введите секретный PIN-код (от 4 до 6 цифр). PIN-код строго индивидуален и является вашей электронно-цифровой подписью во всех операциях приложения (продажи, приход, т.д.).\n\n'
            'Шаг 3: Выбор склада\n'
            'После ввода правильного PIN-кода, система покажет список складов, к которым у вас есть доступ. Нажмите на нужный склад, чтобы начать смену.\n\n'
            'Чтобы сменить склад позже: откройте боковое меню слева (или нажмите на иконку гамбургера) → кликните на название склада в самом верху меню → выберите другой склад.',
      ),
      HelpArticle(
        icon: Icons.menu_open_rounded,
        title: 'Боковое меню навигации',
        content:
            'Основное меню для переходов между разделами спрятано слева. На компьютере оно открыто всегда, на телефоне — открывается специальной кнопкой.\n\n'
            'Что делает каждая кнопка в меню:\n'
            '• Главная (Дашборд) — обзор текущих финансовых показателей за день/месяц.\n'
            '• Касса (Продажа) — основной экран оформления покупок и пробития чеков.\n'
            '• Приход — для занесения новых поставок товаров от поставщиков на склад.\n'
            '• Перемещение — отправка или приём товаров с других точек (складов).\n'
            '• Ревизия — проведение инвентаризации остатков (сверка факта с программой).\n'
            '• Списание — списание испорченного, утерянного или просроченного товара.\n'
            '• Товары — справочник-каталог (добавление, редактирование, настройка цен).\n'
            '• Услуги — реестр оказываемых услуг (шиномонтаж, доставка и т.д.).\n'
            '• Клиенты — база контрагентов для ведения долгов и лояльности.\n'
            '• Отчёты — лента абсолютно всех операций по времени с фильтрацией.\n'
            '• Аналитика — графики и диаграммы прибыли, убытков и маржинальности.\n'
            '• Сотрудники — управление персоналом (зарплаты, доступы).\n'
            '• Настройки — внешний вид, чеки, валюта и способы оплаты.',
      ),
    ],
  ),
  const HelpCategory(
    id: 'sales',
    name: 'Касса и Продажи',
    icon: Icons.point_of_sale_rounded,
    articles: [
      HelpArticle(
        icon: Icons.shopping_basket_rounded,
        title: 'Как пробить корзину (Чек)',
        content:
            'Продажа товара — самый частый процесс в приложении. Разберем все кнопки.\n\n'
            '1. Как добавить товар:\n'
            '• Кликните на карточку товара в сетке/списке.\n'
            '• Либо отсканируйте штрихкод товара USB-сканером (товар сразу добавится).\n'
            '• Либо воспользуйтесь строкой "Поиск" (искать можно по имени или номеру штрихкода).\n\n'
            '2. Панель "Корзина":\n'
            'Товары скапливаются внизу экрана. Нажмите на надпись "Корзина", чтобы развернуть список.\n\n'
            '3. Редактирование в корзине:\n'
            '• Кнопки плюс и минус — меняют количество товара.\n'
            '• Иконка корзины — удаляет товар из чека.\n'
            '• Нажатие на сам товар внутри корзины открывает окно Скидки (на конкретный товар).\n\n'
            '4. Способы оплаты и завершение:\n'
            'Внизу корзины вы увидите кнопки способов оплаты: Наличные, Карта, Kaspi и т.д. (настраиваются в разделе "Настройки").\n'
            '• Если выбраны Наличные — появится калькулятор сдачи (введите сумму купюры клиента).\n'
            '• Нажмите зеленую кнопку "ОПЛАТИТЬ". Чек успешно пробит и остатки списаны со склада.',
      ),
      HelpArticle(
        icon: Icons.discount_rounded,
        title: 'Система скидок в чеке',
        content: 'Приложение поддерживает два уровня скидок.\n\n'
            '1. Скидка на весь чек (Глобальная):\n'
            'В панели корзины, рядом с итоговой суммой есть иконка "процента" или "ценника". Нажмите её.\n'
            'Всплывет окно: вы можете указать скидку просто суммой (например, скинуть 500 сом) либо процентом (скидка 10%).\n\n'
            '2. Скидка на конкретный товар (Товарная):\n'
            'Если скидка нужна только на один товар в чеке, нажмите прямо на строку этого товара внутри открытой Корзины. Вы также сможете указать процент или сомы.\n\n'
            'Внимание: Система не позволит сделать общую сумму корзины отрицательной.',
      ),
      HelpArticle(
        icon: Icons.receipt_long_rounded,
        title: 'Печать чека и QR-коды',
        content:
            'Сразу после нажатия кнопки "ОПЛАТИТЬ", система успешно закроет продажу и предложит напечатать чек (если устройство подключено к принтеру). \n\n'
            '• Чек содержит: дату, имя продавца, список покупок.\n'
            '• В "Настройках" вы можете скрыть имя компании, отключить адрес, или поменять текст "Спасибо за покупку!" в самом низу.\n\n'
            'Если клиент хочет оплатить через QR (Mbank, Kaspi, O!Деньги):\n'
            'В способах оплаты появится кнопка QR (и иконка). Если на эту кнопку нажать, на полный экран выведется заранее загруженный вами QR-код (его загружает владелец в Настройках). Клиент с телефона сканирует ваш экран и проводит оплату.',
      ),
    ],
  ),
  const HelpCategory(
    id: 'inventory',
    name: 'Справочник Товаров',
    icon: Icons.inventory_2_rounded,
    articles: [
      HelpArticle(
        icon: Icons.add_box_rounded,
        title: 'Как добавить и редактировать товар?',
        content:
            'Раздел «Товары» служит для создания карточек товаров и изменения цен.\n\n'
            'Добавление товара:\n'
            '• Товары автоматически добавляются, когда вы делаете первый "Приход".\n'
            '• Но также можно создать "пустую" карточку товара прямо в Справочнике, нажав верхнюю кнопку "Создать".\n\n'
            'Редактирование:\n'
            'Нажмите на любую карточку в списке. Откроется окно, где можно:\n'
            '• Изменить Имя (влияет на печать чека).\n'
            '• Добавить или изменить Штрихкод (отсканируйте новый штрихкод поверх старого).\n'
            '• Поменять Закупочную цену (себестоимость) — она пересчитается.\n'
            '• Поменять Цену продажи (РОЗНИЦА).\n'
            '• Установить лимиты (Минимальный и максимальный запас).\n\n'
            'В самом низу карточки показана текущая маржинальность в процентах (сколько вы зарабатываете чистыми с продажи 1 штуки).',
      ),
      HelpArticle(
        icon: Icons.color_lens_rounded,
        title: 'Цветовая индикация остатков',
        content:
            'Чтобы помочь Кладовщику вовремя дозаказывать товары, левая кромка карточки подсвечивается определенным цветом:\n\n'
            '• КРАСНЫЙ (Критично) — Товара почти нет на складе.\n'
            '• ЖЕЛТЫЙ (Мало) — Товар скоро закончится, пора звонить поставщику.\n'
            '• ЗЕЛЕНЫЙ (Норма) — Ситуация стабильная.\n'
            '• СИНИЙ (Избыток) — Перезатарка склада (слишком много товара).\n\n'
            'Эти цвета регулируются порогами "Мин. запас" и "Макс. запас", которые вы задаёте при редактировании товара.',
      ),
    ],
  ),
  const HelpCategory(
    id: 'operations',
    name: 'Приходы, Перемещения, Ревизия',
    icon: Icons.local_shipping_rounded,
    articles: [
      HelpArticle(
        icon: Icons.post_add_rounded,
        title: 'Оформление Прихода (Поступление)',
        content:
            'Кнопка "Приход" в меню нужна для приемки фур/коробок от поставщиков.\n\n'
            'Как сделать:\n'
            '1. Перейдите в Приход.\n'
            '2. Интерфейс похож на Кассу. Находите на витрине товары (или сканируете штрихкод с коробки).\n'
            '3. Товар падает вниз в "Накладную". Раскройте её.\n'
            '4. Укажите, сколько ШТУК приехало. Рядом увидите цену закупки.\n'
            '5. Можете добавить фотографию бумажной накладной.\n'
            '6. Нажмите "ПРОВЕСТИ ПРИХОД".\n\n'
            'Сразу после этого остаток соответствующих товаров на складе БЕЗВОЗВРАТНО увеличится!',
      ),
      HelpArticle(
        icon: Icons.swap_horiz_rounded,
        title: 'Перемещение на другой склад',
        content:
            'Если у вас сеть складов (или склад + магазин), вы можете отправлять товар между ними без потери финансовой истории.\n\n'
            'Вкладка "Новое":\n'
            '1. Выберите склад, куда поедет товар.\n'
            '2. Добавьте товары в "Фургон" (снизу).\n'
            '3. Важно: Выберите "Тип цен". По себестоимости (чтобы принимающий видел закупку) или По рознице (для отчетности).\n'
            '4. Кнопка "ОТПРАВИТЬ". Товар моментально спишется с вашего склада.\n\n'
            'Вкладка "Входящие":\n'
            'Здесь будет висеть красная точка, если на ВАШ склад кто-то отправил партию. Вы открываете накладную, пересчитываете товар и жмете "ПРИНЯТЬ". Только тогда товар зачислится к вам.',
      ),
      HelpArticle(
        icon: Icons.fact_check_rounded,
        title: 'Ревизия (Переучёт)',
        content:
            'Ревизию надо делать 1 раз в неделю/месяц, чтобы сверить программу с реальностью.\n\n'
            '1. Зайдите в Ревизию. Выберите "Полная" (все товары) или "Выборочная" (только 3-5 позиций).\n'
            '2. Перед вами список. В столбце "Программа" указано то, что сейчас думает компьютер.\n'
            '3. В столбец "Реальность" вам нужно вписать то, что вы руками насчитали на полках.\n'
            '4. Столбец "Разница" сразу покажет Недостачу (например, -2) или Избыток (+1).\n'
            '5. Жмем "ЗАВЕРШИТЬ РЕВИЗИЮ".\n\n'
            'Программа автоматически скорректирует свои остатки на те, что вы вбили в "Реальность".',
      ),
      HelpArticle(
        icon: Icons.delete_forever_rounded,
        title: 'Списание (Брак / Утеря)',
        content:
            'Списание — это процедура легального удаления товара из-за порчи.\n\n'
            '1. Зайдите в Списание. Выберите товары.\n'
            '2. Раскройте Акт списания (внизу экрана).\n'
            '3. Для каждого товара нужно указать "Причину": Брак / Утеря / Истек срок годности / Кража.\n'
            '4. Проведите списание.\n\n'
            'Система запомнит, на какую сумму себестоимости был списан товар, и добавит эту цифру в УБЫТКИ текущего месяца в Аналитике. Это поможет владельцу понимать протечки бюджета.',
      ),
    ],
  ),
  const HelpCategory(
    id: 'employees',
    name: 'Сотрудники и Зарплаты',
    icon: Icons.badge_rounded,
    articles: [
      HelpArticle(
        icon: Icons.person_add_rounded,
        title: 'Управление доступом (Роли и Ключи)',
        content:
            'Только Владелец (и те, кому дали доступ) могут заходить в раздел "Сотрудники".\n\n'
            'Сотрудники авторизуются через PIN-код. Никаких e-mail и паролей вбивать в кассе не нужно.\n\n'
            'Редактирование Сотрудника:\n'
            '• Имя: Будет печататься на чеке.\n'
            '• Ключ/PIN: 4-6 цифр (генерируется кнопкой с кубиками).\n'
            '• Роль: В соседней вкладке "Роли" вы можете создать роль (например, "Продавец") и убрать у неё галочки "Разрешить Приход", "Разрешить Списание", "Разрешить Настройки". И назначить эту роль сотруднику. Тогда он физически не увидит эти разделы меню.\n'
            '• Склады: Вы можете запретить продавцу заходить на "Центральный склад", оставив доступ только к "Магазин 1".',
      ),
      HelpArticle(
        icon: Icons.attach_money_rounded,
        title: 'Настройка Зарплат',
        content: 'В карточке сотрудника есть вкладка "Зарплата".\n\n'
            'Типы зарплат:\n'
            '• Фиксированная в Месяц/День/Смену.\n'
            '• Процент от ПРОДАЖ (Оклад).\n'
            '• Почасовая.\n\n'
            'Учет Расходов (Авансы):\n'
            'Внизу экрана Сотрудника есть блок Расходов на сотрудника. Если вы выдали ему 1000 сом на обед или Аванс — добавьте туда этот расход. Система вычтет эти деньги из Чистой Прибыли склада.',
      ),
    ],
  ),
  const HelpCategory(
    id: 'reports',
    name: 'Отчёты и Аналитика',
    icon: Icons.insert_chart_outlined_rounded,
    articles: [
      HelpArticle(
        icon: Icons.history_rounded,
        title: 'Журнал Отчётов (Лента событий)',
        content: 'В любой непонятной ситуации — открывайте раздел "Отчёты".\n\n'
            'Там хранится железобетонная лента ВСЕХ событий, кто и когда что нажал.\n'
            '• Кто-то удалил товар из чека? Он там будет.\n'
            '• Кладовщик Асанов провел списание 5 бананов? Будет строчка "Списание", время, дата.\n\n'
            'Кнопки сверху — Фильтры. Вы можете нажать кнопку "Продажи", затем выбрать в выпадающем списке конкретного сотрудника "Иван", и нажать кнопку "Экспорт в CSV". Приложение скачает Excel файл (CSV) со всеми нужными продажами Ивана за этот месяц.',
      ),
      HelpArticle(
        icon: Icons.ssid_chart_rounded,
        title: 'Дашборд и Главная (KPI)',
        content:
            'Самая первая страница приложения (Дашборд) предназначена для владельца.\n\n'
            'Здесь показан пульс бизнеса за выбранный период:\n'
            '• Выручка — все грязные поступившие деньги.\n'
            '• Прибыль (Маржа) — Выручка МИНУС Себестоимость проданных товаров.\n'
            '• Топ товаров — хит-парад самых проданных позиций (можно посмотреть, что тащит бизнес вверх).\n'
            '• Диаграмма расходов — куда утекли деньги (Авансы, браки, обеды).\n\n'
            'Графики интерактивны — если навести курсором (или нажать пальцем), появятся конкретные цифры за конкретный день.',
      ),
    ],
  ),
  const HelpCategory(
    id: 'settings',
    name: 'Настройки Системы',
    icon: Icons.settings_rounded,
    articles: [
      HelpArticle(
        icon: Icons.color_lens_rounded,
        title: 'Внешний вид и Тема',
        content: 'В Настройках вы можете включить Светлую или Тёмную тему.\n\n'
            'Важный момент: тема запоминается ЛОКАЛЬНО для каждого отдельного сотрудника. Если кассир А любит тёмную тему, а кассир Б светлую (работая за одним и тем же планшетом) — приложение само переключит тему в момент, когда кассир введет свой PIN.',
      ),
      HelpArticle(
        icon: Icons.qr_code_2_rounded,
        title: 'Настройка Кастомных Платёжных систем (QR)',
        content:
            'В Настройках → "Способы Оплаты" вы можете добавлять свои системы (Например Kaspi, MegaPay, O!Деньги).\n\n'
            '1. Нажмите "Новый способ оплаты".\n'
            '2. Введите название (например, Mbank).\n'
            '3. Самое главное: вы можете нажать "Загрузить фото", и прикрепить картинку своего личного QR-кода от Mbank.\n'
            '4. Сохраните.\n\n'
            'Теперь в Кассе (корзине продаж) появится кнопка Mbank. И если на неё нажать, кассиру в один клик откроется ваш QR на весь экран, готовый к сканированию покупателем!',
      ),
      HelpArticle(
        icon: Icons.currency_exchange_rounded,
        title: 'Курс валют',
        content:
            'В разделе "Валюта" можно переключить отображение символа сомов, рублей или долларов.\n'
            'Также там встроен живой модуль НацБанка КР (НБ КР). Он каждый день через интернет автоматически скачивает курс валют на сегодня. Работает как справочник-конвертер.',
      ),
    ],
  ),
];

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _selectedCategoryId = 'start';
  String _searchQuery = '';

  List<HelpArticle> get _filteredArticles {
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      return _helpCategories
          .expand((c) => c.articles)
          .where((a) =>
              a.title.toLowerCase().contains(q) ||
              a.content.toLowerCase().contains(q))
          .toList();
    }
    return _helpCategories
        .firstWhere((c) => c.id == _selectedCategoryId)
        .articles;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Центр Помощи',
                  style:
                      AppTypography.displaySmall.copyWith(color: cs.onSurface)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                  '${_helpCategories.length} категорий · ${_helpCategories.expand((c) => c.articles).length} подробных статей',
                  style: AppTypography.bodyMedium
                      .copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: AppSpacing.lg),

              // Search
              SizedBox(
                height: 48,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText:
                        'Поиск (например: как списать брак, qr код, зарплата)...',
                    hintStyle: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4),
                        fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline)),
                  ),
                  style: TextStyle(color: cs.onSurface, fontSize: 14),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: isDesktop
                    ? _buildDesktopLayout(cs)
                    : _buildMobileLayout(cs),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Разделы инструкций',
                  style: AppTypography.headlineSmall
                      .copyWith(color: cs.onSurface)),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView(
                  children: _helpCategories
                      .map((c) => _buildCategoryTab(c, cs))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _buildSupportCard(cs, isMobile: false),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xxl),
        Expanded(child: _buildContentArea(cs, isMobile: false)),
      ],
    );
  }

  Widget _buildMobileLayout(ColorScheme cs) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _helpCategories
                .map((c) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _buildCategoryTab(c, cs, isHorizontal: true),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          // Important: We pass isMobile=true to append the Support Card inside the content scroll area
          child: _buildContentArea(cs, isMobile: true),
        ),
      ],
    );
  }

  Widget _buildCategoryTab(HelpCategory category, ColorScheme cs,
      {bool isHorizontal = false}) {
    final isSelected = category.id == _selectedCategoryId;
    return InkWell(
      onTap: () => setState(() {
        _selectedCategoryId = category.id;
        _searchQuery = '';
      }),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: isHorizontal ? AppSpacing.sm : 12,
        ),
        margin: EdgeInsets.only(bottom: isHorizontal ? 0 : AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          mainAxisSize: isHorizontal ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(category.icon,
                color: isSelected
                    ? AppColors.primary
                    : cs.onSurface.withValues(alpha: 0.7),
                size: 20),
            const SizedBox(width: AppSpacing.md),
            Text(
              category.name,
              style: AppTypography.bodyLarge.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : cs.onSurface.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea(ColorScheme cs, {required bool isMobile}) {
    final articles = _filteredArticles;
    final title = _searchQuery.isNotEmpty
        ? 'Результаты поиска (${articles.length})'
        : _helpCategories.firstWhere((c) => c.id == _selectedCategoryId).name;

    return ListView(
      children: [
        Text(title,
            style: AppTypography.headlineMedium.copyWith(color: cs.onSurface)),
        const SizedBox(height: AppSpacing.lg),
        if (articles.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(children: [
                Icon(Icons.search_off_rounded,
                    size: 56, color: cs.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: AppSpacing.md),
                Text('Ничего не найдено. Попробуйте другой запрос.',
                    style: AppTypography.bodyLarge
                        .copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
              ]),
            ),
          )
        else
          for (final article in articles) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(article.icon,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        article.title,
                        style: AppTypography.bodyLarge.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    article.content,
                    style: AppTypography.bodyMedium.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.8),
                      height: 1.6,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],

        // On mobile, append the support card to the bottom of the scrollable content
        if (isMobile) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildSupportCard(cs, isMobile: true),
          const SizedBox(height: AppSpacing.xxl), // Extra bottom padding
        ],
      ],
    );
  }

  Widget _buildSupportCard(ColorScheme cs, {required bool isMobile}) {
    final supportDetails = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.support_agent_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Связаться с разработчиками',
                  style: AppTypography.bodySmall
                      .copyWith(color: Colors.white.withValues(alpha: 0.8))),
              Text('Служба поддержки\n+996 506 384 666',
                  style: AppTypography.bodyLarge.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );

    final whatsappButton = FilledButton.icon(
      onPressed: () async {
        final uri = Uri.parse('https://wa.me/996506384666');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      icon: SvgPicture.string(_waSvg,
          width: 22,
          height: 22,
          colorFilter: ColorFilter.mode(Color(0xFF25D366), BlendMode.srcIn)),
      label: Text('WhatsApp',
          style: TextStyle(
              color: Color(0xFF25D366),
              fontSize: 15,
              fontWeight: FontWeight.bold)),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final instaButton = FilledButton.icon(
      onPressed: () async {
        final uri = Uri.parse(
            'https://www.instagram.com/takesep?igsh=bmR6NHZxdW85bGRr&utm_source=qr');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      icon: SvgPicture.string(_instaSvg, width: 22, height: 22),
      label: const Text('Instagram',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          supportDetails,
          const SizedBox(height: AppSpacing.xl),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                whatsappButton,
                const SizedBox(height: AppSpacing.md),
                instaButton,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: whatsappButton),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: instaButton),
              ],
            ),
        ],
      ),
    );
  }
}
