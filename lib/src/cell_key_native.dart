typedef CellKey = int;

CellKey packCellKey(int x, int y) {
  return ((x & 0xFFFFFFFF) << 32) | (y & 0xFFFFFFFF);
}

int unpackCellX(CellKey key) {
  final u = (key >> 32) & 0xFFFFFFFF;
  return u >= 0x80000000 ? u - 0x100000000 : u;
}

int unpackCellY(CellKey key) {
  final u = key & 0xFFFFFFFF;
  return u >= 0x80000000 ? u - 0x100000000 : u;
}
