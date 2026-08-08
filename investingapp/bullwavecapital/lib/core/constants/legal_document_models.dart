class LegalBlock {
  const LegalBlock({this.paragraphs = const [], this.bullets});

  final List<String> paragraphs;
  final List<String>? bullets;
}

class LegalSection {
  const LegalSection({
    required this.number,
    required this.title,
    required this.blocks,
  });

  final int number;
  final String title;
  final List<LegalBlock> blocks;
}
