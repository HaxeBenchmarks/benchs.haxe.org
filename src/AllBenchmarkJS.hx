import haxe.Http;
import js.Browser;
import js.Syntax;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.Element;
import js.jquery.JQuery;
import BenchmarkJS.GraphDatasetInfo;
import BenchmarkJS.HistoricalDataPoint;
import BenchmarkJS.TargetTimeValues;
import benchmark.data.TestRun;
import data.IMovingAverage;
import json2object.JsonParser;

class AllBenchmarkJS {
	var benchesData:Map<String, AllBenchResults>;
	var haxe3Version:String;
	var haxe4Version:String;
	var haxeNightlyVersion:String;
	var documentLoaded:Bool;
	var filterSettings:FilterSettings;
	var chartObjects:Map<String, Any>;
	var benchmarks:Array<String>;
	var outstandingRequests:Int = 0;
	var latestTime:Float;

	public static function main() {
		new AllBenchmarkJS();
	}

	public function new() {
		haxe3Version = "3";
		haxe4Version = "4";
		haxeNightlyVersion = "nightly";
		latestTime = 0;

		filterSettings = new FilterSettings(checkLoaded);

		benchmarks = [for (e in new JQuery(".targetCanvas").elements()) e.data("bench")];
		loadBenchesData();

		documentLoaded = false;
		chartObjects = new Map<String, Any>();
		new JQuery(Browser.document).ready(function() {
			documentLoaded = true;
			checkLoaded();
		});

		new JQuery("#linesOfCode").hide();
	}

	function loadBenchesData() {
		outstandingRequests = benchmarks.length * 3;
		benchesData = new Map<String, AllBenchResults>();
		for (bench in benchmarks) {
			loadBenchData(bench);
		}
	}

	function loadBenchData(benchmark:String) {
		var request:Http = new Http('$benchmark/data/haxe3.json');
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			var data:ArchivedResults = parser.fromJson(data, "haxe3.json");
			addBenchmarkData(benchmark, Haxe3, data);
			outstandingRequests--;
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 3 data: " + msg);
			outstandingRequests--;
		}
		request.request();

