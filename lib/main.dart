import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_view/photo_view.dart';

import 'e621.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  MyApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext builder) {
    return MaterialApp(
        title: 'e621',
        theme: ThemeData(
            primarySwatch: Colors.indigo,
            accentColor: Colors.indigoAccent,
            brightness: Brightness.light),
        darkTheme: ThemeData(
            primarySwatch: Colors.indigo,
            accentColor: Colors.indigoAccent,
            brightness: Brightness.dark),
        home: SearchIndexView());
  }
}

class SearchIndexView extends StatefulWidget {
  final String search;
  SearchIndexView({Key key, this.search}) : super(key: key);

  @override
  _SearchIndexViewState createState() => _SearchIndexViewState(this.search);
}

class _SearchIndexViewState extends State<SearchIndexView> {
  Future<PostResponse> postResponse;
  String search;

  _SearchIndexViewState(this.search);

  @override
  void initState() {
    super.initState();
    postResponse = fetchPosts(search);
  }

  Widget buildGridWithRefresh(BuildContext context, PostResponse postResponse) {
    return RefreshIndicator(
        child: Container(
            padding: EdgeInsets.all(8),
            child: PostGridView(postResponse: postResponse)),
        onRefresh: () async {
          setState(() {
            this.postResponse = fetchPosts(search);
          });
          await this.postResponse;
        });
  }

  Widget buildBody(BuildContext context) {
    return Center(
      child: FutureBuilder<PostResponse>(
          future: postResponse,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return buildGridWithRefresh(context, snapshot.data);
            } else if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }

            return CircularProgressIndicator();
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(search == null ? 'Index' : search),
          actions: <Widget>[
            Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {},
                );
              },
            ),
            Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) {
                      return SearchView(startingSearch: search);
                    }));
                  },
                );
              },
            ),
          ],
        ),
        body: buildBody(context));
  }
}

class PostGridView extends StatelessWidget {
  final PostResponse postResponse;

  const PostGridView({Key key, this.postResponse}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final posts = postResponse.posts
        .where((post) => post.bestPreviewURL != null && !post.isFlash)
        .toList();

    return StaggeredGridView.countBuilder(
        // primary: true,
        crossAxisCount: 4,
        itemCount: posts.length,
        itemBuilder: (context, index) => PostContainer(post: posts[index]),
        staggeredTileBuilder: (index) => StaggeredTile.fit(2),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8);
  }
}

class PostContainer extends StatelessWidget {
  final Post post;
  final bool isLargeView;

  const PostContainer({Key key, this.post, this.isLargeView = false})
      : super(key: key);

  String get heroTag => 'post-${post.id}';

  Widget smallView(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 24) / 2;
    final ratio = (width / post.sample.width);
    final height = post.sample.height * ratio;

    final image = CachedNetworkImage(
        width: width,
        height: height,
        imageUrl: isLargeView ? post.file.url : post.bestPreviewURL,
        placeholder: (context, url) =>
            Center(child: CircularProgressIndicator()),
        errorWidget: (builder, _url, _err) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Text('Error loading preview')]));

    final hero = Hero(
        tag: heroTag,
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: image));

    return GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) {
            return PostContainer(post: post, isLargeView: true);
          }));
        },
        child: Container(height: height, child: hero));
  }

  void viewDetails(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) {
      return PostDetails(
        post: post,
      );
    }));
  }

  Widget favoritesButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.star_border),
      onPressed: () {
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text('Added to favorites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              Scaffold.of(context).showSnackBar(
                  SnackBar(content: Text('Removed from favorites')));
            },
          ),
        ));
      },
    );
  }

  Widget loadingBuilder(BuildContext context, ImageChunkEvent event) {
    return Center(
      child:
          Container(width: 20, height: 20, child: CircularProgressIndicator()),
    );
  }

  Widget largeView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(post.artists.join(", ")),
        actions: <Widget>[
          Builder(builder: favoritesButton),
          IconButton(
            icon: Icon(Icons.expand_more),
            onPressed: () => viewDetails(context),
          ),
        ],
      ),
      body: PhotoView(
          imageProvider: CachedNetworkImageProvider(post.file.url),
          heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
          loadingBuilder: loadingBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLargeView) {
      return largeView(context);
    } else {
      return smallView(context);
    }
  }
}

class PostDetails extends StatelessWidget {
  final Post post;

  const PostDetails({Key key, this.post}) : super(key: key);

  Widget sectionHeading(BuildContext context, String heading) {
    return Padding(
        child: Text(heading, style: Theme.of(context).textTheme.headline5),
        padding: EdgeInsets.only(top: 8));
  }

  void showSheet(BuildContext context, Tag tag) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Container(
              child: SafeArea(
                  child: Wrap(
            children: <Widget>[
              ListTile(
                  title: Center(
                      child: Text(tag.name,
                          style: Theme.of(context).textTheme.headline4))),
              ListTile(
                  leading: Icon(Icons.search),
                  title: Text('Search for this tag'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) {
                      return SearchIndexView(search: tag.name);
                    }));
                  }),
              ListTile(
                  leading: Icon(Icons.block),
                  title: Text('Blacklist this tag')),
            ],
          )));
        });
  }

  TextSpan tagTextSpan(BuildContext context, Tag tag) {
    return TextSpan(
        text: tag.name + ' ',
        recognizer: (TapGestureRecognizer()
          ..onTap = () => showSheet(context, tag)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(post.id.toString()),
        ),
        body: Container(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(children: [
            sectionHeading(context, 'Tags'),
            RichText(
                text: TextSpan(
                    children: post.tags
                        .map<TextSpan>((tag) => tagTextSpan(context, tag))
                        .toList())),
            sectionHeading(context, 'MD5'),
            Text(post.file.md5),
            sectionHeading(context, 'File Type'),
            Text(post.file.ext),
          ], crossAxisAlignment: CrossAxisAlignment.start),
        ));
  }
}

class SearchView extends StatefulWidget {
  final String startingSearch;

  const SearchView({Key key, this.startingSearch}) : super(key: key);

  @override
  _SearchViewState createState() => _SearchViewState(startingSearch);
}

class _SearchViewState extends State<SearchView> {
  final String startingSearch;
  _SearchViewState(this.startingSearch);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Search'),
        ),
        body: Container(
          padding: EdgeInsets.all(8),
          child: TextField(
            controller: TextEditingController()
              ..text =
                  startingSearch == null ? '' : startingSearch.trim() + ' ',
            autocorrect: false,
            autofocus: true,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(labelText: 'Search tags'),
            onEditingComplete: () {},
            onSubmitted: (search) {
              if (search.isEmpty) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) {
                  return SearchIndexView(search: search);
                }));
              }
            },
          ),
        ));
  }
}
