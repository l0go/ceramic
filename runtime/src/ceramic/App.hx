package ceramic;

#if hxtelemetry
import hxtelemetry.HxTelemetry;
#end

#if (cpp && linc_sdl)
import sdl.SDL;
#end

import ceramic.internal.PlatformSpecific;

import ceramic.Settings;
import ceramic.Assets;
import ceramic.Fragment;
import ceramic.Texture;
import ceramic.BitmapFont;
import ceramic.ConvertField;
import ceramic.Collections;
import ceramic.Shortcuts.*;

import haxe.CallStack;

import backend.Backend;

using ceramic.Extensions;

#if !macro
@:build(ceramic.macros.AppMacro.build())
#end
@:allow(ceramic.Visual)
@:allow(ceramic.Screen)
class App extends Entity {

/// Shared instances

    public static var app(get,null):App;
    static inline function get_app():App { return app; }

/// Events

    /** Ready event is triggered when the app is ready and
        the game logic can be started. */
    @event function ready();

    /** Update event is triggered as many times as there are frames per seconds.
        It is in sync with screen FPS but used for everything that needs
        to get updated depending on time (ceramic.Timer relies on it).
        Use this event to update your contents before they get drawn again. */
    @event function update(delta:Float);

    /** Pre-update event is triggered right before update event and
        can be used when you want to run garantee your code
        will be run before regular update event.*/
    @event function preUpdate(delta:Float);

    /** Post-update event is triggered right after update event and
        can be used when you want to run garantee your code
        will be run after regular update event.*/
    @event function postUpdate(delta:Float);

    @event function keyDown(key:Key);
    @event function keyUp(key:Key);

    @event function controllerAxis(controllerId:Int, axisId:Int, value:Float);
    @event function controllerDown(controllerId:Int, buttonId:Int);
    @event function controllerUp(controllerId:Int, buttonId:Int);
    @event function controllerEnable(controllerId:Int, name:String);
    @event function controllerDisable(controllerId:Int);

    /** Assets events */
    @event function defaultAssetsLoad(assets:Assets);

    /** Fired when the app hits an critical (uncaught) error. Can be used to perform custom crash reporting.
        If this even is handled, app exit should be performed by the event handler. */
    @event function criticalError(error:Dynamic, stack:Array<StackItem>);

    @event function beginEnterBackground();
    @event function finishEnterBackground();

    @event function beginEnterForeground();
    @event function finishEnterForeground();

    @event function lowMemory();

    @event function terminate();

/// Immediate update event, custom implementation

    var immediateCallbacks:Array<Void->Void> = [];

    var immediateCallbacksLen = 0;

#if hxtelemetry
    var hxt:HxTelemetry;
#end

    /** Schedule immediate callback that is garanteed to be executed before the next time frame
        (before elements are drawn onto screen) */
    public function onceImmediate(handleImmediate:Void->Void #if ceramic_debug_immediate , ?pos:haxe.PosInfos #end):Void {

        #if ceramic_debug_immediate
        immediateCallbacks[immediateCallbacksLen++] = function() {
            haxe.Log.trace('immediate flush', pos);
            handleImmediate();
        };
        #else
        immediateCallbacks[immediateCallbacksLen++] = handleImmediate;
        #end

    } //onceImmediate

    /** Execute and flush every awaiting immediate callback, including the ones that
        could have been added with `onceImmediate()` after executing the existing callbacks. */
    #if !debug inline #end public function flushImmediate():Bool {

        var didFlush = false;

        while (immediateCallbacksLen > 0) {

            didFlush = true;

            var pool = ArrayPool.pool(immediateCallbacksLen);
            var callbacks = pool.get();
            var len = immediateCallbacksLen;
            immediateCallbacksLen = 0;

            for (i in 0...len) {
                callbacks.set(i, immediateCallbacks.unsafeGet(i));
                immediateCallbacks[i] = null;
            }

            for (i in 0...len) {
                var cb = callbacks.get(i);
                cb();
            }

            pool.release(callbacks);

        }

        return didFlush;

    } //flushImmediate

/// Static pre-init code (used to add plugins)

    static var preInitCallbacks:Array<Void->Void>;
    static function oncePreInit(handle:Void->Void):Void {
        if (preInitCallbacks == null) preInitCallbacks = [];
        preInitCallbacks.push(handle);
    }

/// Properties

    /** Backend instance */
    public var backend(default,null):Backend;

    /** Screen instance */
    public var screen(default,null):Screen;

    /** App settings */
    public var settings(default,null):Settings;

    /** Logger. Used by log() shortcut */
    public var logger(default,null):Logger = new Logger();

    /** Visuals (ordered) */
    public var visuals(default,null):Array<Visual> = [];

    /** Render Textures */
    public var renderTextures(default,null):Array<RenderTexture> = [];

    /** App level assets. Used to load default bitmap font */
    public var assets(default,null):Assets = new Assets();

    /** App level collections */
    public var collections(default,null):Collections = new Collections();

    /** Default color shader **/
    public var defaultColorShader(default,null):Shader = null;

    /** Default textured shader **/
    public var defaultTexturedShader(default,null):Shader = null;

    /** Default font */
    public var defaultFont(default,null):BitmapFont = null;

    /** Project directory. May be null depending on the platform. */
    public var projectDir:String = null;

    /** App level persistent data */
    public var persistent(default,null):PersistentData = null;

    /** Text input manager */
    public var textInput(default,null):TextInput = null;

