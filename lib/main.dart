import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

import 'e621.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  MyApp({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<PostResponse> postResponse;

  @override
  void initState() {
    super.initState();
    postResponse = fetchPosts();
  }

  Widget buildGridWithRefresh(BuildContext context, PostResponse postResponse) {
    return RefreshIndicator(
        child: PostGridView(postResponse: postResponse),
        onRefresh: () async {
          setState(() {
            this.postResponse = fetchPosts();
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
        home: Scaffold(
            appBar: AppBar(
              title: Text('Index'),
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
                          return SearchView();
                        }));
                      },
                    );
                  },
                ),
              ],
            ),
            body: buildBody(context)));
  }
}

class PostGridView extends StatelessWidget {
  final PostResponse postResponse;

  const PostGridView({Key key, this.postResponse}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
        primary: true,
        padding: const EdgeInsets.all(8),
        crossAxisCount: MediaQuery.of(context).size.width ~/ 160,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: postResponse.posts
            // TODO: this where clause is really weird
            .where((post) => post.bestPreviewURL != null)
            .map<Widget>((post) => PostContainer(post: post))
            .toList());
  }
}

class PostContainer extends StatelessWidget {
  final Post post;
  final bool isLargeView;

  const PostContainer({Key key, this.post, this.isLargeView = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
        imageUrl: isLargeView ? post.file.url : post.bestPreviewURL,
        placeholder: (context, url) => CircularProgressIndicator());

    final hero = Hero(tag: 'post-${post.id}', child: image);

    if (!isLargeView) {
      return Scaffold(
          body: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) {
                  return PostContainer(post: post, isLargeView: true);
                }));
              },
              child: Center(child: hero)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(post.artists.join(", ")),
        actions: <Widget>[
          Builder(builder: (BuildContext context) {
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
          }),
          IconButton(
            icon: Icon(Icons.expand_more),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) {
                return PostDetails(
                  post: post,
                );
              }));
            },
          ),
        ],
      ),
      body: PhotoView(
          imageProvider: CachedNetworkImageProvider(post.file.url),
          heroAttributes: PhotoViewHeroAttributes(tag: 'post-${post.id}'),
          loadingBuilder: (context, event) {
            return Center(
              child: Container(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes,
                ),
              ),
            );
          }),
    );
  }
}

class PostDetails extends StatelessWidget {
  final Post post;

  const PostDetails({Key key, this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(post.id.toString()),
      ),
      body: ListView(
          children: post.tags
              .map<Widget>((tag) => Text('${tag.type} - ${tag.name}'))
              .toList()),
    );
  }
}

class SearchView extends StatefulWidget {
  const SearchView({Key key}) : super(key: key);

  @override
  _SearchViewState createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Search'),
        ),
        body: Container(
          padding: EdgeInsets.all(8),
          child: TextField(
            autocorrect: false,
            autofocus: true,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(labelText: 'Search tags'),
          ),
        ));
  }
}
