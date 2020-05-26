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
		var benches:Array<String> = FileSystem.readDirectory("cases");
		benches.sort(sortBenches);
		for (benchmarkCase in benches) {
			generatePage(benchmarkCase);
		}
		generateAllPage(benches);
		generateHaxePRPage(benches);
	}

	function generatePage(benchmarkCase:String) {
		var targetList:Array<TargetIds> = makeTargetList(Target.allTargets);
		var context = {
			title: 'Haxe $benchmarkCase benchmark',
			description: makeDescription(benchmarkCase),
			targets: targetList,
			canvas: targetList,
		}
		var resource:String = Resource.getString("casePage");
		var template:Template = new Template(resource);
		var page:String = template.execute(context);
		FileSystem.createDirectory('site/$benchmarkCase');
		File.saveContent('site/$benchmarkCase/index.html', page);

		linkData(benchmarkCase);
	}

	function generateAllPage(benches:Array<String>) {
		var targetList:Array<TargetIds> = makeTargetList(Target.allTargets);
		var context = {
			targets: targetList,
			benches: makeBenchesList(benches),
		};
		var resource:String = Resource.getString("allBenches");
		var template:Template = new Template(resource);
		var page:String = template.execute(context);
		File.saveContent('site/allBenchmarks.html', page);
	}

	function generateHaxePRPage(benches:Array<String>) {
		var targetList:Array<TargetIds> = makeTargetList(Target.allTargets);
		var context = {
			targets: targetList,
			benches: makeBenchesList(benches),
		};
		var resource:String = Resource.getString("haxePRBenches");
		var template:Template = new Template(resource);
		var page:String = template.execute(context);
		File.saveContent('site/prBenchmarks.html', page);
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

	function makeBenchesList(benches:Array<String>):Array<TargetIds> {
		var targetCheckboxes:Array<TargetIds> = [];
		for (bench in benches) {
			var id:TargetId = cast bench;
			targetCheckboxes.push({
				id: bench,
				checkboxId: 'bench$id',
				canvasId: 'canvas$id',
				name: bench
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

	public static function sortBenches(a:String, b:String):Int {
		if (a > b) {
			return 1;
		}
		if (a < b) {
			return -1;
		}
		return 0;
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
