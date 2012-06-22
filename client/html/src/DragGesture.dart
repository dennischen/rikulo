//Copyright (C) 2012 Potix Corporation. All Rights Reserved.
//History: Wed, Jun 20, 2012 11:37:32 AM
// Author: tomyeh

/**
 * The callback when [DragGesture] tries to start the dragging.
 *
 * If it returns null, the DragGesture won't be activated (i.e., ignored).
 * If not null, the returned element will be the element that the user
 * is dragging. If you'd like to move the owner directly, you can return
 * [DragGesture]'s `owner`. If you prefer to move a 'ghosted' element,
 * you can make a copy or create a different element depending on your
 * requirement.
 */
typedef Element DragGestureStart(DragGestureState state);
/** The callback that [DragGesture] uses to indicate the user is dragging,
 * or the user ends the dragging (i.e., releases the finger).
 *
 * If this method returns true, [DragGesture] won't move any element.
 * It is useful if you'd like use [DragGesture] to trigger something
 * rather than moving.
 */
typedef bool DragGestureMove(DragGestureState state);

/** The state of movement.
 */
interface MovementState {
  /** The touch point's offset relative to
   * the left-top corner of the owner element (right before moving).
   */
  Offset get offset();
  /** The number of pixels that a user has moved his finger
   * (since `start` was called).
   */
  Offset get delta();

  /** The element that the users touches at the beginning.
   */
  Element get touched();
}

/** The state of dragging.
 */
interface DragGestureState extends MovementState {
  /** Returns [DragGesture].
   */
  DragGesture get gesture();

  /** The element that was dragged, or null if the dragging is not started.
   * It is the element returned by [start], if specified.
   */
  Element get dragged();
  /** The range that the user is allowed to drag, or null if there
   * is no limitation.
   */
  Rectangle get range();
}

/**
 * A touch-and-drag gesture handler
 */
interface DragGesture default _DragGesture {
  /** Constructor.
   *
   * + [owner] is the owner of this drag gesture.
   * + [handle] specifies the element that the user can drag.
   * If not specified, [owner] is assumed.
   * + [range] specifies the range that the user is allowed to drag.
   * The coordinate is the same as [dragged]'s coordinate.
   * If the range's width is 0, the user can drag only vertically.
   * If height is 0, the user can drag only horizontally.
   * If not specified, the whole screen is assumed.
   * If you'd like to limit the dragging to a shape other than rectangle,
   * you have to specify [moving] and move the dragged element in the shape
   * you want (and return true to ignore the default move).
   * Notice that if [transform] is true, the range's width and height shall
   * be negative (since the direction is opposite).
   * + [transform] specifies whether to move [owner] by adjusting the CSS style's
   * transform property (of [dragged]).
   * If not specified (false), it changes the owner's position directly.
   * + [start] is the callback before starting dragging. The returned element
   * will be the element being moved.
   * If it returns null, the dragging won't be activated.
   * + [end] is the callback when the dragging is ended. Unlike other callbacks,
   * it must be specified.
   * + [movement] is the allowed movement to consider if a user is dragging a touch.
   * The user has to drag more than this number to activate the dragging.
   * If negative, it is ignored, i.e., it is considered as dragging as long
   * as the touch starts.
   * Default: -1 (unit: pixels)
   */
  DragGesture(Element owner, [Element handle, bool transform,
    AsRectangle range, int movement,
    DragGestureStart start, DragGestureMove end, DragGestureMove moving]);

  /** Destroys this [DragGesture].
   * It shall be called to clean up the gesture, if it is no longer used.
   */
  void destroy();

  /** The element that owns this drag gesture (never null).
   */
  Element get owner();
  /** The element that the user can drag (never null).
   */
  Element get handle();
}

class _DragGestureState implements DragGestureState {
  final _DragGesture _gesture;
  final Offset _ownerOfs, _initPgOfs;
  Offset _ofs, _delta, _initTxOfs;
  Rectangle _range;
  Element _dragged, _touched, _pending;

