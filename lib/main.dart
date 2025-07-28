import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: TriggerPage(),
  ));
}

class TriggerPage extends StatefulWidget {
  const TriggerPage({super.key});

  @override
  State<TriggerPage> createState() => _TriggerPageState();
}

class _TriggerPageState extends State<TriggerPage> {
  String ip = '192.168.70.190';
  List<String> modes = List.generate(6, (_) => 'column');
  List<String> columns = List.generate(6, (index) => '${index + 1}');
  List<String> layers = List.generate(6, (_) => '1');
  List<String> clips = List.generate(6, (_) => '1');
  int tapCount = 0;
  DateTime lastTap = DateTime.now();
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/bg_vedio.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.setVolume(0);
        _videoController.play();
        if (mounted) setState(() {});
      });
    loadPrefs();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      ip = prefs.getString('resolume_ip') ?? ip;
      for (int i = 0; i < 6; i++) {
        modes[i] = prefs.getString('mode_$i') ?? 'column';
        columns[i] = prefs.getString('column_${i + 1}') ?? '${i + 1}';
        layers[i] = prefs.getString('layer_${i + 1}') ?? '1';
        clips[i] = prefs.getString('clip_${i + 1}') ?? '1';
      }
    });
  }

  Future<void> sendOSC(int index) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      String address;
      if (modes[index] == 'layer_clip') {
        address = "/composition/layers/${layers[index]}/clips/${clips[index]}/connect";
      } else {
        address = "/composition/columns/${columns[index]}/connect";
      }
      final message = _buildOSC(address);
      socket.send(message, InternetAddress(ip), 7000);
      socket.close();
    } catch (e) {
      print("❌ Error sending OSC: $e");
    }
  }

  Uint8List _buildOSC(String address) {
    List<int> bytes = [];
    bytes.addAll(_padOSCString(address));
    bytes.addAll(_padOSCString(","));
    return Uint8List.fromList(bytes);
  }

  List<int> _padOSCString(String value) {
    final bytes = utf8.encode(value);
    final pad = (4 - (bytes.length % 4)) % 4;
    return [...bytes, ...List.filled(pad, 0)];
  }

  void handleTap(Offset position, Size size) {
    final now = DateTime.now();
    final diff = now.difference(lastTap);
    lastTap = now;

    bool inTopRight = position.dx > size.width * 0.7 && position.dy < size.height * 0.3;

    if (diff.inMilliseconds < 600 && inTopRight) {
      tapCount++;
      if (tapCount >= 3) {
        tapCount = 0;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SetupPage(
            ip: ip,
            modes: modes,
            columns: columns,
            layers: layers,
            clips: clips,
          )),
        ).then((_) => loadPrefs());
      }
    } else {
      tapCount = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final isMobile = width < 600;

    final logoHeight = isMobile ? width * 0.12 : width * 0.08;
    final gridMaxWidth = width * 0.9 > 700 ? 700.0 : width * 0.9;

    return GestureDetector(
      onTapDown: (details) => handleTap(details.globalPosition, media.size),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            if (_videoController.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
            Positioned(
              top: 80,
              left: 20,
              child: Image.asset(
                'assets/logo.png',
                height: logoHeight,
                fit: BoxFit.contain,
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: gridMaxWidth),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    const spacing = 12.0;
                    final buttonWidth = (availableWidth - spacing) / 2;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: List.generate(4, (i) {
                        return GestureDetector(
                          onTap: () => sendOSC(i),
                          child: Container(
                            width: buttonWidth,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: AssetImage('assets/Asset ${i + 1}.png'),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),
            const Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  "Triple tap top-right corner to open setup",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SetupPage extends StatelessWidget {
  final String ip;
  final List<String> modes;
  final List<String> columns;
  final List<String> layers;
  final List<String> clips;

  const SetupPage({
    super.key,
    required this.ip,
    required this.modes,
    required this.columns,
    required this.layers,
    required this.clips,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Setup', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final prefs = snapshot.data!;

          final ipController = TextEditingController(text: ip);
          final modeOptions = ['column', 'layer_clip'];
          final columnControllers = List.generate(6, (i) => TextEditingController(text: columns[i]));
          final layerControllers = List.generate(6, (i) => TextEditingController(text: layers[i]));
          final clipControllers = List.generate(6, (i) => TextEditingController(text: clips[i]));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: ipController,
                decoration: const InputDecoration(labelText: 'Resolume IP'),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < 4; i++)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: modes[i],
                      items: modeOptions
                          .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                          .toList(),
                      onChanged: (value) {
                        prefs.setString('mode_$i', value!);
                      },
                      decoration: InputDecoration(labelText: 'Mode for Button ${i + 1}'),
                    ),
                    if (modes[i] == 'column')
                      TextField(
                        controller: columnControllers[i],
                        decoration: const InputDecoration(labelText: 'Column Number'),
                        onChanged: (value) => prefs.setString('column_${i + 1}', value),
                      ),
                    if (modes[i] == 'layer_clip') ...[
                      TextField(
                        controller: layerControllers[i],
                        decoration: const InputDecoration(labelText: 'Layer Number'),
                        onChanged: (value) => prefs.setString('layer_${i + 1}', value),
                      ),
                      TextField(
                        controller: clipControllers[i],
                        decoration: const InputDecoration(labelText: 'Clip Number'),
                        onChanged: (value) => prefs.setString('clip_${i + 1}', value),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ElevatedButton(
                onPressed: () async {
                  await prefs.setString('resolume_ip', ipController.text.trim());
                  for (int i = 0; i < 6; i++) {
                    await prefs.setString('column_${i + 1}', columnControllers[i].text.trim());
                    await prefs.setString('layer_${i + 1}', layerControllers[i].text.trim());
                    await prefs.setString('clip_${i + 1}', clipControllers[i].text.trim());
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 60),
                ),
                child: const Text(
                  'Save & Back',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}