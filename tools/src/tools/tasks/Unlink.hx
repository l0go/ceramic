package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import sys.FileSystem;

class Unlink extends tools.Task {

    override public function info(cwd:String):String {

        return "Remove global ceramic command.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        if (Sys.systemName() == 'Mac') {
            command('rm', ['ceramic'], { cwd: '/usr/local/bin' });
        }
        else if (Sys.systemName() == 'Windows') {
            var haxePath = js.Node.process.env['HAXEPATH'];
            if (haxePath == null || !FileSystem.exists(Path.join([haxePath, 'ceramic.bat']))) {
                fail('There is nothing to unlink.');
            }
            FileSystem.deleteFile(Path.join([haxePath, 'ceramic.bat']));
        }

    } //run

} //Unlink
