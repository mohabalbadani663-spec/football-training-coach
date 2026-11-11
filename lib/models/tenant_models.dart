class Organization {
  const Organization({required this.id, required this.name, this.slug = ''});
  final String id;
  final String name;
  final String slug;
}

class TeamInfo {
  const TeamInfo({
    required this.id,
    required this.organizationId,
    required this.name,
    this.ageGroup,
    this.level,
    this.memberCount = 0,
    this.joinCode,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? ageGroup;
  final String? level;
  final int memberCount;
  final String? joinCode;
}
