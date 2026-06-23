import 'dart:html' as html;

class SessionStorageHelper {
  static String? getAdminServiceRole() {
    try {
      return html.window.sessionStorage['takesep_admin_service_role'];
    } catch (e) {
      return null;
    }
  }
}
