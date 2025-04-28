// lib/core/models/result.dart
class Result<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;

  Result.success(this.data) : isSuccess = true, errorMessage = null;

  Result.error(this.errorMessage) : isSuccess = false, data = null;

  bool get isError => !isSuccess;
  @override
  String toString() {
    return 'Result{data: $data, errorMessage: $errorMessage, isSuccess: $isSuccess}';
  }
}
