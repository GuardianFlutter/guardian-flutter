import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class notificationServices {
  static const String _supabaseUrl = 'https://oczkalzjerzqydzwdnyi.supabase.co';
  static const String _funtionPath = '/functions/v1/send-sos-email';
  
  static Future<void> sendSosEmail({
    required String IdToken,
    required String userId,
    required String userName,
    required String address,
    required String latitude,
    required String longitude,
    required List<Map<String, String>> recipients,
  }) async {
    final uri = Uri.parse('$_supabaseUrl$_funtionPath');

    await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $IdToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userId': userId,
        'userName': userName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'recipients': recipients,
      }),
    ); 
  }

  static Future<void> openWhatsapp({
    required String userName,
    required String address,
    required String latitude,
    required String longitude,
  }) async {
    final message = 'Alerta Sos - $userName%0A'
                    'Ubicación: $address%0A'
                    'Coordenadas: $latitude, $longitude%0A'
                    'Ver en Google Maps: https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';   
    final uri = Uri.parse('https://wa.me/?text=$message');
    final canLaunch = await canLaunchUrl(uri);
    print('Whatsapp canLaunch: $canLaunch, uri: $uri');
    if(await canLaunchUrl(uri)){
      await launchUrl(uri);
    } else {
      throw 'No se pudo abrir WhatsApp';
    }
  }
}