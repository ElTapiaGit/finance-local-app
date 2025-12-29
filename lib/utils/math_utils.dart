/// Redondea un valor double a 2 decimales matematicamente exactos.
/// Ejemplo: 10.5599999 -> 10.56
double roundAmount(double value) {
  return (value * 100).roundToDouble() / 100;
}