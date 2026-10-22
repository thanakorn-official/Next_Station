import 'dart:convert';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

void main() {
  runApp(const NextStationApp());
}

// ---------------------------------------------------------
// 1. Data Model
// ---------------------------------------------------------
class Station {
  final String id;
  final String nameTh;
  final String lineColor;
  final List<String> connections;

  Station({
    required this.id,
    required this.nameTh,
    required this.lineColor,
    required this.connections,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'],
      nameTh: json['name_th'],
      lineColor: json['line_color'],
      connections: List<String>.from(json['connections']),
    );
  }
}

// ---------------------------------------------------------
// 2. Main Application & UI
// ---------------------------------------------------------
class NextStationApp extends StatelessWidget {
  const NextStationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextStation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, fontFamily: 'Roboto'),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Map<String, Station> stationMap = {};
  List<Station> stationsList = [];
  List<String> availableLines = [];

  Station? selectedOrigin;
  Station? selectedDestination;

  List<Station> calculatedPath = [];
  int calculatedFare = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStationData();
  }

  Future<void> _loadStationData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/stations.json',
      );
      final List<dynamic> data = json.decode(response);

      Map<String, Station> tempMap = {};
      List<Station> tempList = [];
      Set<String> linesSet = {'ทั้งหมด'};

      for (var item in data) {
        Station station = Station.fromJson(item);
        tempMap[station.id] = station;
        tempList.add(station);
        linesSet.add(station.lineColor);
      }

      setState(() {
        stationMap = tempMap;
        stationsList = tempList;
        availableLines = linesSet.toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading JSON: $e");
    }
  }

  // ฟังก์ชันสลับต้นทาง - ปลายทาง (แบบ Google Maps)
  void swapStations() {
    setState(() {
      final temp = selectedOrigin;
      selectedOrigin = selectedDestination;
      selectedDestination = temp;
      _calculateRoute(); // คำนวณใหม่ทันทีหลังสลับ
    });
  }

  // อัลกอริทึม BFS หาเส้นทางที่สั้นที่สุด
  List<Station> _findShortestPath(String startId, String endId) {
    Queue<List<Station>> queue = Queue();
    Set<String> visited = {};

    queue.add([stationMap[startId]!]);
    visited.add(startId);

    while (queue.isNotEmpty) {
      List<Station> path = queue.removeFirst();
      Station current = path.last;

      if (current.id == endId) return path;

      for (String neighborId in current.connections) {
        if (!visited.contains(neighborId) &&
            stationMap.containsKey(neighborId)) {
          visited.add(neighborId);
          List<Station> newPath = List.from(path)..add(stationMap[neighborId]!);
          queue.add(newPath);
        }
      }
    }
    return [];
  }

  void _calculateRoute() {
    if (selectedOrigin != null && selectedDestination != null) {
      if (selectedOrigin!.id == selectedDestination!.id) {
        setState(() {
          calculatedPath = [];
          calculatedFare = 0;
        });
        return;
      }
      List<Station> path = _findShortestPath(
        selectedOrigin!.id,
        selectedDestination!.id,
      );
      setState(() {
        calculatedPath = path;
        calculatedFare = path.isNotEmpty ? 16 + ((path.length - 1) * 3) : 0;
      });
    } else {
      setState(() {
        calculatedPath = [];
        calculatedFare = 0;
      });
    }
  }

  // เปิดหน้าต่างเลือกสถานี (Bottom Sheet)
  void _openStationPicker(bool isOrigin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ทำให้หน้าต่างขยายเต็มได้เมื่อมีคีย์บอร์ด
      backgroundColor: Colors.transparent,
      builder: (context) => StationPickerSheet(
        stations: stationsList,
        lines: availableLines,
        title: isOrigin ? 'เลือกสถานีต้นทาง' : 'เลือกสถานีปลายทาง',
        onStationSelected: (station) {
          setState(() {
            if (isOrigin) {
              selectedOrigin = station;
            } else {
              selectedDestination = station;
            }
            _calculateRoute(); // คำนวณอัตโนมัติเมื่อเลือกครบ
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 1. แผนที่อยู่ด้านหลังสุด (Background)
            Positioned.fill(
              child: PhotoView(
                imageProvider: const AssetImage('assets/images/MainMap.jpg'),
                backgroundDecoration: BoxDecoration(color: Colors.grey[200]),
                minScale: PhotoViewComputedScale.contained * 0.9,
                maxScale: PhotoViewComputedScale.covered * 3.0,
              ),
            ),

            // 2. แผงควบคุม ต้นทาง-ปลายทาง ด้านบน (Google Maps Style)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // ไอคอนจุดและหมุดบอกทาง
                      Column(
                        children: [
                          const Icon(
                            Icons.trip_origin,
                            color: Colors.blue,
                            size: 20,
                          ),
                          Container(
                            width: 2,
                            height: 35,
                            color: Colors.grey[300],
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 24,
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // ช่องเลือกสถานี
                      Expanded(
                        child: Column(
                          children: [
                            // ต้นทาง
                            GestureDetector(
                              onTap: () => _openStationPicker(true),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[50],
                                ),
                                child: Text(
                                  selectedOrigin?.nameTh ??
                                      'พิมพ์ค้นหาสถานีต้นทาง...',
                                  style: TextStyle(
                                    color: selectedOrigin != null
                                        ? Colors.black
                                        : Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // ปลายทาง
                            GestureDetector(
                              onTap: () => _openStationPicker(false),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[50],
                                ),
                                child: Text(
                                  selectedDestination?.nameTh ??
                                      'พิมพ์ค้นหาสถานีปลายทาง...',
                                  style: TextStyle(
                                    color: selectedDestination != null
                                        ? Colors.black
                                        : Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ปุ่มสลับสถานี (Swap)
                      IconButton(
                        icon: const Icon(
                          Icons.swap_vert,
                          size: 30,
                          color: Colors.grey,
                        ),
                        onPressed: swapStations,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. แผงแสดงผลลัพธ์ราคาด้านล่างสุด (จะโผล่มาเมื่อเลือกครบ)
            if (calculatedPath.isNotEmpty)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'เดินทางทั้งหมด ${calculatedPath.length - 1} สถานี',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '฿$calculatedFare',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // อนาคตสามารถทำหน้าต่างดูรายละเอียดเส้นทาง (Route Details) ได้
                          },
                          icon: const Icon(Icons.directions_transit),
                          label: const Text(
                            'เริ่มเดินทาง',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. Bottom Sheet สำหรับค้นหาและกรองสถานี
// ---------------------------------------------------------
class StationPickerSheet extends StatefulWidget {
  final List<Station> stations;
  final List<String> lines;
  final String title;
  final Function(Station) onStationSelected;

  const StationPickerSheet({
    Key? key,
    required this.stations,
    required this.lines,
    required this.title,
    required this.onStationSelected,
  }) : super(key: key);

  @override
  State<StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<StationPickerSheet> {
  String searchQuery = '';
  String selectedFilter = 'ทั้งหมด';

  // ฟังก์ชันแปลงชื่อสายเป็นสีสวยๆ
  Color getLineColor(String line) {
    if (line.contains('เขียวอ่อน')) return Colors.lightGreen;
    if (line.contains('เขียวเข้ม')) return Colors.teal;
    if (line.contains('น้ำเงิน')) return Colors.blue;
    if (line.contains('ม่วง')) return Colors.purple;
    if (line.contains('เหลือง'))
      return Colors.orange; // ใช้สีส้มเพื่อให้อ่านตัวหนังสือสีขาวชัดขึ้น
    if (line.contains('ชมพู')) return Colors.pinkAccent;
    if (line.contains('แอร์พอร์ต')) return Colors.red[900]!;
    if (line.contains('ทอง')) return Colors.amber.shade700;
    if (line.contains('แดง')) return Colors.red;
    return Colors.grey;
  }

  // กรองรายการสถานี
  List<Station> get filteredStations {
    return widget.stations.where((station) {
      final matchLine =
          selectedFilter == 'ทั้งหมด' || station.lineColor == selectedFilter;
      final matchSearch = station.nameTh.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      return matchLine && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // สูง 85% ของจอ
      margin: EdgeInsets.only(
        bottom: keyboardHeight,
      ), // ดันขึ้นเมื่อคีย์บอร์ดโผล่
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // แถบขีดๆ ด้านบน
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // ช่อง Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อสถานี...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
          const SizedBox(height: 12),

          // ตัวกรองสีรถไฟฟ้า (Horizontal Scroll)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: widget.lines.map((line) {
                final isSelected = selectedFilter == line;
                final color = getLineColor(line);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      line
                          .replaceAll(RegExp(r'\(.*\)'), '')
                          .trim(), // ซ่อนภาษาอังกฤษให้กระชับ
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: Colors.grey[200],
                    onSelected: (selected) {
                      if (selected) setState(() => selectedFilter = line);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),

          // รายการสถานีที่ค้นพบ
          Expanded(
            child: ListView.builder(
              itemCount: filteredStations.length,
              itemBuilder: (context, index) {
                final station = filteredStations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: getLineColor(station.lineColor),
                    radius: 12,
                  ),
                  title: Text('${station.nameTh} (${station.id})'),
                  subtitle: Text(
                    station.lineColor,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    FocusScope.of(context).unfocus(); // ปิดคีย์บอร์ด
                    Navigator.pop(context); // ปิด Bottom sheet
                    widget.onStationSelected(station); // ส่งค่ากลับไป
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
