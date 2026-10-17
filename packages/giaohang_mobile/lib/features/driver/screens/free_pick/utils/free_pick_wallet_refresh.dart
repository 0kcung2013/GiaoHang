import '../../../../../core/services/free_pick_service.dart';

typedef FreePickViewportReload = void Function(FreePickViewport viewport);

bool reloadFreePickAfterWalletChange({
  required int? previousRevision,
  required int? nextRevision,
  required bool isEnabled,
  required FreePickViewport? viewport,
  required FreePickViewportReload reload,
}) {
  if (previousRevision == null ||
      nextRevision == null ||
      previousRevision == nextRevision ||
      !isEnabled ||
      viewport == null) {
    return false;
  }

  reload(viewport);
  return true;
}
