import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

import 'constants/email_regex_pattern.dart';

class EmailIdentifierScreen extends StatefulWidget {
  final String imagePath;

  EmailIdentifierScreen({required this.imagePath});

  @override
  _EmailIdentifierScreenState createState() => _EmailIdentifierScreenState();
}

class _EmailIdentifierScreenState extends State<EmailIdentifierScreen> {
  late final String _imagePath;
  late final TextRecognizer _textDetector;
  Size? _imageSize;
  List<TextElement> _elements = [];

  List<String>? _listEmailStrings;

  // Fetching the image size from the image file
  Future<void> _getImageSize(File imageFile) async {
    final Completer<Size> completer = Completer<Size>();

    final Image image = Image.file(imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );

    final Size imageSize = await completer.future;
    setState(() {
      _imageSize = imageSize;
    });
  }

  void _recognizeEmails() async {
    _getImageSize(File(_imagePath));

    // Converter a imagem para InputImage
    final inputImage = InputImage.fromFilePath(_imagePath);
    // Identificar o texto da imagem
    final text = await _textDetector.processImage(inputImage);

    // Padrão para filtrar email
    RegExp regEx = RegExp(emailRegexPattern);

    List<String> emailStrings = [];
    // Localizar emails no texto
    for (TextBlock block in text.blocks) {
      for (TextLine line in block.lines) {
        final splittedLine =
            line.text.split(' ').where((text) => regEx.hasMatch(text)).toList();
        if (splittedLine.isNotEmpty) {
          emailStrings.addAll(splittedLine);

          _elements.addAll(line.elements
              .where((element) => splittedLine.contains(element.text))
              .toList());
        }
      }
    }

    setState(() {
      _listEmailStrings = emailStrings;
    });
  }

  @override
  void initState() {
    _imagePath = widget.imagePath;
    // Initializing the text detector
    _textDetector = GoogleMlKit.vision.textRecognizer();
    _recognizeEmails();
    super.initState();
  }

  @override
  void dispose() {
    // Disposing the text detector when not used anymore
    _textDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emails Reconhecidos"),
      ),
      body: _imageSize != null
          ? Stack(
              children: [
                Container(
                  width: double.maxFinite,
                  color: Colors.black,
                  child: CustomPaint(
                    foregroundPainter: TextDetectorPainter(
                      _imageSize!,
                      _elements,
                    ),
                    child: AspectRatio(
                      aspectRatio: _imageSize!.aspectRatio,
                      child: Image.file(
                        File(_imagePath),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Card(
                    elevation: 8,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              "Email identificados:",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 60,
                            child: SingleChildScrollView(
                              child: Column(
                                children: _listEmailStrings
                                        ?.map<Widget>((text) => Text(text))
                                        .toList() ??
                                    <Widget>[],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }
}

// Helps in painting the bounding boxes around the recognized
// email addresses in the picture
class TextDetectorPainter extends CustomPainter {
  TextDetectorPainter(this.absoluteImageSize, this.elements);

  final Size absoluteImageSize;
  final List<TextElement> elements;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    Rect scaleRect(TextElement container) {
      return Rect.fromLTRB(
        container.boundingBox.left * scaleX,
        container.boundingBox.top * scaleY,
        container.boundingBox.right * scaleX,
        container.boundingBox.bottom * scaleY,
      );
    }

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.red
      ..strokeWidth = 2.0;

    for (TextElement element in elements) {
      canvas.drawRect(scaleRect(element), paint);
    }
  }

  @override
  bool shouldRepaint(TextDetectorPainter oldDelegate) {
    return true;
  }
}