  _DragGestureState(DragGesture gesture, int pageX, int pageY):
  _gesture = gesture,
  _initPgOfs = new Offset(pageX, pageY),
  _ownerOfs = new DOMQuery(gesture.owner).documentOffset {
    _ofs = _initPgOfs - _ownerOfs;
    _delta = new Offset(0, 0);
  }

  DragGesture get gesture() => _gesture;
  Offset get offset() => _ofs;
  Offset get delta() => _delta;

  Element get dragged() => _dragged;
  Element get touched() => _touched;
  Rectangle get range() {
    if (_range === null && _gesture._fnRange !== null)
      _range = _gesture._fnRange();
    return _range;
  }
}

abstract class _DragGesture implements DragGesture {
  final Element _owner, _handle;
  final DragGestureStart _start;
  final DragGestureMove _end, _moving;
  final AsRectangle _fnRange;
  final int _movement;
  _DragGestureState _state;
  final bool _transform;

  factory _DragGesture(Element owner, [Element handle,
    bool transform, AsRectangle range, int movement,
    DragGestureStart start, DragGestureMove end,
    DragGestureMove moving]) {
    if (handle === null) handle = owner;
    if (movement === null) movement = -1;
    return browser.touch ?
      new _TouchDragGesture(owner, handle, transform, range, movement,
        start, end, moving):
      new _MouseDragGesture(owner, handle, transform, range, movement,
        start, end, moving);
  }
  _DragGesture._init(Element this._owner, Element this._handle,
    bool this._transform, AsRectangle this._fnRange, int this._movement,
    DragGestureStart this._start, DragGestureMove this._end,
    DragGestureMove this._moving) {
    _listen();
  }

  void destroy() {
    _stop();
    _unlisten();
  }

  Element get owner() => _owner;
  Element get handle() => _handle;

  abstract void _listen();
  abstract void _unlisten();

  void _stop() {
    _state = null;
  }
  void _touchStart(Element touched, int pageX, int pageY) {
    _stop();

    _state = new _DragGestureState(this, pageX, pageY);
    _state._pending = touched;
    if (_movement < 0)
      _activate();
  }
  void _activate() {
    _state._touched = _state._pending;
    _state._pending = null;
    final Element dragged =
      _state._dragged = _start !== null ?  _start(_state): owner;
    if (dragged === null) { //not allowed
      _stop();
      return;
    }

    _state._initTxOfs = _transform ? 
      CSS.offset3dOf(dragged.style.transform): new DOMQuery(dragged).offset;
  }
  void _touchMove(int pageX, int pageY) {
    if (_state !== null) {
      final Offset initPgOfs = _state._initPgOfs;
      if (_state._pending !== null) {
        int v;
        if ((v = pageX - initPgOfs.x) > _movement || v < -_movement
        || (v = pageY - initPgOfs.y) > _movement || v < -_movement)
          _activate();
      }
      if (_state._touched !== null) {
        _moveBy(pageX - _state._ownerOfs.x, pageY - _state._ownerOfs.y,
          pageX - initPgOfs.x, pageY - initPgOfs.y, _moving); 
      }
    }
  }
  void _touchEnd(int pageX, int pageY) {
    if (_state !== null && _state._touched !== null) {
      _moveBy(pageX - _state._ownerOfs.x, pageY - _state._ownerOfs.y,
        pageX - _state._initPgOfs.x, pageY - _state._initPgOfs.y, _end); 
    }
    _stop();
  }
  void _moveBy(int ofsX, int ofsY, int deltaX, int deltaY,
    DragGestureMove callback) {
    final Offset move = _constraint(ofsX, ofsY, deltaX, deltaY);

    if (callback !== null) {
      _state._ofs = new Offset(ofsX, ofsY);
      _state._delta = new Offset(deltaX, deltaY);
      bool done = callback(_state);
      if (done !== null && done)
        return; //no need to move
    }
    if (_transform) {
      _state._dragged.style.transform = CSS.translate3d(move.x, move.y);
    } else {
      _state._dragged.style.left = CSS.px(move.x);
      _state._dragged.style.top = CSS.px(move.y);
    }
  }
  Offset _constraint(int ofsX, int ofsY, int deltaX, int deltaY) {
    final Offset initofs = _state._initTxOfs;
    int moveX = deltaX + initofs.x,
      moveY = deltaY + initofs.y;
    final Rectangle range = _state.range;
    if (range !== null) {
      if (range.width == 0) moveX = initofs.x;
      else if (_transform) { //if transform, width is negative
        if (moveX > range.x) moveX = range.x;
        else if (moveX < range.right) moveX = range.right;
      } else {
        if (moveX < range.x) moveX = range.x;
        else if (moveX > range.right) moveX = range.right;
      }

      if (range.height == 0) moveY = initofs.y;
      else if (_transform) {
        if (moveY > range.y) moveY = range.y;
        else if (moveY < range.bottom) moveY = range.bottom;
      } else {
        if (moveY < range.y) moveY = range.y;
        else if (moveY > range.bottom) moveY = range.bottom;
      }
    }
    return new Offset(moveX, moveY);
  }
}

