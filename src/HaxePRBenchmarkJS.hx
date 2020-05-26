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
import data.IMovingAverage;
import data.TestRun;
import json2object.JsonParser;

class HaxePRBenchmarkJS {
	var benchesData:Map<String, PRBenchResults>;
	var haxeNightlyVersion:String;
	var documentLoaded:Bool;
	var filterSettings:FilterSettings;
	var chartObjects:Map<String, Any>;
	var benchmarks:Array<String>;
	var prList:Array<String>;

	var outstandingRequests:Int = 0;

	public static function main() {
		new HaxePRBenchmarkJS();
	}

	public function new() {
		haxeNightlyVersion = "nightly";
		prList = [];

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
		outstandingRequests = benchmarks.length * 2;
		benchesData = new Map<String, PRBenchResults>();
		for (bench in benchmarks) {
			loadBenchData(bench);
		}
	}

	function loadBenchData(benchmark:String) {
		var request:Http = new Http('$benchmark/data/haxe-pr.json');
		request.onData = function(data:String) {
			var parser:JsonParser<ArchivedResults> = new JsonParser<ArchivedResults>();
			var data:ArchivedResults = parser.fromJson(data, "haxe-pr.json");
			addBenchmarkData(benchmark, HaxePR, data);
			outstandingRequests--;
			checkLoaded();
		}
		request.onError = function(msg:String) {
			trace("failed to download Haxe PR data: " + msg);
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
		var allBenchResults:Null<PRBenchResults> = benchesData.get(benchmark);
		if (allBenchResults == null) {
			allBenchResults = {
				haxeNightlyData: null,
				haxePRData: null
			}
			benchesData.set(benchmark, allBenchResults);
		}
		switch (haxeVersion) {
			case Haxe3 | Haxe4:
			case HaxeNightly:
				allBenchResults.haxeNightlyData = resultData;
			case HaxePR:
				allBenchResults.haxePRData = resultData;
				findPRs(resultData);
		}
	}

	function findPRs(resultData:ArchivedResults) {
		var prs:Array<String> = resultData.map(d -> d.toolVersions.get(HaxePR));

		for (pr in prs) {
			if (prList.contains(pr)) {
				continue;
			}
			prList.push(pr);
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
		for (key => value in benchesData) {
			haxeNightlyVersion = value.haxeNightlyData[value.haxeNightlyData.length - 1].haxeVersion;
		}
		prList.reverse();
		filterSettings.setPRVersions(prList);
	}

	function showData() {
		var target:Target = filterSettings.targets[0];
		showLatest("latestBenchmarks", 'latest benchmark results (lower is faster)', "runtime in seconds", target, (target) -> target.time);
		showLatest("latestCompileTimes", 'latest compile times (lower is faster)', "compile time in seconds", target, (target) -> target.compileTime);

		new JQuery(".targetCanvas").each(function(index:Int, element:Element) {
			var elem:JQuery = new JQuery(element);
			showHistory(target, elem.data("bench"), elem.attr("id"));
		});
	}

	function showLatest(chartId:String, title:String, labelY:String, target:Target, valueCallback:(target:TargetResult) -> TimeValue) {
		var labels:Array<String> = benchmarks;
		var haxeNightlyDataset = {
			label: haxeNightlyVersion,
			backgroundColor: "#66FF66",
			borderColor: "#33FF33",
			borderWidth: 1,
			data: [for (label in labels) null]
		};
		var haxePRDataset = {
			label: filterSettings.haxePRVersion,
			backgroundColor: "#6666FF",
			borderColor: "#0000FF",
			borderWidth: 1,
			data: [for (label in labels) null]
		};
		var data = {
			labels: labels,
			datasets: []
		};
		data.datasets.push(haxeNightlyDataset);
		data.datasets.push(haxePRDataset);
		for (bench in benchmarks) {
			extractLatestData(haxeNightlyDataset, bench, target, r -> r.haxeNightlyData, valueCallback);
			extractLatestPRData(haxePRDataset, bench, target, valueCallback);
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

	function extractLatestData(dataSet:Dynamic, bench:String, target:Target, datasetCallback:(allResults:PRBenchResults) -> ArchivedResults,
			valueCallback:(target:TargetResult) -> TimeValue) {
		var allResults:Null<PRBenchResults> = benchesData.get(bench);
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

	function findLatestPRRun(bench:String):TestRun {
		var allResults:Null<PRBenchResults> = benchesData.get(bench);
		if (allResults == null) {
			return null;
		}
		var results:Null<ArchivedResults> = allResults.haxePRData;
		if ((results == null) || (results.length <= 0)) {
			return null;
		}
		var runs:Array<TestRun> = results.filter(r -> r.toolVersions.get(HaxePR) == filterSettings.haxePRVersion);
		if (runs.length <= 0) {
			return null;
		}

		return runs[runs.length - 1];
	}

	function extractLatestPRData(dataSet:Dynamic, bench:String, target:Target, valueCallback:(target:TargetResult) -> TimeValue) {
		var lastRun:TestRun = findLatestPRRun(bench);
		if (lastRun == null) {
			return;
		}
		var index:Int = benchmarks.indexOf(bench);
		if (index < 0) {
			return;
		}

		for (dataTarget in lastRun.targets) {
			if (dataTarget.name != target) {
				continue;
			}
			dataSet.data[index] = valueCallback(dataTarget);
			return;
		}
	}

	public static function makeGraphDatasets(target:Target, prVersion:String):Array<GraphDatasetInfo> {
		return [
			BenchmarkJS.makeGraphDataset(HaxeNightly, false, target + " (Haxe nightly)", "#66FF66", "#66FF66"),
			BenchmarkJS.makeGraphDataset(HaxePR, false, '$target ($prVersion)', "#0000FF", "#0000FF"),
			BenchmarkJS.makeGraphDataset(HaxeNightly, true, target + " (Haxe nightly avg)", "#88FFCC", "#88FFCC"),
			BenchmarkJS.makeGraphDataset(HaxePR, true, '$target ($prVersion avg)', "#CCCCFF", "#CCCCFF"),
		];
	}

	function showHistory(target:Target, benchmarkName:String, canvasId:String) {
		var graphDataSets:Array<GraphDatasetInfo> = makeGraphDatasets(target, filterSettings.haxePRVersion);

		var allResults:PRBenchResults = benchesData.get(benchmarkName);
		if (allResults == null || allResults.haxePRData == null || allResults.haxeNightlyData == null) {
			new JQuery('#$canvasId').hide();
			return;
		}

		var haxeNightlyData:Null<ArchivedResults> = allResults.haxeNightlyData;
		var haxePRData:Null<ArchivedResults> = allResults.haxePRData;

		new JQuery('#$canvasId').show();

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

		datasetData = datasetData.concat(collectRunData(target, haxeNightlyData, HaxeNightly, valueCallback));
		var startDate:String = "";
		if (datasetData.length > 0) {
			startDate = datasetData.filter(d -> showDate(d.date))[0].date;
		}

		datasetData = datasetData.concat(getPRData(target, benchmarkName, startDate, valueCallback));

		datasetData.sort(BenchmarkJS.sortDate);
		datasetData = BenchmarkJS.mergeTimes(datasetData);

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

	function getPRData(target:Target, benchmarkName:String, startDate:String, valueCallback:(times:TargetTimeValues) -> TimeValue):Array<HistoricalDataPoint> {
		var datasetData:Array<HistoricalDataPoint> = [];

		var lastRun:TestRun = findLatestPRRun(benchmarkName);
		if (lastRun == null) {
			return [];
		}

		var times:Null<TargetTimeValues> = BenchmarkJS.getHistoryTime(lastRun, target);
		if (times == null) {
			return [];
		}
		var time:TimeValue = valueCallback(times);

		datasetData.push({
			time: [HaxePR => time],
			sma: [HaxePR => time],
			date: startDate
		});

		datasetData.push({
			time: [HaxePR => time],
			sma: [HaxePR => time],
			date: lastRun.date
		});

		return datasetData;
	}

	function versionSupportsTarget(version:DatasetType, target:Target):Bool {
		return switch (version) {
			case Haxe3:
				switch (target) {
					case Cpp | Cppia | Csharp | Hashlink | HashlinkC | Java | Neko | NodeJs | Php | Python | Lua | Luajit:
						true;
					case CppGCGen | HashlinkImmix | HashlinkCImmix | Jvm | NodeJsEs6 | Eval:
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

typedef PRBenchResults = {
	var haxeNightlyData:ArchivedResults;
	var haxePRData:ArchivedResults;
}
