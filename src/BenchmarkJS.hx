import haxe.Http;
import js.Browser;
import js.Syntax;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.Element;
import js.jquery.JQuery;
import Target.allTargets;
import benchmark.data.TestRun;
import data.IMovingAverage;
import json2object.JsonParser;

class BenchmarkJS {
	var haxe3Data:Null<ArchivedResults>;
	var haxe4Data:Null<ArchivedResults>;
	var haxe5Data:Null<ArchivedResults>;
	var haxeNightlyData:Null<ArchivedResults>;
	var haxe3Version:String;
	var haxe4Version:String;
	var haxe5Version:String;
	var haxeNightlyVersion:String;
	var documentLoaded:Bool;
	var filterSettings:FilterSettings;
	var chartObjects:Map<String, Any>;
	var benchmarkName:String;
	var latestTime:Float;

	public static function main() {
		new BenchmarkJS();
	}

	public function new() {
		filterSettings = new FilterSettings(checkLoaded);
		haxe3Data = null;
		haxe4Data = null;
		haxe5Data = null;
		haxeNightlyData = null;
		haxe3Version = "3";
		haxe4Version = "4";
		haxe5Version = "5";
		haxeNightlyVersion = "nightly";
		documentLoaded = false;
		chartObjects = new Map<String, Any>();
		latestTime = 0;
		requestArchivedData();
		new JQuery(Browser.document).ready(function() {
			documentLoaded = true;
			checkLoaded();
		});
		benchmarkName = Browser.window.location.pathname.split("/")[1];

		new JQuery("#linesOfCode").hide();
	}

	function requestArchivedData() {
		var request:Http = new Http('data/haxe3.json?r=${Math.random()}');

		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			haxe3Data = parser.fromJson(data, "haxe3.json");
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 3 data: " + msg);
		}
		request.request();

