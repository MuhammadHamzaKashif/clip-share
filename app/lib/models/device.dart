class Device {
  const Device({
    required this.id,
    required this.name,
    required this.connected,
  });

  final String id;
  final String name;
  final bool connected;

  Device copyWithConnected(bool value) =>
      Device(id: id, name: name, connected: value);
}
