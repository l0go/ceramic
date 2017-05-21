package ceramic;

import ceramic.Settings;
import backend.Backend;

@:allow(ceramic.Visual)
@:allow(ceramic.Screen)
class App extends Entity {

/// Shared instances

    public static var app(get,null):App;
    static inline function get_app():App { return app; }

/// Events

    /** Ready event is called when the app is ready and
        the game logic can be started. */
    @event function ready();

    /** Update event is called as many times as there are frames per seconds.
        It is in sync with screen FPS but used for everything that needs
        to get updated depending on time (ceramic.Timer relies on it).
        Use this event to update your contents before they get drawn again. */
    @event function update(delta:Float);

    @event function keyDown(key:Key);
    @event function keyUp(key:Key);

/// Properties

    public var project(default,null):Project;

    public var backend(default,null):Backend;

    public var screen(default,null):Screen;

    public var settings(default,null):Settings;

    public var logger(default,null):Logger = new Logger();

    public var visuals(default,null):Array<Visual> = [];

/// Internal

    var hierarchyDirty:Bool = false;

    /** List of functions that will be called and purged when update iteration begins.
        Useful to run some specific code once exactly before update event is sent. */
    var beginUpdateCallbacks:Array<Void->Void> = [];
    
/// Lifecycle

    function new() {

        app = this;

        settings = new Settings();
        screen = new Screen();

        project = @:privateAccess new Project(new InitSettings(settings));

        backend = new Backend();
        backend.onceReady(this, backendReady);
        backend.init(this);

    } //new

    function backendReady():Void {

        screen.backendReady();

        emitReady();

        screen.resize();

        backend.onUpdate(this, update);

        // Forward key events
        //
        backend.onKeyDown(this, function(key) {
            beginUpdateCallbacks.push(function() emitKeyDown(key));
        });
        backend.onKeyUp(this, function(key) {
            beginUpdateCallbacks.push(function() emitKeyUp(key));
        });

    } //backendReady

    function update(delta:Float):Void {

        Timer.update(delta);

        // Run 'begin update' callbacks, like touch/mouse/key events etc...
        if (beginUpdateCallbacks.length > 0) {
            var callbacks = beginUpdateCallbacks;
            beginUpdateCallbacks = [];
            for (callback in callbacks) {
                callback();
            }
        }

        // Then update
        app.emitUpdate(delta);

        // Notify if screen matrix has changed
        if (screen.matrix.changed) {
            screen.matrix.emitChange();
        }

        for (visual in visuals) {

            // Compute displayed content
            if (visual.contentDirty) {

                // Compute content only if visual is currently visible
                //
                if (visual.visibilityDirty) {
                    visual.computeVisibility();
                }

                if (visual.computedVisible) {
                    visual.computeContent();
                }
            }

        }

        if (hierarchyDirty) {

            // Compute visuals depth
            for (visual in visuals) {

                if (visual.parent == null) {
                    visual.computedDepth = visual.depth;

                    if (visual.children != null) {
                        visual.computeChildrenDepth();
                    }
                }
            }

            // Sort visuals by (computed) depth
            haxe.ds.ArraySort.sort(visuals, function(a:Visual, b:Visual):Int {

                if (a.computedDepth < b.computedDepth) return -1;
                if (a.computedDepth > b.computedDepth) return 1;
                return 0;

            });

            hierarchyDirty = false;
        }

        // Dispatch visual transforms changes
        for (visual in visuals) {

            if (visual.transform != null && visual.transform.changed) {
                visual.transform.emitChange();
            }

        }

        // Update visuals matrix and visibility
        for (visual in visuals) {

            if (visual.matrixDirty) {
                visual.computeMatrix();
            }

            if (visual.visibilityDirty) {
                visual.computeVisibility();
            }

        }

        // Draw
        backend.draw.draw(visuals);

    } //update

}
