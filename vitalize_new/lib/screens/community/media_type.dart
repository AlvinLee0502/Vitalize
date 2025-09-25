enum MediaType {
  image,
  video;

  bool get isImage => this == MediaType.image;
  bool get isVideo => this == MediaType.video;
}