/// Field converters

    public var converters:Map<String,ConvertField<Dynamic,Dynamic>> = new Map();

    public var componentInitializers:Map<String,Array<Dynamic>->Component> = new Map();

/// Internal

    var hierarchyDirty:Bool = false;

    /** List of functions that will be called and purged when update iteration begins.
        Useful to run some specific code once exactly before update event is sent. */
    var beginUpdateCallbacks:Array<Void->Void> = [];

    var pressedScanCodes:IntIntMap = new IntIntMap(16, 0.5, false);

/// Public initializer

    public static function init():InitSettings {

#if cpp
        untyped __global__.__hxcpp_set_critical_error_handler(function(message:String) throw message);
#end

        // Setup actuate time
        motion.actuators.SimpleActuator.getTime = _actuateGetTime;

#if (cpp && linc_sdl)
        SDL.setLCNumericCLocale();
#end

        app = new App();
        return new InitSettings(app.settings);
        
    } //init

    static function _actuateGetTime():Float {

        return Timer.now;

    } //_actuateGetTime
    
/// Lifecycle

    function new() {
        
#if hxtelemetry
        var cfg = new hxtelemetry.HxTelemetry.Config();
        cfg.allocations = true;
        hxt = new HxTelemetry(cfg);
#end

        Runner.init();

        settings = new Settings();
        screen = new Screen();

        backend = new Backend();
        backend.onceReady(this, backendReady);
        backend.init(this);

    } //new

    function backendReady():Void {

#if (cpp && linc_sdl)
        SDL.setLCNumericCLocale();
#end

        // Init persistent data (that relies on backend)
        persistent = new PersistentData('app');

        // Init text input manager
        textInput = new TextInput();

        // Notify screen
        screen.backendReady();

        // Run pre-init callbacks
        if (preInitCallbacks != null) {
            for (callback in [].concat(preInitCallbacks)) {
                callback();
            }
            preInitCallbacks = null;
        }

        // Init field converters
        initFieldConverters();

        // Init component initializers
        initComponentInitializers();

        // Init collections
        initCollections();

        // Load default assets
        //
        // Default font
        assets.add(Fonts.ARIAL_20);

        // Default shaders
        assets.add(Shaders.COLOR);
        assets.add(Shaders.TEXTURED);
        //assets.add(Shaders.FXAA);

        assets.onceComplete(this, function(success) {

            if (success) {

                // Get default asset instances now that they are loaded
                defaultFont = assets.font(Fonts.ARIAL_20);
                defaultColorShader = assets.shader(Shaders.COLOR);
                defaultTexturedShader = assets.shader(Shaders.TEXTURED);

                logger.success('Default assets loaded.');
                assetsLoaded();
            } else {
                error('Failed to load default assets.');
            }

        });
        
        // Allow to load more default assets
        emitDefaultAssetsLoad(assets);

        assets.load();

    } //backendReady

    function initFieldConverters():Void {

        converters.set('ceramic.Texture', new ConvertTexture());
        converters.set('ceramic.BitmapFont', new ConvertFont());
        converters.set('ceramic.FragmentData', new ConvertFragmentData());
        converters.set('Map<String,String>', new ConvertMap<String>());
        converters.set('Map<String,Bool>', new ConvertMap<Bool>());
        converters.set('ceramic.ImmutableMap<String,String>', new ConvertMap<String>());
        converters.set('ceramic.ImmutableMap<String,Bool>', new ConvertMap<Bool>());
        converters.set('ceramic.ImmutableMap<String,ceramic.Component>', new ConvertComponentMap());

    } //initFieldConverters

    function initComponentInitializers():Void {

        // Nothing to do for now

    } //initComponentInitializers

    function initCollections():Void {

        var addedAssets = new Map<String,Bool>();
        var numAdded = 0;

        // Compute databases to load
        //
        for (key in Reflect.fields(info.collections)) {
            for (collectionName in Reflect.fields(Reflect.field(info.collections, key))) {
                var collectionInfo:Dynamic = Reflect.field(Reflect.field(info.collections, key), collectionName);
                if (!Std.is(collectionInfo, String)) {
                    var dataName = collectionInfo.data;
                    if (dataName != null) {
                        if (!addedAssets.exists(dataName)) {
                            addedAssets.set(dataName, true);
                            assets.addDatabase(dataName);
                            numAdded++;
                        }
                    }
                }
            }
        }

        if (numAdded > 0) {
            
            assets.onceComplete(this, function(success) {

                // Fill collections with loaded data
                //
                for (key in Reflect.fields(info.collections)) {
                    for (collectionName in Reflect.fields(Reflect.field(info.collections, key))) {
                        var collectionInfo:Dynamic = Reflect.field(Reflect.field(info.collections, key), collectionName);
                        if (!Std.is(collectionInfo, String)) {
                            var dataName = collectionInfo.data;
                            if (dataName != null) {
                                
                                var data = assets.database(dataName);
                                var collection:Collection<CollectionEntry> = Reflect.field(collections, collectionName);
                                var entryClass = Type.resolveClass(collectionInfo.type);

                                for (item in data) {
                                    var instance:CollectionEntry = Type.createInstance(entryClass, []);
                                    instance.setRawData(item);
                                    collection.push(instance);
                                }

                            }
                        }
                    }
                }

            });

        }

    } //initCollections

    function assetsLoaded():Void {

        // Platform specific code (which is not in backend code)
        PlatformSpecific.postAppInit();

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

        // Forward controller events
        backend.onControllerEnable(this, function(controllerId, name) {
            beginUpdateCallbacks.push(function() emitControllerEnable(controllerId, name));
        });
        backend.onControllerDisable(this, function(controllerId) {
            beginUpdateCallbacks.push(function() emitControllerDisable(controllerId));
        });
        backend.onControllerDown(this, function(controllerId, buttonId) {
            beginUpdateCallbacks.push(function() emitControllerDown(controllerId, buttonId));
        });
        backend.onControllerUp(this, function(controllerId, buttonId) {
            beginUpdateCallbacks.push(function() emitControllerUp(controllerId, buttonId));
        });
        backend.onControllerAxis(this, function(controllerId, axisId, value) {
            beginUpdateCallbacks.push(function() emitControllerAxis(controllerId, axisId, value));
        });

    } //assetsLoaded

    function update(delta:Float):Void {

#if (cpp && linc_sdl)
        SDL.setLCNumericCLocale();
#end

#if hxtelemetry
        hxt.advance_frame();
#end

        Runner.tick();

        Timer.update(delta);

        // Run 'begin update' callbacks, like touch/mouse/key events etc...
        if (beginUpdateCallbacks.length > 0) {
            var callbacks = beginUpdateCallbacks;
            beginUpdateCallbacks = [];
            for (callback in callbacks) {
                callback();
            }
        }

        // Screen pointer over/out events detection
        screen.updatePointerOverState(delta);

        // Trigger pre-update event
        emitPreUpdate(delta);

        // Flush immediate callbacks
        flushImmediate();

        // Update actuate stuff at the correct time
        @:privateAccess motion.actuators.SimpleActuator.stage_onEnterFrame(delta);

        // Flush immediate callbacks
        flushImmediate();

        // Then update
        emitUpdate(delta);

        // Flush immediate callbacks
        flushImmediate();

        // Emit post-update event
        emitPostUpdate(delta);

        // Flush immediate callbacks
        flushImmediate();

        // Update visuals
        updateVisuals(visuals);

        // Update hierarchy from depth
        computeHierarchy();

        // Sort visuals depending on their settings
        sortVisuals(visuals);

        // Draw
        backend.draw.draw(visuals);

    } //update

    @:noCompletion
    #if !debug inline #end public function updateVisuals(visuals:Array<Visual>) {

        do {
            // Notify if screen matrix has changed
            screen.matrix.computeChanged();
            if (screen.matrix.changed) {
                screen.matrix.emitChange();
            }

            for (visual in visuals) {

                // Compute touchable state
                if (visual.touchableDirty) {
                    visual.computeTouchable();
                }

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

            // Dispatch visual transforms changes
            for (visual in visuals) {

                if (visual.transform != null) {
                    visual.transform.computeChanged();
                    if (visual.transform.changed) {
                        visual.transform.emitChange();
                    }
                }

            }
        }
        while (flushImmediate());

        // Update visuals render target, matrix and visibility
        for (visual in visuals) {

            if (visual.renderTargetDirty) {
                visual.computeRenderTarget();
            }

            if (visual.matrixDirty) {
                visual.computeMatrix();
            }

            if (visual.visibilityDirty) {
                visual.computeVisibility();
            }

            if (visual.computedVisible) {
                if (visual.clipDirty) {
                    visual.computeClip();
                }
            }

        }

    } //updateVisuals

    @:noCompletion
    #if !debug inline #end public function computeHierarchy() {

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

            hierarchyDirty = false;
        }

    } //computeHierarchy

    @:noCompletion
    #if !debug inline #end public function sortVisuals(visuals:Array<Visual>) {

        // Sort visuals by (computed) depth
        SortVisuals.sort(visuals);

    } //sortVisuals

/// Keyboard

    function willEmitKeyDown(key:Key):Void {

        pressedScanCodes.set(key.scanCode, pressedScanCodes.get(key.scanCode) + 1);

    } //willEmitKeyDown

    function willEmitKeyUp(key:Key):Void {

        pressedScanCodes.set(key.scanCode, 0);

    } //willEmitKeyUp

    public function isKeyPressed(key:Key):Bool {

        return pressedScanCodes.get(key.scanCode) > 0;

    } //isKeyPressed

    public function isKeyJustPressed(key:Key):Bool {

        return pressedScanCodes.get(key.scanCode) == 1;

    } //isKeyJustPressed

} //App
