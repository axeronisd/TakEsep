import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final imagePath = 'assets/images/logo1.JPG';
  final file = File(imagePath);
  if (!file.existsSync()) {
    print('Error: Logo file not found');
    return;
  }
  
  final image = img.decodeImage(file.readAsBytesSync());
  if (image == null) return;

  final width = image.width;
  final height = image.height;
  final size = width > height ? width : height;

  final squareImage = img.Image(width: size, height: size);
  img.fill(squareImage, color: img.ColorRgb8(255, 255, 255));

  final dx = (size - width) ~/ 2;
  final dy = (size - height) ~/ 2;
  img.compositeImage(squareImage, image, dstX: dx, dstY: dy);

  File('assets/images/logo_square.png').writeAsBytesSync(img.encodePng(squareImage));
  print('Saved logo_square.png');
}
