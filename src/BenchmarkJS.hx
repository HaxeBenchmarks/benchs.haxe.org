import haxe.Http;
import js.Browser;
import js.Syntax;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.Element;
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
	var benchmarkName:String;

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
		benchmarkName = Browser.window.location.pathname.split("/")[1];

		new JQuery("#linesOfCode").hide();
	}

	function requestArchivedData() {
		var request:Http = new Http("data/haxe3.json");

		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			haxe3Data = parser.fromJson(data, "haxe3.json");
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 3 data: " + msg);
		}
		request.request();

		var request:Http = new Http("data/haxe4.json");
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			haxe4Data = parser.fromJson(data, "haxe4.json");
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 4 data: " + msg);
		}
		request.request();

		var request:Http = new Http("data/haxe-nightly.json");
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

		showLatest("latestBenchmarks", 'latest $benchmarkName benchmark results (lower is faster)', "runtime in seconds", (target) -> target.time);
		showLatest("latestCompileTimes", 'latest $benchmarkName compile times (lower is faster)', "compile time in seconds", (target) -> target.compileTime);

		new JQuery(".targetCanvas").each(function(index:Int, element:Element) {
			var elem:JQuery = new JQuery(element);
			showHistory(elem.data("target"), elem.attr("id"));
		});
	}

	function showLatest(chartId:String, title:String, labelY:String, valueCallback:(target:TargetResult) -> TimeValue) {
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

		graphDataSets = graphDataSets.filter(function(info:GraphDatasetInfo):Bool {
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

		if (filterSettings.withHaxe3 && versionSupportsTarget(Haxe3, target)) {
			datasetData = datasetData.concat(collectRunData(target, haxe3Data, Haxe3, valueCallback));
		}
		if (filterSettings.withHaxe4 && versionSupportsTarget(Haxe4, target)) {
			datasetData = datasetData.concat(collectRunData(target, haxe4Data, Haxe4, valueCallback));
		}
		if (filterSettings.withHaxeNightly && versionSupportsTarget(HaxeNightly, target)) {
			datasetData = datasetData.concat(collectRunData(target, haxeNightlyData, HaxeNightly, valueCallback));
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
					case Cpp | Cppia | Csharp | Hashlink | HashlinkC | Java | Neko | NodeJs | Php | Python | Lua:
						true;
					case CppGCGen | HashlinkImmix | HashlinkCImmix | Jvm | NodeJsEs6 | Eval:
						false;
				}
			case Haxe4:
				true;
			case HaxeNightly:
				true;
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

	function getHistoryTime(testRun:TestRun, target:Target):Null<TargetTimeValues> {
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
	var data:Array<TimeValue>;
}

typedef TargetTimeValues = {
	var compileTime:TimeValue;
	var runtime:TimeValue;
}
