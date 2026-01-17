# ![PenPeeper Logo](assets/favicon.ico)  PenPeeper 

> **Streamline Your Penetration Testing Workflow**



## Streamline Your Penetration Testing Workflow
 PenPeeper is a multiplatform organizer and reporting application. Manage engagements, run scans, and generate reports from a central hub.
 PenPeeper allows you to focus on what matters: finding vulnerabilities.
## Available for Windows, Mac, and Linux 


## 🚀 The Philosophy
PenPeeper is built around a logical, left-to-right workflow that mirrors the natural lifecycle of a pentest:
`Gather` -> `Search` -> `Findings` -> `Report`

## ✨ Key Features

-   **Multi-Platform Support**: Available for Windows, Mac, and Linux.
-   **The "Magic Button"**: Automatically add devices and run built-in scans (Nmap, Nikto, FFUF, etc.) with a single click.
-   **Intuitive Workflow**:
    -   **Gather**: Manage devices, import scans/screenshots, and tag assets (e.g., Camera, NAS, Server).
    -   **Search**: Filter by tags, service banners, ports, mac vendors, etc. Use built-in Telnet to probe deeper.
    -   **Findings**: Track "Incomplete" vs "Complete" findings. Ensure all data is captured before reporting.
    -   **Report**: Generate professional PDF reports with custom summary graphics.
-   **Collaboration**: Securely export encrypted project files to share data with teammates.
- **Concurrent Scanning:** Customize how many concurrent scans to run at once.
- **Automated Scanning:** NMap, Nikto, SearchSploit, WhatWeb, Enum4linux, FFUF integration
- **Device Management:** Organize and track discovered devices
- **CVE Findings:** Search and attach CVEs from NVD database.
- **Findings Management:** Review and categorize security findings
- **Report Generation:** Create professional penetration testing reports
- **Customizable Themes:** Multiple themes for your preference.
- **Telnet Client:** Built-in terminal for device interaction.
## 📦 Compiled Downloads

* Download the latest release from the Releases page...

<img src="assets/images/1.webp" alt="Home Tab" >
<img src="assets/images/2.webp" alt="Gather Tab" >
<img src="assets/images/3.webp" alt="Scans Tab" >
<img src="assets/images/4.webp" alt="Search Tab" >
<img src="assets/images/5.webp" alt="Search Tab" >


## 🛠️ How to Use

### If you want to run on Linux without a desktop then run the command:
   ```bash
   ./penpeeper --term
   ```
Then (Navigate to web page at http://YOUR_LINUX_IP:8808/ from another computer.


### 1. Gather
Start by adding your scope.
-   **Magic Button**: Perfect for single network ranges. Adds and scans everything automatically.
-   **Manual Control**: Add devices individually or "Add Device(s)" to populate the list, then scan selected targets at your pace.

### 2. Analyze & Import
-   Drill down into device **Details** or view raw **Scan** results.
-   Import external evidence (screenshots, logs) directly into the device record.

### 3. Flag Findings
-   Found something? Click the red **"Add Flag"** button.
-   This creates an entry in your **Findings** tab for later review.

### 4. Search & Refine
-   Use the **Search** tab to hunt for specific vendors, outdated services, or forgotten endpoints.
-   Use the **Findings** tab to complete the details for every flagged item.

### 5. Report
-   Once findings are complete, head to the **Report** tab.
-   Select a summary graphic, fill in the executive summary using the built-in helper text, and export your polished PDF.


## Build Instructions
[Full flutter project build instructions](BUILD_INSTRUCTIONS.md)

## 🤝 Contributing
Contributions, issues, and feature requests are welcome!

## 📝 License
[License: Apache 2.0 with Commons Clause](License.md)
**What this means:**
- ✅ You can use this for free for personal or professional work.
- ✅ You can modify the code and share those modifications for free.
- ❌ You **cannot** sell this software, or a modified version of it, without explicit permission.
- ❌ You **cannot** host this as a paid service (SaaS).

### brand icons
### [Brand icons created by Pixel perfect - Flaticon](https://www.flaticon.com/free-icons/brand)
