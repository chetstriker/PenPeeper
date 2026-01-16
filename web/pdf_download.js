// PDF download helper for web
window.dartDownloadPdf = function(bytes, filename) {
  console.log('[JS] dartDownloadPdf called, bytes:', bytes.length, 'filename:', filename);
  const blob = new Blob([bytes], { type: 'application/pdf' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  console.log('[JS] Download triggered');
};

// Override Dart function
if (typeof dartPrint !== 'undefined') {
  console.log('[JS] Dart interop ready');
}
