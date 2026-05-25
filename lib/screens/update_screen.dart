import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;

import '../api.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  double progress = 0;
  bool isDownloading = false;
  String apkUrl = '';

  @override
  void initState() {
    super.initState();
    loadVersion();
  }

  Future<void> loadVersion() async {
    final res = await http.get(Uri.parse(Api.versionCheck()));
    final data = jsonDecode(res.body);

    setState(() {
      apkUrl = data['apk_url'];
    });
  }

  Future<void> startUpdate() async {
    setState(() {
      isDownloading = true;
      progress = 0;
    });

    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/update.apk";

    await Dio().download(
      apkUrl,
      path,
      onReceiveProgress: (rec, total) {
        if (total != -1) {
          setState(() {
            progress = rec / total;
          });
        }
      },
    );

    setState(() {
      isDownloading = false;
    });

    await OpenFile.open(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, size: 80),
              const SizedBox(height: 20),
              const Text(
                "يوجد تحديث جديد",
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              if (isDownloading) ...[
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 10),
                Text("${(progress * 100).toStringAsFixed(0)} %"),
              ] else ...[
                ElevatedButton(
                  onPressed: startUpdate,
                  child: const Text("تحديث الآن"),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
