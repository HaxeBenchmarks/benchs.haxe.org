import haxe.Http;
import js.Browser;
import js.Syntax;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.jquery.JQuery;
import data.IMovingAverage;
import data.TestRun;
import json2object.JsonParser;

class BenchmarkJS {
	var haxe3Data:Null<ArchivedResults>;
	var haxe4Data:Null<ArchivedResults>;
	var haxeNightlyData:Null<ArchivedResults>;
	var haxe3Version:String;
	var haxe4Version:String;
	var haxeNightlyVersion:String;
	var documentLoaded:Bool;
	var filterSettings:FilterSettings;
	var chartObjects:Map<String, Any>;

	public static function main() {
		new BenchmarkJS();
	}

	public function new() {
		filterSettings = new FilterSettings(checkLoaded);
		haxe3Data = null;
		haxe4Data = null;
		haxeNightlyData = null;
		haxe3Version = "3";
		haxe4Version = "4";
		haxeNightlyVersion = "nightly";
		documentLoaded = false;
		chartObjects = new Map<String, Any>();
		requestArchivedData();
		new JQuery(Browser.document).ready(function() {
			documentLoaded = true;
			checkLoaded();
		});

		new JQuery("#linesOfCode").hide();
	}

	function requestArchivedData() {
		var request:Http = new Http("data/archiveHaxe3.json");

		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			haxe3Data = parser.fromJson(data, "archiveHaxe3.json");
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 3 data: " + msg);
		}
		request.request();

