class GlassVariant {
  final int index;
  final String name;
  final String description;

  const GlassVariant({
    required this.index,
    required this.name,
    required this.description,
  });

  static const List<GlassVariant> collection = [
    GlassVariant(index: 0, name: "Standard", description: "Kính tiêu chuẩn, cân bằng."),
    GlassVariant(index: 1, name: "Super Clear", description: "Trong suốt tuyệt đối, ít phản xạ."),
    GlassVariant(index: 2, name: "Reflective", description: "Phản quang mạnh như gương."),
    GlassVariant(index: 3, name: "Frosted", description: "Mờ phun cát, che khuyết điểm."),
    GlassVariant(index: 4, name: "Prism", description: "Tán sắc cầu vồng ở viền."),
    GlassVariant(index: 5, name: "Ocean Blue", description: "Ám xanh biển sâu."),
    GlassVariant(index: 6, name: "Amber Gold", description: "Vàng hổ phách cổ điển."),
    GlassVariant(index: 7, name: "Acrylic", description: "Nhựa bóng, phản xạ mềm."),
    GlassVariant(index: 8, name: "Smoked Dark", description: "Kính đen, ngầu, che icon."),
    GlassVariant(index: 9, name: "Apple Liquid", description: "Chất lỏng, bóng bẩy, cao cấp."),
  ];
}