		request = new Http('$benchmark/data/haxe4.json');
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			var data:ArchivedResults = parser.fromJson(data, "haxe4.json");
			addBenchmarkData(benchmark, Haxe4, data);
			outstandingRequests--;
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe 4 data: " + msg);
			outstandingRequests--;
		}
		request.request();

		request = new Http('$benchmark/data/haxe-nightly.json');
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			var data:ArchivedResults = parser.fromJson(data, "haxe-nightly.json");
			addBenchmarkData(benchmark, HaxeNightly, data);
			outstandingRequests--;
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe Nightly data: " + msg);
			outstandingRequests--;
		}
		request.request();
	}

	function addBenchmarkData(benchmark:String, haxeVersion:DatasetType, resultData:ArchivedResults) {
		var allBenchResults:Null<AllBenchResults> = benchesData.get(benchmark);
		if (allBenchResults == null) {
			allBenchResults = {
				haxe3Data: null,
				haxe4Data: null,
				haxeNightlyData: null
			}
			benchesData.set(benchmark, allBenchResults);
		}
		switch (haxeVersion) {
			case Haxe3:
				allBenchResults.haxe3Data = resultData;
			case Haxe4:
				allBenchResults.haxe4Data = resultData;
			case HaxeNightly:
				allBenchResults.haxeNightlyData = resultData;
			case HaxePR:
		}
	}

	function checkLoaded() {
		if (outstandingRequests > 0) {
			return;
		}
		if (!documentLoaded) {
			return;
		}
		detectVersions();
		showData();
	}

	function detectVersions() {
		haxe3Version = "";
		for (key => value in benchesData) {
			if (value.haxe3Data.length <= 0) {
				continue;
			}
			haxe3Version = value.haxe3Data[value.haxe3Data.length - 1].haxeVersion;
			haxe4Version = value.haxe4Data[value.haxe4Data.length - 1].haxeVersion;
			haxeNightlyVersion = value.haxeNightlyData[value.haxeNightlyData.length - 1].haxeVersion;
		}
	}

	function showData() {
		updateLastestTime();
		var target:Target = filterSettings.targets[0];
		showLatest("latestBenchmarks", 'latest benchmark results (lower is faster)', "runtime in seconds", target, (target) -> target.time);
		showLatest("latestCompileTimes", 'latest compile times (lower is faster)', "compile time in seconds", target, (target) -> target.compileTime);

		new JQuery(".targetCanvas").each(function(index:Int, element:Element) {
			var elem:JQuery = new JQuery(element);
			showHistory(target, elem.data("bench"), elem.attr("id"));
		});
	}

	function updateLastestTime() {
		for (key => bench in benchesData) {
			if (latestTime <= 0) {
				latestTime = Date.fromString(bench.haxe4Data[bench.haxe4Data.length - 1].date).getTime();
			}
			var time:Float = Date.fromString(bench.haxe4Data[bench.haxe4Data.length - 1].date).getTime();
			if (time > latestTime) {
				latestTime = time;
			}
			time = Date.fromString(bench.haxeNightlyData[bench.haxeNightlyData.length - 1].date).getTime();
			if (time > latestTime) {
				latestTime = time;
			}
		}
	}

	function showLatest(chartId:String, title:String, labelY:String, target:Target, valueCallback:(target:TargetResult) -> TimeValue) {
		var labels:Array<String> = benchmarks;
		var haxe3Dataset = {
			label: haxe3Version,
			backgroundColor: "#FF6666",
			borderColor: "#FF0000",
			borderWidth: 1,
			data: [for (label in labels) null]
		};
		var haxe4Dataset = {
			label: haxe4Version,
			backgroundColor: "#6666FF",
			borderColor: "#0000FF",
			borderWidth: 1,
			data: [for (label in labels) null]
		};
		var haxeNightlyDataset = {
			label: haxeNightlyVersion,
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
			switch (target) {
				case Target.Jvm | Target.Eval | Target.NodeJsEs6:
				default:
					for (bench in benchmarks) {
						extractLatestData(haxe3Dataset, bench, target, r -> r.haxe3Data, valueCallback);
					}
			}
		}
		if (filterSettings.withHaxe4) {
			data.datasets.push(haxe4Dataset);
			for (bench in benchmarks) {
				extractLatestData(haxe4Dataset, bench, target, r -> r.haxe4Data, valueCallback);
			}
		}
		if (filterSettings.withHaxeNightly) {
			data.datasets.push(haxeNightlyDataset);
			for (bench in benchmarks) {
				extractLatestData(haxeNightlyDataset, bench, target, r -> r.haxeNightlyData, valueCallback);
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

	function extractLatestData(dataSet:Dynamic, bench:String, target:Target, datasetCallback:(allResults:AllBenchResults) -> ArchivedResults,
			valueCallback:(target:TargetResult) -> TimeValue) {
		var allResults:Null<AllBenchResults> = benchesData.get(bench);
		if (allResults == null) {
			return;
		}
		var index:Int = benchmarks.indexOf(bench);
		if (index < 0) {
			return;
		}
		var results:Null<ArchivedResults> = datasetCallback(allResults);
		if ((results == null) || (results.length <= 0)) {
			return;
		}
		var lastRun:TestRun = results[results.length - 1];
		for (dataTarget in lastRun.targets) {
			if (dataTarget.name != target) {
				continue;
			}
			dataSet.data[index] = valueCallback(dataTarget);
			return;
		}
	}

	function showHistory(target:Target, benchmarkName:String, canvasId:String) {
		var graphDataSets:Array<GraphDatasetInfo> = BenchmarkJS.makeGraphDatasets(target);

		var allResults:AllBenchResults = benchesData.get(benchmarkName);
		if (allResults == null || allResults.haxe3Data == null || allResults.haxe4Data == null || allResults.haxeNightlyData == null) {
			new JQuery('#$canvasId').hide();
			return;
		}

		var haxe3Data:Null<ArchivedResults> = allResults.haxe3Data;
		var haxe4Data:Null<ArchivedResults> = allResults.haxe4Data;
		var haxeNightlyData:Null<ArchivedResults> = allResults.haxeNightlyData;

		new JQuery('#$canvasId').show();

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
		if (filterSettings.withHaxeNightly && versionSupportsTarget(HaxeNightly, target)) {
			datasetData = datasetData.concat(collectRunData(target, haxeNightlyData, HaxeNightly, valueCallback));
		}
		datasetData.sort(BenchmarkJS.sortDate);
		datasetData = BenchmarkJS.mergeTimes(datasetData, latestTime);

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
		if (!chartObjects.exists(benchmarkName)) {
			var ctx:CanvasRenderingContext2D = cast(Browser.document.getElementById(canvasId), CanvasElement).getContext("2d");
			var chart:Any = Syntax.code("new Chart({0}, {1})", ctx, options);
			chartObjects.set(benchmarkName, chart);
			return;
		}
		var chart:Any = chartObjects.get(benchmarkName);
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
			case Haxe4 | HaxeNightly | HaxePR:
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

	function collectRunData(target:Target, resultsData:ArchivedResults, type:DatasetType,
			valueCallback:(times:TargetTimeValues) -> TimeValue):Array<HistoricalDataPoint> {
		var average:IMovingAverage = filterSettings.averageFactory(filterSettings.windowSize);
		var datasetData:Array<HistoricalDataPoint> = [];
		for (run in resultsData) {
			var times:Null<TargetTimeValues> = BenchmarkJS.getHistoryTime(run, target);
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
}

typedef AllBenchResults = {
	var haxe3Data:ArchivedResults;
	var haxe4Data:ArchivedResults;
	var haxeNightlyData:ArchivedResults;
}
