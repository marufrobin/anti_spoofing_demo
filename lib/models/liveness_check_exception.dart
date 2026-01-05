class LivenessCheckException implements Exception {
  String msg;
  LivenessCheckException(this.msg);

  String what() {
    return "LivenessCheckException : $msg";
  }

  @override
  String toString() {
    return msg;
  }
}
