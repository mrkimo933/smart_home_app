// lib/core/constants/mqtt_topics.dart

class MqttTopics {
  // Subscribe topics
  static const String voltage = 'esp/sensors/voltage';
  static const String current = 'esp/sensors/current';
  static const String power = 'esp/sensors/power';
  static const String kwh = 'esp/sensors/kwh';

  // Relay states
  static String relayState(int id) => 'esp/relay/$id/state';
  
  static const String relay1State = 'esp/relay/1/state';
  static const String relay2State = 'esp/relay/2/state';
  static const String relay3State = 'esp/relay/3/state';
  static const String relay4State = 'esp/relay/4/state';

  static const List<String> sensorTopics = [
    voltage,
    current,
    power,
    kwh,
  ];

  static const List<String> relayStateTopics = [
    relay1State,
    relay2State,
    relay3State,
    relay4State,
  ];

  // Publish topics
  static String relaySet(int id) => 'app/relay/$id/set';
  
  static const String relay1Set = 'app/relay/1/set';
  static const String relay2Set = 'app/relay/2/set';
  static const String relay3Set = 'app/relay/3/set';
  static const String relay4Set = 'app/relay/4/set';
}
