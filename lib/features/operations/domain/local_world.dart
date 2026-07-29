/// A world found on this machine, ready to push.
class LocalWorldCandidate {
  const LocalWorldCandidate({
    required this.slot,
    required this.slotInferred,
    required this.mainPath,
    required this.mainSize,
    this.mainModified,
    this.pugbackupPath,
    this.pugbackupSize,
  });

  /// The slot this world will occupy on the server.
  final int slot;

  /// Whether [slot] came from the filename or is just a default.
  ///
  /// `false` means the file was accepted despite not following the `N.world.gzip`
  /// convention — a manual export, a file someone shared, anything renamed along the way
  /// — and [slot] defaulted to 0. The UI must then ask which slot to use rather than
  /// treating it as known, and it doubles as the way to seed a brand-new slot from an
  /// arbitrary file.
  final bool slotInferred;

  final String mainPath;
  final int mainSize;
  final int? mainModified;

  /// Core Keeper's own rolling backup for this slot, if it was found alongside. Roughly
  /// one save cycle behind the main file; the two travel together as a set.
  final String? pugbackupPath;
  final int? pugbackupSize;

  bool get hasPugbackup => pugbackupPath != null;

  LocalWorldCandidate withSlot(int newSlot) => LocalWorldCandidate(
    slot: newSlot,
    slotInferred: slotInferred,
    mainPath: mainPath,
    mainSize: mainSize,
    mainModified: mainModified,
    pugbackupPath: pugbackupPath,
    pugbackupSize: pugbackupSize,
  );
}
