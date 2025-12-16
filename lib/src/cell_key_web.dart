typedef CellKey = BigInt;

final BigInt _mask32 = BigInt.from(0xFFFFFFFF);
final BigInt _sign32 = BigInt.from(0x80000000);
final BigInt _mod32 = BigInt.from(0x100000000);

int _toSigned32(BigInt u) {
  return (u >= _sign32 ? u - _mod32 : u).toInt();
}

CellKey packCellKey(int x, int y) {
  final bx = BigInt.from(x) & _mask32;
  final by = BigInt.from(y) & _mask32;
  return (bx << 32) | by;
}

int unpackCellX(CellKey key) {
  final u = (key >> 32) & _mask32;
  return _toSigned32(u);
}

int unpackCellY(CellKey key) {
  final u = key & _mask32;
  return _toSigned32(u);
}
