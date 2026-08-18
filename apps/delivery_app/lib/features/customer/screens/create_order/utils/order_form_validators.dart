String? Function(String?) requiredOrderText(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}
