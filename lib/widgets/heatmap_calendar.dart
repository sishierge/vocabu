import 'package:flutter/material.dart';

class HeatmapCalendar extends StatelessWidget {
  final Map<DateTime, int> data; // date -> minutes
  final int months;

  const HeatmapCalendar({
    super.key,
    required this.data,
    this.months = 6,
  });

  @override
  Widget build(BuildContext context) {
    // End date is today
    final now = DateTime.now();
    // Start date is roughly months ago, aligned to Sunday to ensure nice grid
    // Actually standard contribution graphs start on Sunday/Monday.
    // Let's ensure we show the last 'months' months.
    final startDate = DateTime(now.year, now.month - months + 1, 1);
    
    // Adjust start date to previous Sunday (or Monday based on locale, let's stick to Monday as per image '一')
    // Image shows '一' (Monday) at top? No, usually '日' (Sun) or 'Mon'.
    // Image labels: 一, 三, 五, 日 (Mon, Wed, Fri, Sun).
    // This implies the grid rows correspond to days of week.
    // Standard is 7 rows.
    // Row 0 = Mon, Row 1 = Tue... Row 6 = Sun?
    // Or Row 0 = Sun?
    // Image has '一' (Mon) as first label. So Row 0 is Monday.
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scrollable Heatmap
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Start from right (latest date)
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Labels (Sticky left? No, let's scroll them or keep them outside)
                // Better to keep them outside the scroll view if possible, or inside.
                // Keeping inside for simplicity of alignment first.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(height: 20), // Space for month labels
                    ...List.generate(7, (index) {
                      // 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun
                      final label = index % 2 == 0 ? ['一', '三', '五', '日'][index ~/ 2] : ''; 
                      return Container(
                        height: 12,
                        margin: const EdgeInsets.only(bottom: 3),
                        alignment: Alignment.centerRight,
                        child: Text(
                          label,
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(width: 8),
                
                // The Grid
                _buildGridWithMonths(startDate, now),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('少', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              const SizedBox(width: 6),
              ...List.generate(5, (level) => Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _getColor(level),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
              const SizedBox(width: 6),
              Text('多', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridWithMonths(DateTime start, DateTime end) {
    final firstMonday = start.subtract(Duration(days: start.weekday - 1));
    final lastSunday = end.add(Duration(days: 7 - end.weekday));
    final totalDays = lastSunday.difference(firstMonday).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(totalWeeks, (weekIndex) {
        final mondayOfWeek = firstMonday.add(Duration(days: weekIndex * 7));
        
        // Determine Month Label
        String? monthLabel;
        if (mondayOfWeek.day <= 7) { 
           monthLabel = '${mondayOfWeek.month}月';
        }
        
        return Column(
          children: [
            // Label slot
            Container(
              height: 20,
              width: 15,
              padding: const EdgeInsets.only(bottom: 4),
              alignment: Alignment.bottomLeft,
              child: monthLabel != null 
                  ? Text(monthLabel, style: TextStyle(fontSize: 10, color: Colors.grey[400]), softWrap: false, overflow: TextOverflow.visible) 
                  : null,
            ),
            
            // Days
            ...List.generate(7, (dayIndex) {
               final date = mondayOfWeek.add(Duration(days: dayIndex));
               final minutes = data[DateTime(date.year, date.month, date.day)] ?? 0;
               final level = _getLevel(minutes);
               
               // Hide future dates?
               final isFuture = date.isAfter(end);
               
               return Tooltip(
                 message: '${date.month}月${date.day}日: $minutes分钟',
                 child: Container(
                   width: 12,
                   height: 12,
                   margin: const EdgeInsets.only(bottom: 3, right: 3),
                   decoration: BoxDecoration(
                     color: isFuture ? Colors.transparent : _getColor(level),
                     borderRadius: BorderRadius.circular(2),
                   ),
                 ),
               );
            }),
          ],
        );
      }),
    );
  }

  int _getLevel(int minutes) {
    if (minutes == 0) return 0;
    if (minutes < 15) return 1;
    if (minutes < 30) return 2;
    if (minutes < 60) return 3;
    return 4;
  }

  static Color _getColor(int level) {
    // Ant Design Blue Palette (Geomancy)
    switch (level) {
      case 0: return const Color(0xFFF0F0F0);
      case 1: return const Color(0xFFBAE7FF);
      case 2: return const Color(0xFF69C0FF);
      case 3: return const Color(0xFF1890FF);
      case 4: return const Color(0xFF0050B3);
      default: return const Color(0xFFF0F0F0);
    }
  }
}
