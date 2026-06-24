import 'dart:math';

/// Тип задачи в маршруте
enum RouteTaskType {
  pickup,   // Забрать из магазина
  dropoff,  // Доставить клиенту
}

/// Точка маршрута (Задача)
class RouteTask {
  final RouteTaskType type;
  final String orderId;
  final Map<String, dynamic> order;
  final double lat;
  final double lng;
  
  // Дополнительные данные для UI
  final String title;
  final String subtitle;
  final String address;

  RouteTask({
    required this.type,
    required this.orderId,
    required this.order,
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
    required this.address,
  });

  /// Дистанция в метрах от других координат (по прямой)
  double distanceTo(double otherLat, double otherLng) {
    const double earthRadius = 6371000; // метры
    final dLat = _degreesToRadians(otherLat - lat);
    final dLng = _degreesToRadians(otherLng - lng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat)) *
            cos(_degreesToRadians(otherLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}

class RouteOptimizer {
  /// Строит оптимальный маршрут (TSP с приоритетами)
  static List<RouteTask> buildOptimalRoute(
    double currentLat,
    double currentLng,
    List<Map<String, dynamic>> activeOrders,
  ) {
    if (activeOrders.isEmpty) return [];

    final List<RouteTask> allTasks = [];
    final Map<String, bool> orderPickedUp = {};

    // 1. Формируем все потенциальные задачи
    for (final order in activeOrders) {
      final status = order['status'];
      final isPickedUp = status == 'picked_up' || status == 'arrived';
      orderPickedUp[order['id']] = isPickedUp;

      // Если еще не забрали — добавляем задачу Pickup
      if (!isPickedUp) {
        final wh = order['warehouses'];
        final isFreelance = order['delivery_type'] == 'freelance' && (order['items_total'] as num?)?.toDouble() == 0;
        final pickupName = isFreelance ? 'Откуда (Клиент)' : (wh?['name'] ?? 'Магазин');
        final pickupAddr = isFreelance ? (order['pickup_address'] ?? '') : (wh?['address'] ?? '');
        allTasks.add(RouteTask(
          type: RouteTaskType.pickup,
          orderId: order['id'],
          order: order,
          lat: (order['pickup_lat'] as num?)?.toDouble() ?? (wh?['latitude'] as num?)?.toDouble() ?? 0,
          lng: (order['pickup_lng'] as num?)?.toDouble() ?? (wh?['longitude'] as num?)?.toDouble() ?? 0,
          title: 'Забрать заказ: $pickupName',
          subtitle: 'Заказ #${order['id'].toString().substring(0, 5)}',
          address: pickupAddr,
        ));
      }

      // Задачу Dropoff добавляем всегда
      final cust = order['customers'];
      allTasks.add(RouteTask(
        type: RouteTaskType.dropoff,
        orderId: order['id'],
        order: order,
        lat: (cust?['latitude'] as num?)?.toDouble() ?? (order['delivery_lat'] as num?)?.toDouble() ?? 0,
        lng: (cust?['longitude'] as num?)?.toDouble() ?? (order['delivery_lng'] as num?)?.toDouble() ?? 0,
        title: 'Доставить клиенту: ${cust?['name'] ?? 'Клиент'}',
        subtitle: 'Сумма: ${order['total']} сом',
        address: order['delivery_address'] ?? '',
      ));
    }

    final List<RouteTask> route = [];
    double lastLat = currentLat;
    double lastLng = currentLng;

    // Жадный алгоритм с учетом приоритетов (Greedy Precedence)
    while (allTasks.isNotEmpty) {
      RouteTask? bestTask;
      double minDistance = double.infinity;
      int bestIndex = -1;

      for (int i = 0; i < allTasks.length; i++) {
        final task = allTasks[i];

        // Проверяем доступность: Dropoff доступен только если заказ уже забрали (либо ранее, либо в рамках этого расчета)
        if (task.type == RouteTaskType.dropoff && !orderPickedUp[task.orderId]!) {
          continue; // Нельзя доставить то, что еще не забрали
        }

        final dist = task.distanceTo(lastLat, lastLng);
        if (dist < minDistance) {
          minDistance = dist;
          bestTask = task;
          bestIndex = i;
        }
      }

      if (bestTask == null) {
        // Fallback: если не можем найти доступную задачу (ошибка данных), берем первую
        bestTask = allTasks[0];
        bestIndex = 0;
      }

      // Добавляем в маршрут
      route.add(bestTask);
      allTasks.removeAt(bestIndex);

      // Обновляем позицию
      lastLat = bestTask.lat;
      lastLng = bestTask.lng;

      // Если мы только что добавили Pickup в маршрут, значит в будущих итерациях Dropoff для этого заказа становится доступным
      if (bestTask.type == RouteTaskType.pickup) {
        orderPickedUp[bestTask.orderId] = true;
      }
    }

    // 2. Умная группировка (Опционально): если несколько Pickup из одного магазина идут подряд, можно их объединить в UI.
    // Но для простоты списка мы возвращаем плоский отсортированный массив задач.

    return route;
  }
}
