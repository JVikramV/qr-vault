import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:url_launcher/url_launcher.dart';
import 'qr_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  runApp(const QRVaultApp());
}

class QRVaultApp extends StatelessWidget {
  const QRVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0F0628),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5CF6),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0628),
          elevation: 0,
        ),
      ),

      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController =
  TextEditingController();

  Future<void> launchPayment(String upiUri) async {
    final uri = Uri.parse(upiUri);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }


  String searchQuery = "";
  Set<String> favoriteUpis = {};
  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();

    final favorites =
        prefs.getStringList('favorites') ?? [];

    setState(() {
      favoriteUpis = favorites.toSet();
    });
  }

  Future<void> saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'favorites',
      favoriteUpis.toList(),
    );
  }
  List<Map<String, String>> get sortedQrList {
    final list = List<Map<String, String>>.from(filteredQrList);

    list.sort((a, b) {
      final aFav =
      favoriteUpis.contains(a["upi"]);
      final bFav =
      favoriteUpis.contains(b["upi"]);

      if (aFav == bFav) return 0;

      return aFav ? -1 : 1;
    });

    return list;
  }
  List<Map<String, String>> get filteredQrList {
    if (searchQuery.isEmpty) {
      return qrList;
    }

    return qrList.where((qr) {
      final name =
      (qr["name"] ?? "").toLowerCase();

      final upi =
      (qr["upi"] ?? "").toLowerCase();

      return name.contains(searchQuery.toLowerCase()) ||
          upi.contains(searchQuery.toLowerCase());
    }).toList();
  }
  String message = "Tap Scan Gallery";
  List<Map<String, String>> qrList = [];
  Map<String, String> parseUpi(String qrData) {
    try {
      final uri = Uri.parse(qrData);

      return {
        "name": uri.queryParameters["pn"] ?? "Unknown",
        "upi": uri.queryParameters["pa"] ?? "Unknown",
      };
    } catch (_) {
      return {
        "name": "Invalid QR",
        "upi": "",
      };
    }
  }
  @override
  void initState() {
    super.initState();

    loadFavorites();

    scanGallery();
  }

  Future<void> scanGallery() async {
    final PermissionState ps =
    await PhotoManager.requestPermissionExtend();

    if (!ps.hasAccess) {
      setState(() {
        message = "Gallery permission denied";
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    final Set<String> uniqueImages = {};
    final Set<String> processedImages = {};
    qrList.clear();
    int totalQrCodes = 0;

    final scanner = BarcodeScanner();
    final Set<String> uniqueUpis = {};

    for (final album in albums) {
      final images = await album.getAssetListPaged(
        page: 0,
        size: 100,
      );

      for (final image in images) {
        uniqueImages.add(image.id);

      }

      for (final image in images) {
        if (processedImages.contains(image.id)) {
          continue;
        }

        processedImages.add(image.id);
        final file = await image.file;

        if (file == null) continue;

        try {
          final inputImage =
          InputImage.fromFilePath(file.path);

          final barcodes =
          await scanner.processImage(inputImage);

          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              final data = barcode.rawValue!;
              print("QR DATA: $data");

              if (data.startsWith("upi://")) {
                final parsed = parseUpi(data);

                final upiId =
                    parsed["upi"] ?? "Unknown";

                if (!uniqueUpis.contains(upiId)) {
                  uniqueUpis.add(upiId);

                  qrList.add({
                    "name": parsed["name"] ?? "Unknown",
                    "upi": upiId,
                    "rawUpi": data,
                    "imagePath": file.path,
                  });
                }
              }
              totalQrCodes++;
            }
          }
        } catch (_) {}
      }
    }

    await scanner.close();

    setState(() {
      message = "Found $totalQrCodes QR codes";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/logo.png',
                width: 40,
                height: 40,
              ),

              const SizedBox(width: 12),

              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "QR Vault",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Your Payment Wallet",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [


            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF24114A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Search merchant or UPI",
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: sortedQrList.length,
                itemBuilder: (context, index) {

                  final qr = sortedQrList[index];

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2D145E),
                          Color(0xFF1C0B3A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),

                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF8B5CF6),
                        child: const Icon(
                          Icons.qr_code_2,
                          color: Colors.white,
                        ),
                      ),

                      title: Text(
                        qr["name"]!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          qr["upi"]!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      trailing: IconButton(
                        icon: Icon(
                          favoriteUpis.contains(qr["upi"])
                              ? Icons.star
                              : Icons.star_border,
                          color: const Color(0xFFFFD700),
                        ),
                        onPressed: () async {
                          setState(() {
                            if (favoriteUpis.contains(qr["upi"])) {
                              favoriteUpis.remove(qr["upi"]);
                            } else {
                              favoriteUpis.add(qr["upi"]!);
                            }
                          });

                          await saveFavorites();
                        },
                      ),

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QrDetailScreen(
                              qr: qr,
                            ),
                          ),
                        );
                      },
                    ),
                  );;
                },
              ),
            ),
          ],
        ),
    );
  }
}