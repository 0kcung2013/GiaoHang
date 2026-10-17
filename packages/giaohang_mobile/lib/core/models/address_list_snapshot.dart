class AddressListSnapshot<T> {
  const AddressListSnapshot({
    required this.items,
    this.isFromCache = false,
    this.warning,
  });

  final List<T> items;
  final bool isFromCache;
  final String? warning;
}
