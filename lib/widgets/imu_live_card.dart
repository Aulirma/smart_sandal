import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/emerys_ble_service.dart';
import '../theme/app_theme.dart';

// class ImuLiveCard extends StatefulWidget {
//   const ImuLiveCard({super.key});
//
//   @override
//   State<ImuLiveCard> createState() => _ImuLiveCardState();
// }
//
// class _ImuLiveCardState extends State<ImuLiveCard> {
//   final EmerysBleService _bleService = EmerysBleService.instance;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Otomatis mencari sandal ketika Page Pantau pertama kali dibuka.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _bleService.connect();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _bleService,
//       builder: (context, _) {
//         final reading = _bleService.latestReading;
//
//         return Container(
//           width: double.infinity,
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             color: Theme.of(context).cardColor,
//             borderRadius: BorderRadius.circular(24),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.03),
//                 blurRadius: 10,
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildHeader(context),
//               const SizedBox(height: 16),
//               _buildConnectionPanel(context),
//               if (_bleService.errorMessage != null) ...[
//                 const SizedBox(height: 12),
//                 _buildErrorPanel(context, _bleService.errorMessage!),
//               ],
//               const SizedBox(height: 18),
//               if (reading == null)
//                 _buildEmptyState(context)
//               else
//                 _buildReading(context, reading),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildHeader(BuildContext context) {
//     final statusColor = _statusColor();
//
//     return Row(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: AppTheme.primaryColor.withValues(alpha: 0.1),
//             shape: BoxShape.circle,
//           ),
//           child: const Icon(
//             Icons.sensors,
//             color: AppTheme.primaryColor,
//             size: 20,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Data IMU Langsung',
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 15,
//                   color: Theme.of(context).colorScheme.onSurface,
//                 ),
//               ),
//               Text(
//                 'MPU6050 • Accelerometer dan Gyroscope',
//                 style: TextStyle(
//                   fontSize: 11,
//                   color: Theme.of(context).colorScheme.onSurfaceVariant,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
//           decoration: BoxDecoration(
//             color: statusColor.withValues(alpha: 0.12),
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(Icons.circle, size: 7, color: statusColor),
//               const SizedBox(width: 5),
//               Text(
//                 _statusLabel(),
//                 style: TextStyle(
//                   color: statusColor,
//                   fontSize: 9,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildConnectionPanel(BuildContext context) {
//     final isConnected = _bleService.isConnected;
//     final isBusy = _bleService.isBusy;
//
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppTheme.primaryColor.withValues(alpha: 0.07),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             isConnected
//                 ? Icons.bluetooth_connected
//                 : Icons.bluetooth_searching,
//             color: AppTheme.primaryColor,
//             size: 22,
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   EmerysBleService.targetDeviceName,
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 13,
//                     color: Theme.of(context).colorScheme.onSurface,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   _connectionDescription(),
//                   style: TextStyle(
//                     fontSize: 10,
//                     color: Theme.of(context).colorScheme.onSurfaceVariant,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 8),
//           if (isConnected)
//             TextButton(
//               onPressed: _bleService.disconnect,
//               child: const Text('Putuskan'),
//             )
//           else
//             FilledButton(
//               onPressed: isBusy ? null : _bleService.connect,
//               style: FilledButton.styleFrom(
//                 backgroundColor: AppTheme.primaryColor,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 8,
//                 ),
//                 visualDensity: VisualDensity.compact,
//               ),
//               child: Text(isBusy ? 'Memproses...' : 'Hubungkan'),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildErrorPanel(BuildContext context, String message) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
//         borderRadius: BorderRadius.circular(14),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Icon(
//             Icons.warning_amber_rounded,
//             color: Color(0xFFF59E0B),
//             size: 18,
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               message,
//               style: TextStyle(
//                 fontSize: 11,
//                 color: Theme.of(context).colorScheme.onSurface,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyState(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 12),
//         child: Column(
//           children: [
//             Icon(
//               Icons.show_chart,
//               color: Theme.of(context)
//                   .colorScheme
//                   .onSurfaceVariant
//                   .withValues(alpha: 0.5),
//               size: 32,
//             ),
//             const SizedBox(height: 8),
//             Text(
//               _bleService.isConnected
//                   ? 'Menunggu paket pertama dari MPU6050...'
//                   : 'Hubungkan sandal untuk melihat data sensor.',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 11,
//                 color: Theme.of(context).colorScheme.onSurfaceVariant,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildReading(BuildContext context, ImuReading reading) {
//     final receivedAt = _bleService.lastPacketReceivedAt;
//     final timeText = receivedAt == null
//         ? '-'
//         : DateFormat('HH:mm:ss.SSS').format(receivedAt);
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'Paket terakhir',
//               style: TextStyle(
//                 fontSize: 10,
//                 color: Theme.of(context).colorScheme.onSurfaceVariant,
//               ),
//             ),
//             Text(
//               timeText,
//               style: TextStyle(
//                 fontSize: 10,
//                 fontWeight: FontWeight.w600,
//                 color: Theme.of(context).colorScheme.onSurface,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         _buildAxisGroup(
//           context,
//           title: 'Akselerometer',
//           unit: 'm/s²',
//           x: reading.accelX,
//           y: reading.accelY,
//           z: reading.accelZ,
//         ),
//         const SizedBox(height: 18),
//         _buildAxisGroup(
//           context,
//           title: 'Giroskop',
//           unit: '°/s',
//           x: reading.gyroX,
//           y: reading.gyroY,
//           z: reading.gyroZ,
//         ),
//         const SizedBox(height: 16),
//         Container(
//           width: double.infinity,
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//           decoration: BoxDecoration(
//             color: Theme.of(context)
//                 .colorScheme
//                 .surfaceContainerHighest
//                 .withValues(alpha: 0.45),
//             borderRadius: BorderRadius.circular(14),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'Magnitudo percepatan',
//                 style: TextStyle(
//                   fontSize: 11,
//                   color: Theme.of(context).colorScheme.onSurfaceVariant,
//                 ),
//               ),
//               Text(
//                 '${reading.accelerationMagnitude.toStringAsFixed(2)} m/s²',
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                   color: Theme.of(context).colorScheme.onSurface,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildAxisGroup(
//       BuildContext context, {
//         required String title,
//         required String unit,
//         required double x,
//         required double y,
//         required double z,
//       }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text(
//               title,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 12,
//                 color: Theme.of(context).colorScheme.onSurface,
//               ),
//             ),
//             const SizedBox(width: 5),
//             Text(
//               '($unit)',
//               style: TextStyle(
//                 fontSize: 10,
//                 color: Theme.of(context).colorScheme.onSurfaceVariant,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 10),
//         Row(
//           children: [
//             Expanded(child: _buildAxisValue(context, 'X', x)),
//             const SizedBox(width: 8),
//             Expanded(child: _buildAxisValue(context, 'Y', y)),
//             const SizedBox(width: 8),
//             Expanded(child: _buildAxisValue(context, 'Z', z)),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildAxisValue(
//       BuildContext context,
//       String axis,
//       double value,
//       ) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
//       decoration: BoxDecoration(
//         border: Border.all(color: Theme.of(context).dividerColor),
//         borderRadius: BorderRadius.circular(14),
//       ),
//       child: Column(
//         children: [
//           Text(
//             axis,
//             style: const TextStyle(
//               color: AppTheme.primaryColor,
//               fontSize: 10,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 5),
//           FittedBox(
//             child: Text(
//               value.toStringAsFixed(2),
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 14,
//                 color: Theme.of(context).colorScheme.onSurface,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _statusLabel() {
//     switch (_bleService.status) {
//       case EmerysBleStatus.disconnected:
//         return 'TERPUTUS';
//       case EmerysBleStatus.requestingPermission:
//         return 'IZIN';
//       case EmerysBleStatus.scanning:
//         return 'MENCARI';
//       case EmerysBleStatus.connecting:
//         return 'MENGHUBUNGKAN';
//       case EmerysBleStatus.connected:
//         return 'TERHUBUNG';
//       case EmerysBleStatus.error:
//         return 'GAGAL';
//     }
//   }
//
//   String _connectionDescription() {
//     switch (_bleService.status) {
//       case EmerysBleStatus.disconnected:
//         return 'Belum terhubung ke sandal';
//       case EmerysBleStatus.requestingPermission:
//         return 'Meminta izin Bluetooth';
//       case EmerysBleStatus.scanning:
//         return 'Mencari ESP32-C3 di sekitar';
//       case EmerysBleStatus.connecting:
//         return 'Membuka koneksi GATT';
//       case EmerysBleStatus.connected:
//         return 'Menerima notification IMU secara langsung';
//       case EmerysBleStatus.error:
//         return 'Periksa pesan kesalahan di bawah';
//     }
//   }
//
//   Color _statusColor() {
//     switch (_bleService.status) {
//       case EmerysBleStatus.connected:
//         return const Color(0xFF16A34A);
//       case EmerysBleStatus.error:
//         return const Color(0xFFDC2626);
//       case EmerysBleStatus.disconnected:
//         return const Color(0xFF6B7280);
//       case EmerysBleStatus.requestingPermission:
//       case EmerysBleStatus.scanning:
//       case EmerysBleStatus.connecting:
//         return AppTheme.primaryColor;
//     }
//   }
// }
