import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

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
      print(res);
    } on PlatformException {
      print("Failed to load the model");
    }
  }

  pickFromCamera() async {
    var image = await picker.getImage(source: ImageSource.camera);
    print(image);
    if (image == null) return null;
    setState(() {
      _image = File(image.path);
    });
    predictImage(_image);
  }

  pickFromGallery() async {
    var image = await picker.getImage(source: ImageSource.gallery);
    print(image.path);
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
            print(_imageHeight);
            print(_imageWidth);
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

  cropImage(File imageFile, int i) async {
    double factorX = 300;
    double factorY = _imageHeight / _imageHeight * 300;
    var obj = _recognitions[i];
    var a = IOSUiSettings(
      rectX: obj["rect"]["x"] * factorX,
      rectY: obj["rect"]["y"] * factorY,
      rectHeight: obj["rect"]["h"] * factorY,
      rectWidth: obj["rect"]["w"] * factorX,
    );
    File croppedFile = await ImageCropper.cropImage(
        sourcePath: imageFile.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9,
        ],
        androidUiSettings: AndroidUiSettings(

            toolbarTitle: 'Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
       // iosUiSettings: a
        );
    print(croppedImage.path);
    setState(() {
      croppedImage = croppedFile;
    });

    return croppedFile;
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

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
    cropImage(_image, 0);
    print("--------------------------" + croppedImage.path);

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
      // margin: EdgeInsets.only(left: 5),
      // height: 400,
      //width: double.infinity,
      child: Positioned(
        top: 0.0,
        left: 0.0,
        width: size.width,
        child: _image == null
            ? Text("No Image Selected")
            : Image.file(
                _image,
              ),
      ),
    ));

    stackChildren.addAll(renderBoxes(size));

    if (_busy) {
      stackChildren.add(Center(
        child: CircularProgressIndicator(),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("TFLite Demo"),
      ),
      floatingActionButton: Row(
        children: [
          ElevatedButton(
            child: Icon(Icons.camera_alt),
            onPressed: pickFromCamera,
          ),
          ElevatedButton(
            child: Icon(Icons.image),
            onPressed: pickFromGallery,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 200,
            child: Stack(
              children: stackChildren,
            ),
          ),
          Container(
            child: croppedImage == null
                ? Container(
                    child: Text("please select file"),
                  )
                : Image.file(_image,alignment: Alignment.lerp(1,1,1),),
          )
        ],
      ),
    );
  }
}