		var request:Http = new Http("data/archiveHaxe4.json");
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			haxe4Data = parser.fromJson(data, "archiveHaxe4.json");
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 4 data: " + msg);
		}
		request.request();

		var request:Http = new Http("data/archiveHaxeNightly.json");
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			haxeNightlyData = parser.fromJson(data, "archiveHaxeNightly.json");
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
		if (haxeNightlyData == null) {
			return;
		}
		if (!documentLoaded) {
			return;
		}
		showData();
	}

	function showData() {
		haxe3Version = haxe3Data[haxe3Data.length - 1].haxeVersion;
		haxe4Version = haxe4Data[haxe4Data.length - 1].haxeVersion;
		haxeNightlyVersion = haxeNightlyData[haxeNightlyData.length - 1].haxeVersion;

		showLatest();
		// showLinesOfCode();
		showHistory(Cpp, "cppBenchmarks");
		showHistory(CppGCGen, "cppGCGenBenchmarks");
		showHistory(Java, "javaBenchmarks");
		showHistory(Jvm, "jvmBenchmarks");
		showHistory(Hashlink, "hlBenchmarks");
		showHistory(HashlinkC, "hlcBenchmarks");
		showHistory(NodeJs, "nodeBenchmarks");
		showHistory(NodeJsEs6, "nodeES6Benchmarks");
		showHistory(Csharp, "csharpBenchmarks");
		showHistory(Eval, "evalBenchmarks");
		showHistory(Neko, "nekoBenchmarks");
		showHistory(Php, "phpBenchmarks");
		showHistory(Python, "pythonBenchmarks");
	}

	function showLatest() {
		var latestHaxe3Data:TestRun = haxe3Data[haxe3Data.length - 1];
		var latestHaxe4Data:TestRun = haxe4Data[haxe4Data.length - 1];
		var latestHaxeNightlyData:TestRun = haxeNightlyData[haxeNightlyData.length - 1];
		var labels:Array<String> = filterSettings.targets;

		var haxe3Dataset = {
			label: latestHaxe3Data.haxeVersion,
			backgroundColor: "#FF6666",
			borderColor: "#FF0000",
			borderWidth: 1,
			data: [for (label in labels) null]
		};

		var haxe4Dataset = {
			label: latestHaxe4Data.haxeVersion,
			backgroundColor: "#6666FF",
			borderColor: "#0000FF",
			borderWidth: 1,
			data: [for (label in labels) null]
		};

		var haxeNightlyDataset = {
			label: latestHaxeNightlyData.haxeVersion,
			backgroundColor: "#66FF66",
			borderColor: "#33FF33",
			borderWidth: 1,
			data: [for (label in labels) null]
		};

		var data = {
			labels: labels,
			datasets: []
		};
		if (filterSettings.withHaxe3) {
			data.datasets.push(haxe3Dataset);
			for (target in latestHaxe3Data.targets) {
				var index:Int = data.labels.indexOf(target.name);
				if (index < 0) {
					continue;
				}
				switch (target.name) {
					case Jvm | Eval | NodeJsEs6:
						continue;
					default:
				}
				haxe3Dataset.data[index] = target.time;
			}
		}
		if (filterSettings.withHaxe4) {
			data.datasets.push(haxe4Dataset);
			for (target in latestHaxe4Data.targets) {
				var index:Int = data.labels.indexOf(target.name);
				if (index < 0) {
					continue;
				}
				haxe4Dataset.data[index] = target.time;
			}
		}
		if (filterSettings.withHaxeNightly) {
			data.datasets.push(haxeNightlyDataset);
			for (target in latestHaxeNightlyData.targets) {
				var index:Int = data.labels.indexOf(target.name);
				if (index < 0) {
					continue;
				}
				haxeNightlyDataset.data[index] = target.time;
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
					text: "latest benchmark results (lower is faster)"
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
								labelString: "runtime in seconds"
							},
							ticks: {
								beginAtZero: true
							}
						}
					]
				}
			}
		};
		if (!chartObjects.exists("latest")) {
			var ctx:CanvasRenderingContext2D = cast(Browser.document.getElementById("latestBenchmarks"), CanvasElement).getContext("2d");
			var chart:Any = Syntax.code("new Chart({0}, {1})", ctx, options);
			chartObjects.set("latest", chart);
			return;
		}
		var chart:Any = chartObjects.get("latest");
		untyped chart.data = data;
		Syntax.code("{0}.update()", chart);
	}

	function showLinesOfCode() {
		if (Browser.document.getElementById("linesOfCode") == null) {
			return;
		}

		var inputDataset = {
			label: "Input lines",
			backgroundColor: "#FF6666",
			borderColor: "#FF0000",
			borderWidth: 1,
			fill: false,
			spanGaps: true,
			data: []
		};

		var outputDataset = {
			label: "Formatted lines",
			backgroundColor: "#6666FF",
			borderColor: "#0000FF",
			borderWidth: 1,
			fill: false,
			spanGaps: true,
			data: []
		};

		var data = {
			labels: [],
			datasets: [inputDataset, outputDataset]
		};

		for (run in haxe4Data) {
			for (runTarget in run.targets) {
				if (runTarget.name != NodeJs) {
					continue;
				}
				data.labels.push(run.date);
				inputDataset.data.push(runTarget.inputLines);
				outputDataset.data.push(runTarget.outputLines);
			}
		}
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
					text: 'Lines of Code'
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
								labelString: "lines of code"
							}
						}
					]
				}
			}
		};
		if (!chartObjects.exists("linesOfCode")) {
			var ctx:CanvasRenderingContext2D = cast(Browser.document.getElementById("linesOfCode"), CanvasElement).getContext("2d");
			var chart:Any = Syntax.code("new Chart({0}, {1})", ctx, options);
			chartObjects.set("linesOfCode", chart);
			return;
		}
		var chart:Any = chartObjects.get("linesOfCode");
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

		graphDataSets = graphDataSets.filter(function(info:GraphDatasetInfo):Bool {
			if ((info.type == Haxe3) && (target == Jvm || target == Eval || target == NodeJsEs6)) {
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
		if (filterSettings.withHaxe3) {
			datasetData = datasetData.concat(collectRunData(target, haxe3Data, Haxe3));
		}
		if (filterSettings.withHaxe4) {
			datasetData = datasetData.concat(collectRunData(target, haxe4Data, Haxe4));
		}
		if (filterSettings.withHaxeNightly) {
			datasetData = datasetData.concat(collectRunData(target, haxeNightlyData, HaxeNightly));
		}
		datasetData.sort(sortDate);
		datasetData = mergeTimes(datasetData);

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
					text: '$target benchmark results (lower is faster)'
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
								labelString: "runtime in seconds"
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
		untyped chart.data = data;
		Syntax.code("{0}.update()", chart);
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

	function mergeTimes(datasetData:Array<HistoricalDataPoint>):Array<HistoricalDataPoint> {
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
		return result;
	}

	function collectRunData(target:Target, resultsData:ArchivedResults, type:DatasetType):Array<HistoricalDataPoint> {
		var average:IMovingAverage = filterSettings.averageFactory(filterSettings.windowSize);
		var datasetData:Array<HistoricalDataPoint> = [];
		for (run in resultsData) {
			var time:Null<Float> = getHistoryTime(run, target);
			if (time == null) {
				continue;
			}
			average.addValue(time);
			datasetData.push({
				time: [type => time],
				sma: [type => average.getAverage()],
				date: run.date
			});
		}
		return datasetData;
	}

	function makeGraphDatasets(target:Target):Array<GraphDatasetInfo> {
		return [
			makeGraphDataset(Haxe3, false, target + " (Haxe 3)", "#FF0000", "#FF0000"),
			makeGraphDataset(Haxe4, false, target + " (Haxe 4)", "#0000FF", "#0000FF"),
			makeGraphDataset(HaxeNightly, false, target + " (Haxe nightly)", "#66FF66", "#66FF66"),
			makeGraphDataset(Haxe3, true, target + " (Haxe 3 avg)", "#FFCCCC", "#FFCCCC"),
			makeGraphDataset(Haxe4, true, target + " (Haxe 4 avg)", "#CCCCFF", "#CCCCFF"),
			makeGraphDataset(HaxeNightly, true, target + " (Haxe nightly avg)", "#CCFFCC", "#CCFFCC"),
		];
	}

	function makeGraphDataset(type:DatasetType, movingAverage:Bool, label:String, borderColor:String, backgroundColor:String):GraphDatasetInfo {
		return {
			type: type,
			movingAverage: movingAverage,
			dataset: {
				label: label,
				backgroundColor: backgroundColor,
				borderColor: borderColor,
				borderWidth: 1,
				fill: false,
				spanGaps: true,
				data: []
			}
		}
	}

	function sortDate(a:HistoricalDataPoint, b:HistoricalDataPoint):Int {
		if (a.date > b.date) {
			return 1;
		}
		if (a.date < b.date) {
			return -1;
		}
		return 0;
	}

	function getHistoryTime(testRun:TestRun, target:Target):Null<TimeValue> {
		for (runTarget in testRun.targets) {
			if (target == runTarget.name) {
				return runTarget.time;
			}
		}
		return null;
	}
}

@:enum
abstract Target(String) to String {
	var Cpp = "C++";
	var CppGCGen = "C++ (HXCPP_GC_GENERATIONAL)";
	var Csharp = "C#";
	var Hashlink = "Hashlink";
	var HashlinkC = "Hashlink/C";
	var Java = "Java";
	var Jvm = "JVM";
	var Neko = "Neko";
	var NodeJs = "NodeJS";
	var NodeJsEs6 = "NodeJS (ES6)";
	var Php = "PHP";
	var Python = "Python";
	var Eval = "eval";
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
	var data:Array<TimeValue>;
}
