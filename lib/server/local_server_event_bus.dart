import 'dart:async';

class LocalServerEvent {
  const LocalServerEvent({required this.type, required this.payload});

  final String type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};
}

class LocalServerEventBus {
  LocalServerEventBus._();

  static final LocalServerEventBus instance = LocalServerEventBus._();

  final StreamController<LocalServerEvent> _controller =
      StreamController<LocalServerEvent>.broadcast();

  Stream<LocalServerEvent> get stream => _controller.stream;

  void emit(LocalServerEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
