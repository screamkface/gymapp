int _idCounter = 0;

String newModelId(String prefix) {
  _idCounter += 1;
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
}
