import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';
import 'powersync_db.dart';
import 'supabase_sync.dart';

/// Repository for Service CRUD operations via PowerSync.
class ServiceRepository {
  final _uuid = const Uuid();

  Future<List<Service>> getServices(String companyId) async {
    final rows = await powerSyncDb.getAll(
      'SELECT * FROM services WHERE company_id = ? ORDER BY name',
      [companyId],
    );
    return rows.map((r) => Service.fromJson(r)).toList();
  }

  Future<Service> createService({
    required String companyId,
    required String name,
    String? category,
    String? description,
    required double price,
    int durationMinutes = 0,
    String? imageUrl,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await powerSyncDb.execute(
      '''INSERT INTO services (id, company_id, name, category, description,
         price, duration_minutes, is_active, image_url, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [id, companyId, name, category, description, price, durationMinutes, 1, imageUrl, now, now],
    );

    await SupabaseSync.upsert('services', {
      'id': id, 'company_id': companyId, 'name': name, 'category': category,
      'description': description, 'price': price, 'duration_minutes': durationMinutes,
      'is_active': true, 'image_url': imageUrl, 'created_at': now, 'updated_at': now,
    });

    return Service(
      id: id, companyId: companyId, name: name, category: category,
      description: description, price: price, durationMinutes: durationMinutes,
      imageUrl: imageUrl,
      createdAt: DateTime.now(), updatedAt: DateTime.now(),
    );
  }

  Future<void> updateService({
    required String serviceId,
    String? name, String? category, String? description,
    double? price, int? durationMinutes, bool? isActive, String? imageUrl, bool clearImage = false,
  }) async {
    final sets = <String>[];
    final params = <Object?>[];
    if (name != null) { sets.add('name = ?'); params.add(name); }
    if (category != null) { sets.add('category = ?'); params.add(category); }
    if (description != null) { sets.add('description = ?'); params.add(description); }
    if (price != null) { sets.add('price = ?'); params.add(price); }
    if (durationMinutes != null) { sets.add('duration_minutes = ?'); params.add(durationMinutes); }
    if (clearImage) {
      sets.add('image_url = NULL');
    } else if (imageUrl != null) {
      sets.add('image_url = ?'); params.add(imageUrl);
    }
    if (isActive != null) { sets.add('is_active = ?'); params.add(isActive ? 1 : 0); }
    if (sets.isEmpty) return;
    sets.add('updated_at = ?'); params.add(DateTime.now().toIso8601String());
    params.add(serviceId);
    await powerSyncDb.execute(
      'UPDATE services SET ${sets.join(', ')} WHERE id = ?', params,
    );

    final sbData = <String, dynamic>{};
    if (name != null) sbData['name'] = name;
    if (category != null) sbData['category'] = category;
    if (description != null) sbData['description'] = description;
    if (price != null) sbData['price'] = price;
    if (durationMinutes != null) sbData['duration_minutes'] = durationMinutes;
    if (isActive != null) sbData['is_active'] = isActive;
    if (clearImage) sbData['image_url'] = null;
    else if (imageUrl != null) sbData['image_url'] = imageUrl;
    sbData['updated_at'] = DateTime.now().toIso8601String();
    await SupabaseSync.update('services', serviceId, sbData);
  }

  Future<void> deleteService(String serviceId) async {
    await powerSyncDb.execute('DELETE FROM services WHERE id = ?', [serviceId]);
    await SupabaseSync.delete('services', serviceId);
  }
}
