import 'package:flutter/material.dart';

class PantauPage extends StatelessWidget {
  final VoidCallback? onBackPressed;

  const PantauPage({super.key, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (onBackPressed != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: onBackPressed,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (onBackPressed != null) const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pemantauan Langsung',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Data langsung dari sandal pintar',
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.circle, color: Colors.green, size: 8),
                      SizedBox(width: 6),
                      Text(
                        'Langsung',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Status Card
            _buildPantauStatusCard(),
            const SizedBox(height: 24),
            // Lokasi Langsung Card
            _buildPantauLocationCard(),
            const SizedBox(height: 24),
            // Pola Langkah Card
            _buildPantauStepPatternCard(),
            const SizedBox(height: 24),
            // Intensitas Gerakan Card
            _buildPantauIntensityCard(),
            const SizedBox(height: 24),
            // Peringatan Terbaru Card
            _buildPantauAlertsCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPantauStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_walk, color: Color(0xFF0D9488), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Saat Ini',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const Text(
                    'Berjalan Normal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPillButton('Normal', true),
              const SizedBox(width: 8),
              _buildPillButton('Tidak Stabil', false),
              const SizedBox(width: 8),
              _buildPillButton('Risiko Jatuh', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton(String label, bool isActive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF0FDFA) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF2DD4BF) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? const Color(0xFF0D9488) : Colors.grey[500],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPantauLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.location_on_outlined, color: Color(0xFF0D9488), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Lokasi Langsung',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.grey[400], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Jejak Aktif',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Center(
                  child: CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: TrackPainter(),
                  ),
                ),
                const Positioned(
                  top: 60,
                  left: 150,
                  child: Icon(Icons.location_on, color: Color(0xFF0D9488), size: 32),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.circle, color: Colors.green, size: 6),
                        SizedBox(width: 4),
                        Text(
                          'LANGSUNG',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.near_me, size: 12, color: Color(0xFF0D9488)),
                          SizedBox(width: 4),
                          Text(
                            'Nenek Aishah',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        'Taman Sri Muda, Shah Alam',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Text(
                    '3.1390°N\n101.6869°E',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn('Jarak', '1,2 km'),
              _buildMetricColumn('Durasi', '28 menit'),
              _buildMetricColumn('Kecepatan', '2,6 km/j'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildPantauStepPatternCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.insights, color: Color(0xFF0D9488), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Pola Langkah',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Text(
                '30 menit terakhir',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(20, (index) {
                final double height = (10 + (index % 5) * 15 + (index % 3) * 20).toDouble().clamp(30, 100);
                return Container(
                  width: 8,
                  height: height,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF).withValues(alpha: index == 12 ? 1.0 : 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30 menit lalu', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
              Text('Sekarang', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPantauIntensityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt, color: Color(0xFF0D9488), size: 18),
              SizedBox(width: 8),
              Text(
                'Intensitas Gerakan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildIntensityRow('Kaki Kiri', 0.62, '62%'),
          const SizedBox(height: 16),
          _buildIntensityRow('Kaki Kanan', 0.58, '58%'),
          const SizedBox(height: 16),
          _buildIntensityRow('Skor Keseimbangan', 0.85, '85%'),
        ],
      ),
    );
  }

  Widget _buildIntensityRow(String label, double value, String percentage) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Text(percentage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.grey[100],
            color: const Color(0xFF2DD4BF),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildPantauAlertsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 8),
              Text(
                'Peringatan Terbaru',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPantauAlertItem(
            'Ketidakstabilan sesaat terdeteksi',
            '09:15  •  Dekat area pasar',
            const Color(0xFFFFF7ED),
          ),
          const SizedBox(height: 12),
          _buildPantauAlertItem(
            'Risiko jatuh meningkat selama 10 menit',
            'Kemarin  •  Taman rumah',
            const Color(0xFFFFF7ED),
          ),
        ],
      ),
    );
  }

  Widget _buildPantauAlertItem(String title, String subtitle, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D9488).withValues(alpha: 0.4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(50, 120);
    path.quadraticBezierTo(100, 100, 150, 80);
    path.quadraticBezierTo(200, 60, 250, 70);
    path.lineTo(300, 50);

    const double dashWidth = 8;
    const double dashSpace = 6;
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }

    final endpointPaint = Paint()
      ..color = const Color(0xFF0D9488)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(300, 50), 4, endpointPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
