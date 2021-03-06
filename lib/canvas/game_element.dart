class GameElement extends ElementParentImpl {
  static const _edgeOffset = 32;
  static const _backgroundSize = const Size(2048, 1536);
  static const _backgroundHoleSize = 16 * SquareElement._size + 2 * _edgeOffset;
  static const _boardOffset = const Vector(352, 96);
  static const _popExplodeAnimationOffset = const Vector(-88, -88);
  static const _popAnimationHitFrame = 12;

  static const _dartAnimationOffset =
      const Vector(-512 + 0.5 * SquareElement._size,
          -388 + 0.5 * SquareElement._size);

  final PCanvas _canvas = new PCanvas(0, 0);
  final GameBackgroundElement _background = new GameBackgroundElement();
  final BoardElement _boardElement = new BoardElement();
  final ScoreElement _scoreElement = new ScoreElement();
  final NewGameElement _newGameElement = new NewGameElement();
  final GameTitleElement _titleElement = new GameTitleElement();
  final TextureAnimationElement
    _popAnimationLayer = new TextureAnimationElement(0, 0),
    _dartAnimationLayer = new TextureAnimationElement(0, 0);
  final bool _targetMode;
  final EventHandle _targetChanged = new EventHandle();

  int _targetX, _targetY;
  double _scale;
  Vector _scaledBoardOffset;

  Game _game;

  GameElement(this._targetMode) : super(100, 100) {
    _canvas.registerParent(this);
    _canvas.addElement(_background);
    _canvas.addElement(_boardElement);
    _canvas.addElement(_titleElement);
    _canvas.addElement(_newGameElement);
    _canvas.addElement(_scoreElement);
    _canvas.addElement(_popAnimationLayer);
    _canvas.addElement(_dartAnimationLayer);
  }

  EventRoot<EventArgs> get newGameClick => _newGameElement.clicked;

  Game get game => _game;

  void set game(Game value) {
    _game = value;
    if(value == null) {
      size = const Size(100, 100);
    } else {
      _updateSize(value.field.width, value.field.height);
    }
  }

  bool get canRevealTarget =>
      _targetX != null && _game.canReveal(_targetX, _targetY);

  bool get canFlagTarget =>
      _targetX != null && _game.canToggleFlag(_targetX, _targetY);

  void revealTarget() {
    if(_targetX != null) {
      game.reveal(_targetX, _targetY);
      _target(null, null);
    }
  }

  void toggleTargetFlag() {
    if(_targetX != null) {
      final success = _toggleFlag(_targetX, _targetY);
      if(success) {
        _target(null, null);
      }
    }
  }

  EventRoot get targetChanged => _targetChanged;

  int get visualChildCount => 1;

  PElement getVisualChild(int index) {
    assert(index == 0);
    return _canvas;
  }

  void update() {
    super.update();
    final offset = _scaledBoardOffset +
        const Coordinate(_edgeOffset, _edgeOffset);

    _canvas.setTopLeft(_boardElement, offset);
    _canvas.setTopLeft(_popAnimationLayer, offset);
    _canvas.setTopLeft(_dartAnimationLayer, offset);

    // score offset
    // end of the board - score width
    final x = _scale * (_backgroundSize.width - _boardOffset.x - _scoreElement.width);

    _canvas.setTopLeft(_scoreElement, new Coordinate(x, 0));
    _canvas.getChildTransform(_scoreElement).scale(_scale, _scale);

    final newGameTopLeft = new Coordinate(
        (_boardOffset.x + _newGameElement.width * 0.2) * _scale, 0);
    _canvas.setTopLeft(_newGameElement, newGameTopLeft);
    _canvas.getChildTransform(_newGameElement).scale(_scale, _scale);

    final titleMultiplier = 1.7;
    final titleTopLeft = new Coordinate(_scale * 0.5 * (_backgroundSize.width -
        _titleElement.width * titleMultiplier), 0);
    _canvas.setTopLeft(_titleElement, titleTopLeft);
    _canvas.getChildTransform(_titleElement)
      .scale(titleMultiplier * _scale, titleMultiplier * _scale);
  }

  void drawOverride(CanvasRenderingContext2D ctx) {
    // draw children via super
    super.drawOverride(ctx);

    // draw target element
    _drawTarget(ctx);
 }

  void _drawTarget(CanvasRenderingContext2D ctx) {
    assert((_targetX == null) == (_targetY == null));
    if(_targetX != null) {
      final halfSize = SquareElement._size * 0.5;
      var targetLoc = new Vector(_targetX, _targetY);
      targetLoc = targetLoc.scale(SquareElement._size);

      ctx.fillStyle = 'rgba(255, 0, 0, 0.5)';
      CanvasUtil.centeredCircle(ctx,
          targetLoc.x + halfSize, targetLoc.y + halfSize, halfSize);
      ctx.fill();
    }
  }

  void _startPopAnimation(Coordinate start, [Iterable<Coordinate> reveals = null]) {
    if(reveals == null) {
      assert(game.state == GameState.lost);
      reveals = new NumberEnumerable.fromRange(0, game.field.length)
          .select((i) {
            final t = game.field.getCoordinate(i);
            final c = new Coordinate(t.Item1, t.Item2);
            return new Tuple(c, game.getSquareState(c.x, c.y));
          })
          .where((t2) => t2.Item2 == SquareState.mine || t2.Item2 == SquareState.hidden)
          .select((t2) => t2.Item1)
          .toList();
    }

    for(final c in reveals) {
      final initialOffset = new Vector(SquareElement._size * c.x,
          SquareElement._size * c.y);
      final squareOffset = _popExplodeAnimationOffset + initialOffset;

      var delay = _popAnimationHitFrame + ((c - start).length * 4).toInt();
      delay += rnd.nextInt(10);

      final ss = game.getSquareState(c.x, c.y);

      String texturePrefix;
      int frameCount;

      switch(ss) {
        case SquareState.revealed:
        case SquareState.hidden:
          texturePrefix = 'balloon_pop';
          frameCount = 28;
          break;
        case SquareState.mine:
          texturePrefix = 'balloon_explode';
          frameCount = 24;
          break;
        default:
          throw 'not supported';
      }

      final request = new TextAniRequest(texturePrefix, frameCount, squareOffset,
          delay: delay, initialFrame: 'balloon.png', initialFrameOffset: initialOffset);

      switch(ss) {
        case SquareState.revealed:
        case SquareState.hidden:
          request.started.add((args) => _playPop());
          break;
        case SquareState.mine:
          request.started.add((args) => _playBoom());
          break;
      }

      _popAnimationLayer.add(request);
    }
  }

  void _playPop() {
    var i = rnd.nextInt(8);
    playAudio('Pop$i');
  }

  void _playBoom() {
    var i = rnd.nextInt(4) + 1;
    playAudio('Bomb$i');
  }

  void _startDartAnimation(Iterable<Coordinate> points) {
    for(final point in points) {
      final squareOffset = _dartAnimationOffset +
          new Vector(SquareElement._size * point.x, SquareElement._size * point.y);

      _dartAnimationLayer.add(new TextAniRequest('dart_fly_shadow', 54, squareOffset));
      _dartAnimationLayer.add(new TextAniRequest('dart_fly', 54, squareOffset));
    }
  }

  void _squareClicked(ElementMouseEventArgs args) {
    if(!_game.gameEnded) {
      final SquareElement se = args.element;
      if(_targetMode) {
        _target(se.x, se.y);
      } else {
        _click(se.x, se.y, args.shiftKey);
      }
    }
  }

  void _target(int x, int y) {
    _targetX = x;
    _targetY = y;
    _targetChanged.fireEvent(null);
    invalidateDraw();
  }

  bool _toggleFlag(int x, int y) {
    assert(!game.gameEnded);
    final ss = game.getSquareState(x, y);
    if(ss == SquareState.hidden) {
      game.setFlag(x, y, true);
      return true;
    } else if(ss == SquareState.flagged) {
      game.setFlag(x, y, false);
      return true;
    }
    return false;
  }

  void _click(int x, int y, bool alt) {
    assert(!game.gameEnded);
    final ss = game.getSquareState(x, y);

    List<Coordinate> reveals = null;

    if(alt) {
      if(ss == SquareState.hidden || ss == SquareState.flagged) {
        _toggleFlag(x, y);
      } else if(ss == SquareState.revealed) {
        if(game.canReveal(x, y)) {
          // get adjacent ballons
          final adjHidden = $(game.field.getAdjacentIndices(x, y))
              .select((i) {
                final t = game.field.getCoordinate(i);
                return new Coordinate(t.Item1, t.Item2);
              })
              .where((t) => game.getSquareState(t.x, t.y) == SquareState.hidden)
              .toList();

          assert(adjHidden.length > 0);

          _startDartAnimation(adjHidden);
          reveals = game.reveal(x, y);
        }
      }
    } else {
      if(ss == SquareState.hidden) {
        _startDartAnimation([new Coordinate(x, y)]);
        reveals = game.reveal(x, y);
      }
    }

    if(reveals != null && reveals.length > 0) {
      assert(game.state != GameState.lost);
      if(!alt) {
        // if it was a normal click, the first item should be the clicked item
        var first = reveals[0];
        assert(first.x == x);
        assert(first.y == y);
      }
      _startPopAnimation(new Coordinate(x, y), reveals);
    } else if(game.state == GameState.lost) {
      _startPopAnimation(new Coordinate(x, y));
    }
  }

  void _updateSize(int w, int h) {
    final sizeX = _getScale(w, _backgroundSize.width, _backgroundHoleSize);
    final sizeY = _getScale(h, _backgroundSize.height, _backgroundHoleSize);

    _canvas.size = size = new Size(sizeX, sizeY);

    // NOTE: width wins here. Need to do work to make left and right sides
    //       scale nicely when not a square
    _scale = sizeX / _backgroundSize.width;
    _scaledBoardOffset = _boardOffset.scale(_scale);
  }

  static num _getScale(int count, num fullSize, num holeSize) {
    final k = count * SquareElement._size + 2 * _edgeOffset;

    return k * fullSize / holeSize;
  }
}
