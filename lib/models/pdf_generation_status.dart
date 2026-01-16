enum PdfGenerationState {
  idle,
  preparing,
  generating,
  saving,
  completed,
  error,
}

class PdfGenerationStatus {
  final PdfGenerationState state;
  final String message;
  final double progress;
  final String? errorMessage;

  const PdfGenerationStatus({
    required this.state,
    required this.message,
    this.progress = 0.0,
    this.errorMessage,
  });

  factory PdfGenerationStatus.idle() {
    return const PdfGenerationStatus(
      state: PdfGenerationState.idle,
      message: 'Ready to generate PDF',
    );
  }

  factory PdfGenerationStatus.preparing() {
    return const PdfGenerationStatus(
      state: PdfGenerationState.preparing,
      message: 'Preparing report data...',
      progress: 0.1,
    );
  }

  factory PdfGenerationStatus.generating(String section, double progress) {
    return PdfGenerationStatus(
      state: PdfGenerationState.generating,
      message: 'Generating $section...',
      progress: progress,
    );
  }

  factory PdfGenerationStatus.saving() {
    return const PdfGenerationStatus(
      state: PdfGenerationState.saving,
      message: 'Saving PDF file...',
      progress: 0.9,
    );
  }

  factory PdfGenerationStatus.completed(String filePath) {
    return PdfGenerationStatus(
      state: PdfGenerationState.completed,
      message: 'PDF saved: $filePath',
      progress: 1.0,
    );
  }

  factory PdfGenerationStatus.error(String error) {
    return PdfGenerationStatus(
      state: PdfGenerationState.error,
      message: 'Error generating PDF',
      progress: 0.0,
      errorMessage: error,
    );
  }
}
