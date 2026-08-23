class InstitutionBranding {
  const InstitutionBranding({
    this.displayName = '',
    this.tagline = '',
    this.primaryColor = '',
    this.logoUrl = '',
    this.backgroundUrl = '',
  });

  final String displayName;
  final String tagline;
  final String primaryColor;
  final String logoUrl;
  final String backgroundUrl;

  factory InstitutionBranding.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const InstitutionBranding();
    return InstitutionBranding(
      displayName: data['displayName'] as String? ?? '',
      tagline: data['tagline'] as String? ?? '',
      primaryColor: data['primaryColor'] as String? ?? '',
      logoUrl: data['logoUrl'] as String? ?? '',
      backgroundUrl: data['backgroundUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'tagline': tagline,
    'primaryColor': primaryColor,
    'logoUrl': logoUrl,
    'backgroundUrl': backgroundUrl,
  };
}

class Institution {
  const Institution({
    required this.id,
    required this.name,
    this.branding = const InstitutionBranding(),
  });

  final String id;
  final String name;
  final InstitutionBranding branding;

  factory Institution.fromMap(String id, Map<String, dynamic> data) {
    return Institution(
      id: id,
      name: data['name'] as String? ?? '',
      branding: InstitutionBranding.fromMap(
        data['branding'] as Map<String, dynamic>?,
      ),
    );
  }
}
