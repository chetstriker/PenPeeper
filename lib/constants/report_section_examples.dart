class ReportSectionExamples {
  static const String executiveSummaryDescription = 'This is the most crucial part for high-level decision-makers. It should be concise and non-technical. Include: Objective and Scope (briefly state what was tested), Overall Risk/Security Posture (clear assessment), Key Findings (top 3-5 critical issues), Strategic Recommendations (high-level actions), and Time/Effort Metrics (test duration and constraints).';

  static const String methodologyScopeDescription = 'This section explains how the test was performed, providing context and credibility. Include: Scope (detailed list of systems, IPs, subnets in/out of scope), Approach (test type and methodologies used), Timeline (start and finish dates), and Limitations (any constraints).';

  static const String riskRatingModelDescription = 'Explain the logic behind your risk scores. Describe the rating scale (Critical, High, Medium, Low, Informational) and define what each level means in terms of Likelihood of exploitation and the resulting Impact on the business.';

  static const String conclusionDescription = 'A brief summary reiterating the overall security posture and encouraging timely remediation. Include key takeaways, priority actions, long-term recommendations, and follow-up assessment plans.';

  static const String executiveSummary = '''
This penetration test assessed the security posture of XYZ Corporation's internal network infrastructure from October 15-20, 2024. The assessment identified significant security vulnerabilities that pose a HIGH RISK to the organization's data and operations.

Key Findings:
• Critical: Unpatched Windows Server 2012 systems vulnerable to remote code execution (CVE-2019-0708)
• High: Weak password policies allowing brute-force attacks on 15 user accounts
• High: Misconfigured firewall rules exposing internal services to the internet
• Medium: Outdated SSL/TLS configurations on web servers
• Medium: Missing security patches on 40% of workstations

Strategic Recommendations:
1. Implement immediate patching program for critical vulnerabilities
2. Deploy Multi-Factor Authentication (MFA) across all user accounts
3. Conduct comprehensive firewall rule audit and remediation
4. Establish regular vulnerability scanning and patch management processes
5. Provide security awareness training for all staff

The testing was conducted over 5 business days with minimal disruption to operations. Immediate action is required to address critical findings within 30 days.''';

  static const String methodologyScope = '''
Scope:
This assessment covered the following systems and networks:
• Internal network: 192.168.1.0/24, 192.168.10.0/24
• Web applications: portal.example.com, admin.example.com
• Database servers: 3 SQL Server instances
• Active Directory domain controllers: 2 servers
• Out of scope: Production payment processing systems, third-party SaaS applications

Testing Approach:
• Type: Gray-Box Assessment (network diagrams and non-privileged credentials provided)
• Methodology: OWASP Testing Guide v4, NIST SP 800-115, MITRE ATT&CK Framework
• Tools: Nmap, Metasploit, Burp Suite Professional, Nikto, SQLMap, Bloodhound

Timeline:
• Reconnaissance and Scanning: October 15-16, 2024
• Vulnerability Assessment: October 17-18, 2024
• Exploitation and Post-Exploitation: October 19-20, 2024
• Reporting: October 21-22, 2024

Limitations:
• Testing restricted to non-business hours (6 PM - 6 AM) to minimize operational impact
• Denial-of-service attacks were not performed
• Social engineering and physical security testing were excluded
• Read-only access provided to domain controllers (no privilege escalation testing)''';

  static const String riskRatingModelDelta = '''[
  {"insert": {"image": "risk.png"}},
  {"insert": "\n"}
]''';

  static const String riskRatingModel = '''
This report uses the Common Vulnerability Scoring System (CVSS) v3.1 as the foundation for risk ratings, combined with business impact assessment.

Severity Levels:

CRITICAL (CVSS 9.0-10.0)
• Likelihood: Easily exploitable with publicly available tools
• Impact: Complete system compromise, data breach, or business disruption
• Action Required: Immediate remediation within 24-48 hours
• Examples: Unauthenticated remote code execution, default credentials on critical systems

HIGH (CVSS 7.0-8.9)
• Likelihood: Exploitable with moderate skill level
• Impact: Significant data exposure, privilege escalation, or service disruption
• Action Required: Remediation within 7-14 days
• Examples: SQL injection, authentication bypass, unpatched critical vulnerabilities

MEDIUM (CVSS 4.0-6.9)
• Likelihood: Requires specific conditions or authenticated access
• Impact: Limited data exposure or system access
• Action Required: Remediation within 30-60 days
• Examples: Cross-site scripting (XSS), information disclosure, weak encryption

LOW (CVSS 0.1-3.9)
• Likelihood: Difficult to exploit or requires significant resources
• Impact: Minimal security impact
• Action Required: Remediation within 90 days or next maintenance window
• Examples: Missing security headers, verbose error messages

INFORMATIONAL (CVSS 0.0)
• Likelihood: Not directly exploitable
• Impact: No immediate security impact but represents security best practice
• Action Required: Consider for future security improvements
• Examples: Security recommendations, hardening suggestions

Risk Calculation:
Final risk rating considers:
1. CVSS base score
2. Exploitability (availability of public exploits)
3. Business criticality of affected systems
4. Potential for lateral movement or privilege escalation
5. Regulatory compliance requirements''';

  static const String conclusion = '''
The penetration test of XYZ Corporation's infrastructure revealed significant security vulnerabilities that require immediate attention. The overall security posture is assessed as HIGH RISK due to the presence of critical vulnerabilities that could lead to complete system compromise.

Key Takeaways:
• 5 Critical vulnerabilities require immediate remediation
• 12 High-severity issues pose significant risk to business operations
• Lack of consistent patch management is the primary security gap
• Network segmentation is insufficient to contain potential breaches
• Security monitoring and incident response capabilities need enhancement

Priority Actions:
1. Address all Critical findings within 48 hours
2. Implement emergency patching for CVE-2019-0708 (BlueKeep)
3. Deploy MFA for all administrative accounts immediately
4. Conduct firewall rule audit and remediation within 7 days
5. Establish formal vulnerability management program

Long-term Recommendations:
• Implement Security Information and Event Management (SIEM) solution
• Conduct quarterly vulnerability assessments
• Establish security awareness training program
• Develop and test incident response procedures
• Consider implementing Zero Trust network architecture

The security team demonstrated strong cooperation throughout the assessment. With proper resource allocation and management commitment, the identified vulnerabilities can be effectively remediated. We recommend conducting a follow-up assessment in 90 days to verify remediation efforts and assess overall security improvement.

For questions or clarification regarding any findings in this report, please contact the assessment team.''';
}
