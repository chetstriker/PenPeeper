import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CveRow extends StatelessWidget {
  final Map<String, dynamic> cve;

  const CveRow({super.key, required this.cve});

  @override
  Widget build(BuildContext context) {
    final cveId = cve['cve_id'];
    final url = 'https://vulners.com/githubexploit/$cveId';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        children: [
          if (cve['cvss'] != null && cve['cvss'] > 0)
            Text(
              '(CVSS: ${cve['cvss']}) ',
              style: TextStyle(
                color: _getCvssColor(cve['cvss']),
                fontWeight: FontWeight.w500,
              ),
            ),
          if (cve['is_exploit'] == 1)
            const Text(
              '[EXPLOIT AVAILABLE] ',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          SelectableText(
            '$cveId ',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          InkWell(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Text(
              url,
              style: const TextStyle(
                color: Color(0xFF4FC3F7),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCvssColor(double cvss) {
    if (cvss >= 9.0) return Colors.red;
    if (cvss >= 7.0) return Colors.orange;
    if (cvss >= 4.0) return Colors.yellow;
    return Colors.green;
  }
}
