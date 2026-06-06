import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class TorrentCell extends StatelessWidget {
  final Map<String, dynamic> torrent;

  const TorrentCell({super.key, required this.torrent});

  @override
  Widget build(BuildContext context) {
    // 根据 qBit 的 state 字段动态决定颜色和状态文本
    String state = torrent['state'] ?? 'unknown';
    Color color = CupertinoColors.systemGrey;
    String statusText = state;

    if (state.contains('downloading')) { color = CupertinoColors.activeBlue; statusText = "下载中"; }
    else if (state.contains('stalled')) { color = CupertinoColors.systemOrange; statusText = "停滞"; }
    else if (state.contains('uploading')) { color = CupertinoColors.systemGreen; statusText = "做种中"; }

    double progress = (torrent['progress'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(torrent['name'] ?? '未知任务', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CupertinoColors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${(progress * 100).toStringAsFixed(1)}%", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(statusText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            padding: EdgeInsets.zero,
            lineHeight: 6.0,
            percent: progress,
            barRadius: const Radius.circular(3),
            progressColor: color,
            backgroundColor: CupertinoColors.systemGrey6,
          ),
        ],
      ),
    );
  }
}