		var request:Http = new Http('data/haxe4.json?r=${Math.random()}');
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			haxe4Data = parser.fromJson(data, "haxe4.json");
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 4 data: " + msg);
		}
		request.request();

		var request:Http = new Http('data/haxe5.json?r=${Math.random()}');
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			haxe5Data = parser.fromJson(data, "haxe5.json");
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 5 data: " + msg);
		}
		request.request();

		var request:Http = new Http('data/haxe-nightly.json?r=${Math.random()}');
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			haxeNightlyData = parser.fromJson(data, "haxe-nightly.json");
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 3 data: " + msg);
		}
		request.request();
	}

	function checkLoaded() {
		if (haxe3Data == null) {
			return;
		}
		if (haxe4Data == null) {
			return;
		}
		if (haxe5Data == null) {
			return;
		}
		if (haxeNightlyData == null) {
			return;
		}
		if (!documentLoaded) {
			return;
		}
		showData();
	}

	function showData() {
		haxe3Version = "";
		if (haxe3Data.length > 0) {
			haxe3Version = haxe3Data[haxe3Data.length - 1].haxeVersion;
		}
		haxe4Version = haxe4Data[haxe4Data.length - 1].haxeVersion;
		haxe5Version = haxe5Data[haxe5Data.length - 1].haxeVersion;
		haxeNightlyVersion = haxeNightlyData[haxeNightlyData.length - 1].haxeVersion;
		updateLastestTime();

		buildIssueLists();
		showLatest("latestBenchmarks", 'latest $benchmarkName benchmark results (lower is faster)', "runtime in seconds", (target) -> target.time);
		showLatest("latestCompileTimes", 'latest $benchmarkName compile times (lower is faster)', "compile time in seconds", (target) -> target.compileTime);

		new JQuery(".targetCanvas").each(function(index:Int, element:Element) {
			var elem:JQuery = new JQuery(element);
			showHistory(elem.data("target"), elem.attr("id"));
		});
	}

	function updateLastestTime() {
		latestTime = Date.fromString(haxe4Data[haxe4Data.length - 1].date).getTime();
		var time:Float = Date.fromString(haxeNightlyData[haxeNightlyData.length - 1].date).getTime();
		if (time > latestTime) {
			latestTime = time;
		}
		time = Date.fromString(haxe5Data[haxe5Data.length - 1].date).getTime();
		if (time > latestTime) {
			latestTime = time;
		}
	}

	function buildIssueLists() {
		var showIssues:(issues:String, id:String) -> Void = function(issues:String, id:String) {
			if (issues.length <= 0) {
				new JQuery('#$id').hide();
				new JQuery('#$id span').text("");
			} else {
				new JQuery('#$id').show();
				new JQuery('#$id span').text(issues);
			}
		};

		var issues:String = buildIssueList(haxe3Data, Haxe3);
		// showIssues(buildIssueList(haxe3Data, Haxe3), "haxe3Issues");
		showIssues(buildIssueList(haxe4Data, Haxe4), "haxe4Issues");
		showIssues(buildIssueList(haxe5Data, Haxe5), "haxe5Issues");
		showIssues(buildIssueList(haxeNightlyData, HaxeNightly), "haxeNightlyIssues");
	}

	function buildIssueList(data:Null<ArchivedResults>, version:DatasetType):String {
		var run:TestRun;
		if ((data == null) || (data.length <= 0)) {
			return "no benchmark data";
		}
		run = data[data.length - 1];
		var requiredTargets:Array<Target> = allTargets.filter(t -> switch (version) {
			case Haxe3:
				switch (t) {
					case CppGCGen | Jvm | NodeJsEs6 | Eval:
						false;
					default:
						true;
				}
			case Haxe4 | HaxePR:
				true;
			case Haxe5 | HaxeNightly:
				switch (t) {
					case Csharp | Java:
						false;
					default:
						true;
				}
		});
		for (target in run.targets) {
			var index:Int = requiredTargets.indexOf(cast target.name);
			if (index < 0) {
				// bonus target?
				trace('[$version] has unexpected target ${target.name}');
				continue;
			}
			requiredTargets.splice(index, 1);
		}
		return requiredTargets.join(", ");
	}

	function showLatest(chartId:String, title:String, labelY:String, valueCallback:(target:TargetResult) -> TimeValue) {
		var hasHaxe3 = (haxe3Data.length > 0);
		var latestHaxe3Data:TestRun = null;
		if (hasHaxe3) {
			latestHaxe3Data = haxe3Data[haxe3Data.length - 1];
		}
		var latestHaxe4Data:TestRun = haxe4Data[haxe4Data.length - 1];
		var latestHaxe5Data:TestRun = haxe5Data[haxe5Data.length - 1];
		var latestHaxeNightlyData:TestRun = haxeNightlyData[haxeNightlyData.length - 1];
		var labels:Array<String> = filterSettings.targets;

		var haxe3Dataset = null;

		if (hasHaxe3) {
			haxe3Dataset = {
				label: latestHaxe3Data.haxeVersion,
				backgroundColor: "#FF6666",
				borderColor: "#FF0000",
				borderWidth: 1,
				lineTension: 0,
				data: [for (label in labels) null]
			};
		}

		var haxe4Dataset = {
			label: latestHaxe4Data.haxeVersion,
			backgroundColor: "#6666FF",
			borderColor: "#0000FF",
			borderWidth: 1,
			lineTension: 0,
			data: [for (label in labels) null]
		};

		var haxe5Dataset = {
			label: latestHaxe5Data.haxeVersion,
			backgroundColor: "#CC00FF",
			borderColor: "#6600FF",
			borderWidth: 1,
			lineTension: 0,
			data: [for (label in labels) null]
		};

		var haxeNightlyDataset = {
			label: latestHaxeNightlyData.haxeVersion,
			backgroundColor: "#66FF66",
			borderColor: "#33FF33",
			borderWidth: 1,
			lineTension: 0,
			data: [for (label in labels) null]
		};

		var data = {
			labels: labels,
			datasets: []
		};
		if (hasHaxe3 && filterSettings.withHaxe3) {
			data.datasets.push(haxe3Dataset);
			for (target in latestHaxe3Data.targets) {
				var index:Int = data.labels.indexOf(target.name);
				if (index < 0) {
					continue;
				}
				switch (target.name) {
					case Target.Jvm | Target.Eval | Target.NodeJsEs6:
						continue;
					default:
				}
				haxe3Dataset.data[index] = valueCallback(target);
			}
		}
		if (filterSettings.withHaxe4) {
			data.datasets.push(haxe4Dataset);
			for (target in latestHaxe4Data.targets) {
				var index:Int = data.labels.indexOf(target.name);
				if (index < 0) {
					continue;
				}
				haxe4Dataset.data[index] = valueCallback(target);
			}
		}
		if (filterSettings.withHaxe5) {
			data.datasets.push(haxe5Dataset);
			for (target in latestHaxe5Data.targets) {
				var index:Int = data.labels.indexOf(target.name);
				if (index < 0) {
					continue;
				}
				haxe5Dataset.data[index] = valueCallback(target);
			}
		}
		if (filterSettings.withHaxeNightly) {
			data.datasets.push(haxeNightlyDataset);
			for (target in latestHaxeNightlyData.targets) {
				var index:Int = data.labels.indexOf(target.name);
				if (index < 0) {
					continue;
				}
				haxeNightlyDataset.data[index] = valueCallback(target);
			}
		}

		var options = {
			type: "bar",
			data: data,
			options: {
				responsive: true,
				animation: {
					duration: 0
				},
				legend: {
					position: "top",
				},
				title: {
					display: true,
					text: title
				},
				tooltips: {
					mode: "index",
					intersect: false,
					bodyAlign: "right",
					bodyFontFamily: "Courier"
				},
				hover: {
					mode: "nearest",
					intersect: true
				},
				scales: {
					yAxes: [
						{
							scaleLabel: {
								display: true,
								labelString: labelY
							},
							ticks: {
								beginAtZero: true
							}
						}
					]
				}
			}
		};
		if (!chartObjects.exists(chartId)) {
			var ctx:CanvasRenderingContext2D = cast(Browser.document.getElementById(chartId), CanvasElement).getContext("2d");
			var chart:Any = Syntax.code("new Chart({0}, {1})", ctx, options);
			chartObjects.set(chartId, chart);
			return;
		}
		var chart:Any = chartObjects.get(chartId);
		untyped chart.data = data;
		Syntax.code("{0}.update()", chart);
	}

	function showHistory(target:Target, canvasId:String) {
		if (filterSettings.hasTarget(target)) {
			new JQuery('#$canvasId').show();
		} else {
			new JQuery('#$canvasId').hide();
			return;
		}
		var graphDataSets:Array<GraphDatasetInfo> = makeGraphDatasets(target);

		var hasHaxe3 = (haxe3Data.length > 0);

		graphDataSets = graphDataSets.filter(function(info:GraphDatasetInfo):Bool {
			if ((info.type == Haxe3) && !hasHaxe3) {
				return false;
			}
			if (!versionSupportsTarget(info.type, target)) {
				return false;
			}
			switch (filterSettings.showAverage) {
				case JustData:
					if (info.movingAverage) {
						return false;
					}
				case OnlyAverage:
					if (!info.movingAverage) {
						return false;
					}
				case DataAndAverage:
			}
			return true;
		});

		var data = {
			labels: [],
			datasets: []
		};

		var datasetData:Array<HistoricalDataPoint> = [];

		var valueCallback:(times:TargetTimeValues) -> TimeValue;
		var graphTitle:String;
		switch (filterSettings.timesSelection) {
			case Compiletime:
				valueCallback = (times) -> times.compileTime;
				graphTitle = '$benchmarkName compile times';
				new JQuery('#$canvasId').addClass("compileTimeGraph").removeClass("benchmarkGraph");
			case _:
				valueCallback = (times) -> times.runtime;
				graphTitle = '$benchmarkName benchmark results';
				new JQuery('#$canvasId').addClass("benchmarkGraph").removeClass("compileTimeGraph");
		}

		if (hasHaxe3 && filterSettings.withHaxe3 && versionSupportsTarget(Haxe3, target)) {
			datasetData = datasetData.concat(collectRunData(target, haxe3Data, Haxe3, valueCallback));
		}
		if (filterSettings.withHaxe4 && versionSupportsTarget(Haxe4, target)) {
			datasetData = datasetData.concat(collectRunData(target, haxe4Data, Haxe4, valueCallback));
		}
		if (filterSettings.withHaxe5 && versionSupportsTarget(Haxe5, target)) {
			datasetData = datasetData.concat(collectRunData(target, haxe5Data, Haxe5, valueCallback));
		}
		if (filterSettings.withHaxeNightly && versionSupportsTarget(HaxeNightly, target)) {
			datasetData = datasetData.concat(collectRunData(target, haxeNightlyData, HaxeNightly, valueCallback));
		}
		datasetData.sort(sortDate);
		datasetData = mergeTimes(datasetData, latestTime);

		var now:Float = Date.now().getTime();
		for (item in datasetData) {
			if (!showDate(item.date)) {
				continue;
			}
			data.labels.push(item.date);
			for (graph in graphDataSets) {
				if (graph.movingAverage) {
					graph.dataset.data.push(item.sma.get(graph.type));
				} else {
					graph.dataset.data.push(item.time.get(graph.type));
				}
			}
		}
		data.datasets = graphDataSets.map(item -> item.dataset);

		var options = {
			type: "line",
			data: data,
			options: {
				responsive: true,
				animation: {
					duration: 0
				},
				legend: {
					position: "top",
				},
				title: {
					display: true,
					text: '$target $graphTitle (lower is faster)'
				},
				tooltips: {
					mode: "index",
					intersect: false,
					bodyAlign: "right",
					bodyFontFamily: "Courier"
				},
				hover: {
					mode: "nearest",
					intersect: true
				},
				scales: {
					yAxes: [
						{
							scaleLabel: {
								display: true,
								labelString: "times in seconds"
							}
						}
					]
				}
			}
		};
		if (!chartObjects.exists(target)) {
			var ctx:CanvasRenderingContext2D = cast(Browser.document.getElementById(canvasId), CanvasElement).getContext("2d");
			var chart:Any = Syntax.code("new Chart({0}, {1})", ctx, options);
			chartObjects.set(target, chart);
			return;
		}
		var chart:Any = chartObjects.get(target);
		untyped chart.options = options.options;
		untyped chart.data = data;
		Syntax.code("{0}.update()", chart);
	}

	function versionSupportsTarget(version:DatasetType, target:Target):Bool {
		return switch (version) {
			case Haxe3:
				switch (target) {
					case Cpp | Cppia | Csharp | Hashlink | HashlinkC | Java | Neko | NodeJs | Php | Python | Lua | Luajit:
						true;
					case CppGCGen | Jvm | NodeJsEs6 | Eval:
						false;
				}
			case Haxe4 | HaxePR:
				true;
			case Haxe5 | HaxeNightly:
				switch (target) {
					case Cpp | Cppia | Hashlink | HashlinkC | Neko | NodeJs | Php | Python | Lua | Luajit | CppGCGen | Jvm | NodeJsEs6 | Eval:
						true;
					case Csharp | Java:
						false;
				}
		}
	}

	function showDate(dateVal:String):Bool {
		var time:Float = Date.fromString(dateVal).getTime();
		if ((filterSettings.startDate != null) && (filterSettings.startDate > time)) {
			return false;
		}
		if ((filterSettings.endDate != null) && (filterSettings.endDate < time)) {
			return false;
		}
		return true;
	}

	public static function mergeTimes(datasetData:Array<HistoricalDataPoint>, latestTimeValue:Float):Array<HistoricalDataPoint> {
		var result:Array<HistoricalDataPoint> = [];
		var lastDataPoint:Null<HistoricalDataPoint> = null;
		var lastTime:Null<Float> = null;
		for (data in datasetData) {
			if (lastDataPoint == null) {
				lastDataPoint = data;
				lastTime = Date.fromString(lastDataPoint.date).getTime();
				result.push(data);
				continue;
			}
			var newTime:Float = Date.fromString(data.date).getTime();
			if (Math.abs(newTime - lastTime) > 120 * 1000) {
				lastDataPoint = data;
				lastTime = newTime;
				result.push(data);
				continue;
			}
			for (key => val in data.time) {
				lastDataPoint.time.set(key, val);
			}
			for (key => val in data.sma) {
				lastDataPoint.sma.set(key, val);
			}
		}
		if (lastTime < latestTimeValue) {
			result.push({
				time: [],
				sma: [],
				date: DateTools.format(Date.fromTime(latestTimeValue), "%Y-%m-%d %H:%M:%S")
			});
		}
		return result;
	}

	function collectRunData(target:Target, resultsData:ArchivedResults, type:DatasetType,
			valueCallback:(times:TargetTimeValues) -> TimeValue):Array<HistoricalDataPoint> {
		var average:IMovingAverage = filterSettings.averageFactory(filterSettings.windowSize);
		var datasetData:Array<HistoricalDataPoint> = [];
		for (run in resultsData) {
			var times:Null<TargetTimeValues> = getHistoryTime(run, target);
			if (times == null) {
				continue;
			}
			var time:TimeValue = valueCallback(times);
			average.addValue(time);
			datasetData.push({
				time: [type => time],
				sma: [type => average.getAverage()],
				date: run.date
			});
		}
		return datasetData;
	}

	public static function makeGraphDatasets(target:Target):Array<GraphDatasetInfo> {
		return [
			makeGraphDataset(Haxe3, false, target + " (Haxe 3)", "#FF0000", "#FF0000"),
			makeGraphDataset(Haxe4, false, target + " (Haxe 4)", "#0000FF", "#0000FF"),
			makeGraphDataset(Haxe5, false, target + " (Haxe 5)", "#CC00FF", "#CC00FF"),
			makeGraphDataset(HaxeNightly, false, target + " (Haxe nightly)", "#66FF66", "#66FF66"),
			makeGraphDataset(Haxe3, true, target + " (Haxe 3 avg)", "#FFCCCC", "#FFCCCC"),
			makeGraphDataset(Haxe4, true, target + " (Haxe 4 avg)", "#CCCCFF", "#CCCCFF"),
			makeGraphDataset(Haxe5, true, target + " (Haxe 5 avg)", "#FFAAFF", "#FFAAFF"),
			makeGraphDataset(HaxeNightly, true, target + " (Haxe nightly avg)", "#88FFCC", "#88FFCC"),
		];
	}

	public static function makeGraphDataset(type:DatasetType, movingAverage:Bool, label:String, borderColor:String, backgroundColor:String):GraphDatasetInfo {
		return {
			type: type,
			movingAverage: movingAverage,
			dataset: {
				label: label,
				backgroundColor: backgroundColor,
				borderColor: borderColor,
				borderWidth: 1,
				lineTension: 0,
				fill: false,
				spanGaps: true,
				data: []
			}
		}
	}

	public static function sortDate(a:HistoricalDataPoint, b:HistoricalDataPoint):Int {
		if (a.date > b.date) {
			return 1;
		}
		if (a.date < b.date) {
			return -1;
		}
		return 0;
	}

	public static function getHistoryTime(testRun:TestRun, target:Target):Null<TargetTimeValues> {
		for (runTarget in testRun.targets) {
			if (target == runTarget.name) {
				return {runtime: runTarget.time, compileTime: runTarget.compileTime};
			}
		}
		return null;
	}
}

typedef HistoricalDataPoint = {
	var time:Map<DatasetType, TimeValue>;
	var sma:Map<DatasetType, TimeValue>;
	var date:String;
}

typedef GraphDatasetInfo = {
	var type:DatasetType;
	var movingAverage:Bool;
	var dataset:GraphDataset;
}

typedef GraphDataset = {
	var label:String;
	var backgroundColor:String;
	var borderColor:String;
	var borderWidth:Int;
	var fill:Bool;
	var spanGaps:Bool;
	var lineTension:Float;
	var data:Array<TimeValue>;
}

typedef TargetTimeValues = {
	var compileTime:TimeValue;
	var runtime:TimeValue;
}
