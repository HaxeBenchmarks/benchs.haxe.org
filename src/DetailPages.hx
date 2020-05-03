import haxe.Resource;
import haxe.Template;
import sys.FileSystem;
import sys.io.File;
import Target.TargetId;

class DetailPages {
	public function new() {
		generatePages();
	}

	function generatePages() {
		for (benchmarkCase in FileSystem.readDirectory("cases")) {
			generatePage(benchmarkCase);
		}
	}

	function generatePage(benchmarkCase:String) {
		var context = {
			title: 'Haxe $benchmarkCase benchmark',
			description: makeDescription(benchmarkCase),
			targets: makeTargetList([
				Cpp, CppGCGen, Cppia, Csharp, Hashlink, HashlinkC, HashlinkImmix, HashlinkCImmix, Java, Jvm, Neko, NodeJs, NodeJsEs6, Php, Python, Eval, Lua
			]),
			canvas: makeTargetList([
				Cpp, CppGCGen, Java, Jvm, Hashlink, HashlinkC, HashlinkImmix, HashlinkCImmix, NodeJs, NodeJsEs6, Cppia, Csharp, Neko, Eval, Php, Python, Lua
			]),
		}
		var resource:String = Resource.getString("casePage");
		var template:Template = new Template(resource);
		var page:String = template.execute(context);
		FileSystem.createDirectory('site/$benchmarkCase');
		File.saveContent('site/$benchmarkCase/index.html', page);

		linkData(benchmarkCase);
	}

	function linkData(benchmarkCase:String) {
		var baseFolder:Null<String> = Sys.getEnv("BENCHMARK_RESULTS_BASE");
		if ((baseFolder == null) || (baseFolder.trim().length <= 0)) {
			return;
		}
		if (!FileSystem.exists(baseFolder)) {
			return;
		}
		if (!FileSystem.exists('$baseFolder/$benchmarkCase')) {
			return;
		}
		Sys.command("ln", ["-sfn", '$baseFolder/$benchmarkCase', 'site/$benchmarkCase/data']);
	}

	function makeTargetList(targets:Array<Target>):Array<TargetIds> {
		var targetCheckboxes:Array<TargetIds> = [];
		for (target in targets) {
			var id:TargetId = target;
			targetCheckboxes.push({
				id: target,
				checkboxId: 'target$id',
				canvasId: 'canvas$id',
				name: target
			});
		}
		return targetCheckboxes;
	}

	function makeDescription(benchmarkCase:String):String {
		if (!FileSystem.exists('cases/$benchmarkCase/README.md')) {
			return "";
		}
		return Markdown.markdownToHtml(File.getContent('cases/$benchmarkCase/README.md'));
	}

	public static function main() {
		new DetailPages();
	}
}

typedef TargetIds = {
	var id:String;
	var checkboxId:String;
	var canvasId:String;
	var name:String;
}
