class ImageLoader extends ResourceLoader<ImageElement> {
  final Set<String> _loaded = new Set<String>();

  ImageLoader(Iterable<String> urls) : super(urls);

  void _doLoad(String url) {
    assert(url != null);
    assert(!_resources.containsKey(url));
    final img = new ImageElement(url);
    _resources[url] = img;
    if(img.complete) {
      _loadHandler(url, img);
    } else {
      img.on.load.add((args) {
        final ImageElement img = args.currentTarget;
        assert(_resources.containsValue(img));
        assert(args.type == 'load');
        _loadHandler(url, img);
      });
    }
  }


  void _loadHandler(String originalUrl, ImageElement img) {
    assert(!_loaded.contains(originalUrl));
    _loaded.add(originalUrl);
    _onLoaded(originalUrl);
  }
}
