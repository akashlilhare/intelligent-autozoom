import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(MyApp());
}

const String ssd = "SSD MobileNet";
const String yolo = "Tiny YOLOv2";

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TfliteHome(),
    );
  }
}

class TfliteHome extends StatefulWidget {
  @override
  _TfliteHomeState createState() => _TfliteHomeState();
}

class _TfliteHomeState extends State<TfliteHome> {
  String _model = ssd;
  File _image;
  File croppedImage;

  double _imageWidth;
  double _imageHeight;
  bool _busy = false;
  final picker = ImagePicker();

  List _recognitions;

  @override
  void initState() {
    super.initState();
    _busy = true;

    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      if (_model == yolo) {
        res = await Tflite.loadModel(
          model: "assets/yolov2_tiny.tflite",
          labels: "assets/yolov2_tiny.txt",
        );
      } else {
        res = await Tflite.loadModel(
          model: "assets/ssd_mobilenet.tflite",
          labels: "assets/ssd_mobilenet.txt",
        );
      }
    } on PlatformException {
      print("Failed to load the model");
    }
  }

  pickImage(ImageSource source, Size deviceSize) async {
    var image = await picker.getImage(
      source: source,
    );
    if (image == null) return null;
    setState(() {
      _image = File(image.path);
    });
    predictImage(_image);
  }

  pickFromCamera() async {
    var image = await picker.getImage(
      source: ImageSource.camera,
    );

    if (image == null) return null;
    setState(() {
      _image = File(image.path);
    });
    predictImage(_image);
  }

  predictImage(File image) async {
    if (image == null) return;

    if (_model == yolo) {
      await yolov2Tiny(image);
    } else {
      await ssdMobileNet(image);
    }

    FileImage(image)
        .resolve(ImageConfiguration())
        .addListener((ImageStreamListener((ImageInfo info, bool _) {
          setState(() {
            _imageWidth = info.image.width.toDouble();
            _imageHeight = info.image.height.toDouble();
            print("image height "+_imageHeight.toString());
            print("image width " + _imageWidth.toString());
          });
        })));

    setState(() {
      _image = image;
      _busy = false;
    });
  }

  yolov2Tiny(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
        path: image.path,
        model: "YOLO",
        threshold: 0.3,
        imageMean: 0.0,
        imageStd: 255.0,
        numResultsPerClass: 1);

    setState(() {
      _recognitions = recognitions;
    });
  }

  ssdMobileNet(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
        path: image.path, numResultsPerClass: 1);

    setState(() {
      _recognitions = recognitions;
    });
  }

  Map myWidget;
  Widget toDisplay = Container();
  Rect newRect;

  Widget addBox(Size screen) {

    if (_recognitions == null) return Container();
    if (_imageWidth == null || _imageHeight == null) return Container();

    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;
    int indexMax = 0;
    double maxAcc = 0;
    Color blue = Colors.red;

    for (int i = 0; i < _recognitions.length; i++) {
      if (_recognitions[0]["confidenceInClass"] > maxAcc) {
        maxAcc = _recognitions[0]["confidenceInClass"];
        indexMax = i;
      }
    }

    print(_recognitions[indexMax]);

    return Positioned(
      left: _recognitions[indexMax]["rect"]["x"] * factorX,
      top: _recognitions[indexMax]["rect"]["y"] * factorY,
      width: _recognitions[indexMax]["rect"]["w"] * factorX,
      height: _recognitions[indexMax]["rect"]["h"] * factorY,
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(
          color: blue,
          width: 3,
        )),
        child: Text(
          "${_recognitions[indexMax]["detectedClass"]} ${(_recognitions[indexMax]["confidenceInClass"] * 100).toStringAsFixed(0)}%",
          style: TextStyle(
            background: Paint()..color = blue,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  List<Widget> renderBoxes(Size screen) {
    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;

    Color blue = Colors.red;
    return _recognitions.map((re) {
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
            color: blue,
            width: 3,
          )),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = blue,
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {

    Size size = MediaQuery.of(context).size;

    List<Widget> stackChildren = [];

    stackChildren.add(Container(
      child: Positioned(

        width: size.width,
        child: _image == null
            ? Padding(padding: EdgeInsets.symmetric(vertical: size.width*.7),
            child: Center(child: Text("No Image Selected",style: TextStyle(fontSize: 18,fontWeight: FontWeight.w700),)))
            : Image.file(
                _image,
              ),
      ),
    ));

    //  stackChildren.addAll(renderBoxes(size));
    stackChildren.add(addBox(size));

    if (_busy) {
      stackChildren.add(Center(
        child: CircularProgressIndicator(),
      ));
    }

    return Scaffold(

        appBar: AppBar(
          title: Text("Image Cropper"),
          backgroundColor: Colors.purple,
        ),
        floatingActionButton: Row(mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end, children: [
              MaterialButton(
                onPressed: () { pickImage(ImageSource.camera, size);},
                color: Colors.purple,
                textColor: Colors.white,
                child: Icon(
                  Icons.camera_alt,
                  size: 24,
                ),
                padding: EdgeInsets.all(16),
                shape: CircleBorder(),
              ),
              MaterialButton(
                onPressed: () { pickImage(ImageSource.gallery, size);},
                color: Colors.purple,
                textColor: Colors.white,
                child: Icon(
                  Icons.image,
                  size: 24,
                ),
                padding: EdgeInsets.all(16),
                shape: CircleBorder(),
              ),
        ]),
        body: Container(
          child: Stack(
            children: stackChildren,
          ),
        ),


    );

  }
}
