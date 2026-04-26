class MainGroup {
  final int groupId;
  final String groupName;
  final String groupDescription;

  MainGroup({
    required this.groupId,
    required this.groupName,
    required this.groupDescription,
  });

  factory MainGroup.fromJson(Map<String, dynamic> json) {
    return MainGroup(
      groupId: int.parse(json['group_id'].toString()),
      groupName: json['group_name'] ?? "",
      groupDescription: json['group_description'] ?? "",
    );
  }
}