class _TouchDragGesture extends _DragGesture {
  EventListener _elStart, _elMove, _elEnd;

  _TouchDragGesture(Element owner, [Element handle,
    bool transform, AsRectangle range, int movement,
    DragGestureStart start, DragGestureMove end,
    DragGestureMove moving]):
    super._init(owner, handle,  transform, range, movement, start, end, moving);

  void _listen() {
    final ElementEvents on = handle.on;
    on.touchStart.add(_elStart = (TouchEvent event) {
      if (event.touches.length > 1)
        _touchEnd(event.pageX, event.pageY); //ignore multiple fingers
      else
        _touchStart(event.target, event.pageX, event.pageY);
    });
    on.touchMove.add(_elMove = (TouchEvent event) {
      _touchMove(event.pageX, event.pageY);
    });
    on.touchEnd.add(_elEnd = (TouchEvent event) {
      _touchEnd(event.pageX, event.pageY);
    });
  }
  void _unlisten() {
    final ElementEvents on = handle.on;
    if (_elStart !== null) on.touchStart.remove(_elStart);
    if (_elMove !== null) on.touchMove.remove(_elMove);
    if (_elEnd !== null) on.touchEnd.remove(_elEnd);
  }
}

class _MouseDragGesture extends _DragGesture {
  EventListener _elStart, _elMove, _elEnd;
  bool _captured = false;

  _MouseDragGesture(Element owner, [Element handle,
    bool transform, AsRectangle range, int movement,
    DragGestureStart start, DragGestureMove end,
    DragGestureMove moving]):
    super._init(owner, handle,  transform, range, movement, start, end, moving);

  void _stop() {
    if (_captured) {
      _captured = false;
      final ElementEvents on = document.on;
      if (_elMove !== null)
        on.mouseMove.remove(_elMove);
      if (_elEnd !== null)
        on.mouseUp.remove(_elEnd);
    }
    super._stop();
  }
  void _capture() {
    _captured = true;
    final ElementEvents on = document.on;
    on.mouseMove.add(_elMove = (MouseEvent event) {
      _touchMove(event.pageX, event.pageY);
    });
    on.mouseUp.add(_elEnd = (MouseEvent event) {
      _touchEnd(event.pageX, event.pageY);
    });
  }
  void _listen() {
    handle.on.mouseDown.add(_elStart = (MouseEvent event) {
      _touchStart(event.target, event.pageX, event.pageY);
      _capture();
    });
  }
  void _unlisten() {
    if (_elStart !== null)
      handle.on.mouseDown.remove(_elStart);
  }
}