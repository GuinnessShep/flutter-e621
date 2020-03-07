import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum Rating { safe, questionable, explicit }

class InvalidRatingException implements Exception {
  final String _providedRating;

  InvalidRatingException(this._providedRating);

  String errorMessage() {
    return 'Got unexpected rating value: $_providedRating';
  }
}

Rating parseRating(String rating) {
  switch (rating) {
    case 's':
      return Rating.safe;
    case 'q':
      return Rating.questionable;
    case 'e':
      return Rating.explicit;
  }

  throw InvalidRatingException(rating);
}

class PostResponse {
  final List<Post> posts;

  PostResponse(this.posts);

  factory PostResponse.fromJson(Map<String, dynamic> json) {
    List<Post> posts;

    if (json.containsKey('post')) {
      posts = [Post.fromJson(json['post'])];
    } else {
      posts = json['posts'].map<Post>((post) => Post.fromJson(post)).toList();
    }

    return PostResponse(posts);
  }
}

class Post {
  final int id;
  final String createdAt;
  final Rating rating;
  final PostFile file;
  final PostSample sample;
  final PostPreview preview;
  final List<Tag> tags;

  Post(this.id, this.createdAt, this.rating, this.file, this.sample,
      this.preview, this.tags);

  factory Post.fromJson(Map<String, dynamic> json) {
    final PostFile file = PostFile.fromJson(json['file']);
    assert(file != null);

    final PostSample sample = PostSample.fromJson(json['sample']);
    assert(sample != null);

    final PostPreview preview = PostPreview.fromJson(json['preview']);
    assert(preview != null);

    List<Tag> tags = List();

    json['tags'].forEach((name, tagItems) {
      final tagType = parseTagType(name);
      tagItems.forEach((tagValue) {
        final tag = Tag(tagValue, tagType);
        tags.add(tag);
      });
    });

    return Post(json['id'], json['created_at'], parseRating(json['rating']),
        file, sample, preview, tags);
  }

  String get bestPreviewURL {
    if (sample == null || sample.url == null || isFlash) {
      return preview.url;
    }

    return sample.url;
  }

  bool get isFlash => file.ext == "swf";

  final List<String> _removeArtists = ['conditional_dnp'];
  List<String> get artists {
    return tags.isEmpty
        ? ["unknown"]
        : tags
            .where((tag) => tag.type == TagType.artist)
            .map((tag) => tag.name)
            .where((tag) => !_removeArtists.contains(tag))
            .toList();
  }
}

class PostFile {
  final int width;
  final int height;
  final String ext;
  final int size;
  final String md5;
  final String url;

  PostFile(this.width, this.height, this.ext, this.size, this.md5, this.url);
  PostFile.fromJson(Map<String, dynamic> json)
      : width = json['width'],
        height = json['height'],
        ext = json['ext'],
        size = json['size'],
        md5 = json['md5'],
        url = json['url'];
}

class PostSample {
  final bool has;
  final int height;
  final int width;
  final String url;

  PostSample(this.has, this.height, this.width, this.url);
  PostSample.fromJson(Map<String, dynamic> json)
      : has = json['has'],
        height = json['height'],
        width = json['width'],
        url = json['url'];
}

class PostPreview {
  final int width;
  final int height;
  final String url;

  PostPreview(this.width, this.height, this.url);
  PostPreview.fromJson(Map<String, dynamic> json)
      : width = json['width'],
        height = json['height'],
        url = json['url'];
}

enum TagType {
  general,
  species,
  character,
  copyright,
  artist,
  invalid,
  lore,
  meta
}

class InvalidTagTypeException implements Exception {
  final String providedType;

  InvalidTagTypeException(this.providedType);

  String errorMessage() {
    return 'Unknown provided type: $providedType';
  }
}

TagType parseTagType(String tagType) {
  switch (tagType) {
    case 'general':
      return TagType.general;
    case 'species':
      return TagType.species;
    case 'character':
      return TagType.character;
    case 'copyright':
      return TagType.copyright;
    case 'artist':
      return TagType.artist;
    case 'invalid':
      return TagType.invalid;
    case 'lore':
      return TagType.lore;
    case 'meta':
      return TagType.meta;
  }

  throw InvalidTagTypeException(tagType);
}

class Tag {
  final String name;
  final TagType type;

  Tag(this.name, this.type);
}

class ApiFailureException implements Exception {
  final int statusCode;

  ApiFailureException(this.statusCode);

  String errorMessage() {
    return 'Got invalid status code from API response: $statusCode';
  }
}

Future<PostResponse> fetchPosts([String tags]) async {
  Map<String, String> params = {};
  if (tags != null && tags.isNotEmpty) {
    params['tags'] = tags;
  }
  final uri = Uri.https('e621.net', '/posts.json', params);

  final resp = await http.get(uri);

  if (resp.statusCode == 200) {
    return PostResponse.fromJson(json.decode(resp.body));
  } else {
    throw ApiFailureException(resp.statusCode);
  }
}
