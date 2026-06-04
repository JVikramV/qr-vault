import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

Future<void> launchPayment(String upiUri) async {
  final uri = Uri.parse(upiUri);

  if (await canLaunchUrl(uri)) {
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}

class QrDetailScreen extends StatelessWidget {
  final Map<String, String> qr;

  const QrDetailScreen({
    super.key,
    required this.qr,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(qr["name"] ?? "QR"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(
                File(qr["imagePath"]!),
                fit: BoxFit.contain,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              qr["upi"] ?? "",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ElevatedButton.icon(
            icon: const Icon(Icons.payment),
            label: const Text("Pay With..."),
            onPressed: () {
              launchPayment(
                qr["rawUpi"]!,
              );
            },
          ),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text("Copy UPI ID"),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: qr["upi"]!,
                ),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("UPI ID copied"),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text("Share QR"),
            onPressed: () async {
              await Share.shareXFiles(
                [
                  XFile(qr["imagePath"]!),
                ],
                text: "${qr["name"]}\n${qr["upi"]}",
              );
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}