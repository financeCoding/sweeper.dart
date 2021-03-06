class TextureAnimationElement extends PElement {
  final List<TextAniRequest> _requests = new List<TextAniRequest>();

  TextureAnimationElement(num width, num height) :
    super(width, height);

  void add(TextAniRequest request) {
    assert(request != null);
    assert(request.fresh);
    _requests.add(request);
    invalidateDraw();
  }

  void update() {

    var toRemove = new List<TextAniRequest>();
    for(final r in _requests) {
      r.update();
      assert(!r.fresh);
      if(r.done) {
        toRemove.add(r);
      }
    }

    for(final r in toRemove) {
      final i = _requests.indexOf(r, 0);
      assert(i >= 0);
      _requests.removeRange(i, 1);
    }

    if(_requests.length > 0) {
      invalidateDraw();
    }
  }

  void drawOverride(CanvasRenderingContext2D ctx) {
    for(final r in _requests) {
      r.drawOverride(ctx);
    }
  }
}

class TextAniRequest {
  final EventHandle<EventArgs> _startEventHandle = new EventHandle<EventArgs>();
  final String _texturePrefix;
  final int _frameCount;
  final Coordinate _offset;
  final int _delay;
  final String _initialFrame;
  final Coordinate _initialFrameOffset;

  bool _done = false;
  int _frame = null;

  TextAniRequest(this._texturePrefix, this._frameCount,
      this._offset, {int delay: 0, int startFrame: 0,
    String initialFrame: null, Coordinate initialFrameOffset: null}) :
      this._delay = delay,
      this._initialFrame = initialFrame,
      this._initialFrameOffset = initialFrameOffset {
    assert(_delay >= 0);
    assert(_texturePrefix != null);
    assert(_frameCount > 0);
    assert(_offset.isValid);
  }

  bool get fresh => _frame == null;
  bool get done => _done;

  EventRoot<EventArgs> get started => _startEventHandle;

  void update() {
    if(_frame == null) {
      _frame = -_delay;
    } else if(_frame < (_frameCount - 1)){
      _frame++;
      assert(_frame < _frameCount);
    } else {
      _done = true;
    }

    if(_frame == 0 && !_done) {
      _startEventHandle.fireEvent(EventArgs.empty);
    }
  }

  void drawOverride(CanvasRenderingContext2D ctx) {
    var frameName;
    var offset = _offset;
    if(_frame < 0 && _initialFrame != null) {
      frameName = _initialFrame;
      if(_initialFrameOffset != null) {
        offset = _initialFrameOffset;
      }
    } else {

      // if we're delayed (_frame < 0), then draw frame 0
      final frame = (_frame < 0) ? 0 : _frame;

      var frameString = frame.toInt().toString();
      while(frameString.length < 4) {
        frameString = "0$frameString";
      }

      frameName = "${_texturePrefix}_$frameString.png";
    }

    ctx.save();
    ctx.translate(offset.x, offset.y);
    drawTextureKeyAt(ctx, frameName);
    ctx.restore();
  }
}
