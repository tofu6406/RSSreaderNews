import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // ここでhttpをインポート
import 'package:ogp_data_extract/ogp_data_extract.dart';
import 'package:webfeed_plus/domain/rss_feed.dart';
import 'package:webfeed_plus/domain/rss_item.dart';
import 'webview_screen.dart'; // 依存関係に応じてパスを修正してください

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<RssItem> _newsItems = [];  // 全ニュース項目
  List<RssItem> _filteredNewsItems = [];  // フィルタされたニュース項目
  bool _isLoading = true;
  String _searchKeyword = '';  // 検索キーワード
  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
    });

    const rssUrl =
       'https://api.allorigins.win/get?url=https://news.yahoo.co.jp/rss/topics/top-picks.xml';
    // const rssUrl = 'https://api.allorigins.win/get?url=https://news.yahoo.co.jp/rss/media/gifuweb/all.xml';


    try {
      final response = await http.get(Uri.parse(rssUrl)); // 正しいhttp参照
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final content = json['contents'] as String;

        final decodedContent =
            content.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
        final feed = RssFeed.parse(decodedContent);

        setState(() {
          _newsItems = feed.items ?? [];
          _filteredNewsItems = _newsItems;  // 初期は全て表示
        });
      } else {
        throw Exception('Failed to load RSS feed');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 検索フィルタリング
  void _filterNews(String keyword) {
    setState(() {
      _searchKeyword = keyword;
      if (keyword.isEmpty) {
        // キーワードが空なら全ニュースを表示
        _filteredNewsItems = _newsItems;
      } else {
        // キーワードで部分一致フィルタリング
        _filteredNewsItems = _newsItems.where((item) {
          final title = item.title?.toLowerCase() ?? '';
          final description = item.description?.toLowerCase() ?? '';
          final lowerKeyword = keyword.toLowerCase();

          print('Title: $title');  // タイトルを確認
          print('Description: $description');  // 説明を確認

          return title.contains(lowerKeyword) || description.contains(lowerKeyword);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'ニュースを検索',
          ),
          onChanged: _filterNews,  // ユーザーの入力に基づいてフィルタリング
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _filterNews(_searchKeyword);  // 検索ボタンを押したときにフィルタリング
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredNewsItems.isEmpty
            ? const Center(
              child: Text('結果が見つかりませんでした'),
            )
          : ListView.builder(
              itemCount: _filteredNewsItems.length,
              itemBuilder: (context, index) {
                final item = _filteredNewsItems[index];
                return FutureBuilder<OgpData?>(
                  future: _fetchOgpData(item.link),
                  builder: (context, snapshot) {
                    final ogpData = snapshot.data;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 5.0),
                      child: InkWell(
                        onTap: () => _openArticle(item.link),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10.0),
                                topRight: Radius.circular(10.0),
                              ),
                              child: ogpData?.image != null
                                  ? Image.network(
                                      ogpData!.image!,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.article,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8.0),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ogpData?.title ?? item.title ?? 'No title',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    ogpData?.description ??
                                        item.pubDate?.toLocal().toString() ??
                                        '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<OgpData?> _fetchOgpData(String? url) async {
    if (url == null) return null;
    try {
      return await OgpDataExtract.execute(url);
    } catch (e) {
      print('Failed to fetch OGP data: $e');
      return null;
    }
  }

  void _openArticle(String? url) {
    if (url != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewScreen(url: url),
        ),
      );
    }
  }
}
