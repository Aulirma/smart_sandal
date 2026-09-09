// import 'dart:math';
//
// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
//
// import '../services/emerys_ble_service.dart';
// import '../models/sensor.dart';
//
//
// class ImuStepChart extends StatefulWidget {
//
//   const ImuStepChart({
//     super.key,
//   });
//   @override
//   State<ImuStepChart> createState() =>
//       _ImuStepChartState();
// }
//
// class _ImuStepChartState extends State<ImuStepChart> {
//   final List<double> _movementHistory = [];
//   static const int maxData = 20;
//   double calculateMovementScore(
//       SensorData data
//       ){
//
//     final acceleration =
//     sqrt(
//       pow(data.accX, 2) +
//           pow(data.accY, 2) +
//           pow(data.accZ, 2),
//     );
//     final gyro =
//     sqrt(
//       pow(data.gyroX, 2) +
//           pow(data.gyroY, 2) +
//           pow(data.gyroZ, 2),
//     );
//     return (0.7 * acceleration) +
//         (0.3 * gyro);
//
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<SensorData>(
//       stream:
//       EmerysBleService.instance.sensorStream,
//       builder:
//           (context, snapshot){
//         if(snapshot.hasData){
//
//           final value =
//           calculateMovementScore(
//               snapshot.data!
//           );
//           _movementHistory.add(value);
//           if(_movementHistory.length > maxData){
//             _movementHistory.removeAt(0);
//           }
//         }
//
//         return Container(
//           height: 180,
//           padding:
//           const EdgeInsets.all(16),
//
//           decoration:
//           BoxDecoration(
//             color:
//             Theme.of(context)
//                 .cardColor,
//             borderRadius:
//             BorderRadius.circular(24),
//           ),
//           child:
//           Column(
//             crossAxisAlignment:
//             CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Pola Langkah",
//                 style:
//                 TextStyle(
//                   fontSize: 15,
//                   fontWeight:
//                   FontWeight.bold,
//                   color:
//                   Theme.of(context)
//                       .colorScheme
//                       .onSurface,
//                 ),
//               ),
//
//               const SizedBox(height: 15),
//               Expanded(
//                 child:
//                 BarChart(
//                   BarChartData(
//                     maxY: 20,
//                     borderData:
//                     FlBorderData(
//                       show:false,
//                     ),
//                     gridData:
//                     FlGridData(
//                       show:false,
//                     ),
//                     titlesData:
//                     FlTitlesData(
//                       show:false,
//                     ),
//                     barGroups:
//                     List.generate(
//                       _movementHistory.length,
//                           (index){
//                         return BarChartGroupData(
//                           x:index,
//                           barRods:[
//                             BarChartRodData(
//                               toY:
//                               _normalize(
//                                   _movementHistory[index]
//                               ),
//                               width:8,
//                               borderRadius:
//                               BorderRadius.circular(5),
//                               color:
//                               const Color(0xFF2DD4BF),
//                             )
//                           ],
//                         );
//                       },
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   double _normalize(double value){
//     if(value > 20){
//       return 20;
//     }
//     if(value < 0){
//       return 0;
//     }
//     return value;
//   }
// }