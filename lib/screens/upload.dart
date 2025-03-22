part of bc_screens;

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool processed = false;
  bool processing = false;
  File? _imageFile;
  Map<String, dynamic>? predictions;
  Map<String, dynamic> result = {};
  ResultAdapter? results;
  Box<ResultAdapter> resultBox = Hive.box<ResultAdapter>('results');
  final _controller = ConfettiController();

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    print("🔄 Loading model...");
    await Tflite.loadModel(
      model: "assets/model/model.tflite",
      labels: "assets/model/labels.txt",
    );
    print("✅ Model loaded successfully!");
  }

  @override
  void dispose() {
    Tflite.close();
    _controller.dispose();
    print("🚀 Tflite closed.");
    super.dispose();
  }

  startConfetti() {
    _controller.play();
    Future.delayed(const Duration(seconds: 5), () {
      _controller.stop();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    print("📸 Picking image...");
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: source);

    setState(() {
      if (pickedImage != null) {
        _imageFile = File(pickedImage.path);
        print("🖼️ Image picked: ${_imageFile!.path}");
      } else {
        print("❌ No image selected.");
      }
    });
  }

  Future<void> _performImageDetection() async {
    if (_imageFile != null) {
      setState(() {
        processing = true;
        print("🔍 Detecting cancer in image...");
      });

      var recognitions = await Tflite.runModelOnImage(
        path: _imageFile!.path,
        imageMean: 0.0,
        imageStd: 255.0,
        numResults: 2,
        threshold: 0.2,
        asynch: true,
      );

      setState(() {
        if (recognitions != null && recognitions.isNotEmpty) {
          print("🎯 Detection results: $recognitions");

          predictions = recognitions[0].cast<String, dynamic>();

          result["confidence"] = predictions!["confidence"];
          result["label"] = predictions!["label"];
          result["image"] = _imageFile!.path;
          processed = true;
          processing = false;

          results = ResultAdapter.fromJson(result);
          resultBox.add(results!);

          if( predictions!["label"] == '2 normal') {
            startConfetti();
          }

          print("✅ Detection complete!");
          print("📊 Results: $result");
        } else {
          result["confidence"] = 0.0;
          result["label"] = "Unknown";
          result["image"] = _imageFile!.path;
          processed = true;
          processing = false;

          print("⚠️ No results found.");
        }
      });
    } else {
      print("❌ No image file to process.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.appTheme(context);
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                CustomAppHeader(
                  height: MediaQuery.of(context).size.height * .22,
                ),
                const SizedBox(
                  height: 20,
                ),
                (processed)
                    ? Container()
                    : Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 15.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: appTheme.bgColor2,
                          borderRadius: BorderRadius.circular(12),
                          image: (_imageFile != null)
                              ? DecorationImage(
                                  image: FileImage(_imageFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                      ),
                (processing)
                    ? Container(
                        margin: const EdgeInsets.symmetric(vertical: 25),
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: appTheme.primaryColor,
                        ),
                      )
                    : (processed)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.0),
                              ),
                              Container(
                                height:
                                    MediaQuery.of(context).size.height * .35,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: appTheme.light,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 20),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                child: PredictionScreen(
                                  confidence: result["confidence"] ?? 0.00,
                                  label: result["label"] ?? "0 nothing",
                                ),
                              ),
                            ],
                          )
                        : Container(),
                (processed)
                    ? CustomButton(
                        icon: const Icon(Icons.refresh),
                        title: "Reload",
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.initRoute),
                      )
                    : (_imageFile != null)
                        ? Column(
                            children: [
                              CustomButton(
                                color: appTheme.secondaryColor,
                                icon: const Icon(
                                  CupertinoIcons.search,
                                  size: 20,
                                ),
                                title: "Detect Cancer",
                                onPressed: () => _performImageDetection(),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomButton(
                                color: appTheme.primaryColor,
                                icon: const Icon(
                                  CupertinoIcons.camera,
                                  size: 20,
                                ),
                                title: "Re-upload Picture",
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery),
                              )
                            ],
                          )
                        : Column(
                            children: [
                              CustomButton(
                                color: appTheme.primaryColor,
                                icon: const Icon(
                                  CupertinoIcons.camera,
                                  size: 20,
                                ),
                                title: "Capture with Camera",
                                onPressed: () => _pickImage(ImageSource.camera),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomButton(
                                color: appTheme.uploadColor,
                                icon: const Icon(
                                  CupertinoIcons.cloud_upload_fill,
                                  size: 20,
                                ),
                                title: "Upload Scan",
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery),
                              )
                            ],
                          ),
              ],
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _controller,
          blastDirection: pi / 2,
          gravity: 0.1,
          emissionFrequency: 0.05,
          numberOfParticles: 20,
          shouldLoop: false,
        )
      ],
    );
  }
}

class CustomButton extends StatelessWidget {
  final String? title;
  final Color? color;
  final Icon icon;
  final void Function()? onPressed;
  const CustomButton(
      {super.key, this.title, this.color, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final textTheme = CustomTextTheme.customTextTheme(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(15),
            elevation: 0,
            backgroundColor: color,
          ),
          onPressed: onPressed,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(
                width: 10,
              ),
              Text(
                title.toString(),
                style: textTheme.labelMedium,
              )
            ],
          )),
    );
  }
}
