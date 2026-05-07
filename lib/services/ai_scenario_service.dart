import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../models/energy_scenario.dart';

class AiScenarioService {
  static const String _apiKeyPref = 'groq_api_key';
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key);
  }

  Future<bool> testApiKey(String key) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': 'Say OK'}
          ],
          'max_tokens': 5,
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<EnergyScenario>> generateScenarios({
    required double budgetEGP,
    required int currentDay,
    required double currentKwh,
    required List<Device> devices,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('NO_API_KEY');
    }

    final deviceList = devices
        .map((d) =>
            '${d.name}: ${d.wattage}W, priority: ${d.priority.name}')
        .join('\n');

    final userContent = '''Monthly budget: $budgetEGP EGP.
Current consumption: ${currentKwh.toStringAsFixed(2)} kWh on day $currentDay of the month.
Devices:
$deviceList

Egyptian electricity tiers: 0-50=0.41, 51-100=0.71, 101-200=1.01, 201-350=1.61, 351-650=1.85 EGP/kWh

Return ONLY a JSON array of exactly 3 scenarios (no extra text, no markdown):
[
  {
    "name": "توفير أقصى",
    "emoji": "💰",
    "description": "description in Arabic",
    "predictedCost": 450.0,
    "savingsEGP": 50.0,
    "devices": [
      {
        "deviceName": "AC",
        "hoursPerDay": 4.0,
        "timeSlot": "9PM-1AM"
      }
    ]
  },
  {
    "name": "توازن",
    "emoji": "⚖️",
    "description": "...",
    "predictedCost": 480.0,
    "savingsEGP": 20.0,
    "devices": []
  },
  {
    "name": "راحة",
    "emoji": "😊",
    "description": "...",
    "predictedCost": 510.0,
    "savingsEGP": 0.0,
    "devices": []
  }
]''';

    return await _callApi(apiKey, userContent);
  }

  Future<List<EnergyScenario>> _callApi(
    String apiKey,
    String userContent, {
    int retryCount = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an energy saving assistant for Egyptian homes. Always respond with valid JSON only, no extra text, no markdown code blocks.',
            },
            {
              'role': 'user',
              'content': userContent,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('API_ERROR_${response.statusCode}');
      }

      final responseJson =
          jsonDecode(response.body) as Map<String, dynamic>;
      final content = (responseJson['choices'] as List)
          .first['message']['content'] as String;

      // Clean response — remove possible markdown code fences
      final cleaned = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      try {
        final list = jsonDecode(cleaned) as List<dynamic>;
        return list
            .map((e) =>
                EnergyScenario.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Invalid JSON — retry once
        if (retryCount < 1) {
          return await _callApi(apiKey, userContent,
              retryCount: retryCount + 1);
        }
        throw Exception('INVALID_JSON');
      }
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('NO_INTERNET');
    }
  }
}

final aiScenarioService = AiScenarioService();
