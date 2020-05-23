import js.Browser;
import js.html.Element;
import js.jquery.Event;
import js.jquery.JQuery;
import data.ExponentialMovingAverage;
import data.IMovingAverage;
import data.SimpleMovingAverage;

class FilterSettings {
	static inline final BENCHMARK_COOKIE:String = "BenchmarkSettings";

	public var windowSize:Int;
	public var averageFactory:(windowSize:Int) -> IMovingAverage;
	public var showAverage:ShowAverage;
	public var average:AverageFunction;
	public var withHaxe3:Bool;
	public var withHaxe4:Bool;
	public var withHaxeNightly:Bool;
	public var startDate:Null<Float>;
	public var endDate:Null<Float>;
	public var targets:Array<Target>;
	public var timesSelection:TimesSelection;

	var defaultSettings:String;
	var updateGraphsCB:UpdateGraphs;

	public function new(updateGraphsCB:UpdateGraphs) {
		this.updateGraphsCB = updateGraphsCB;
		windowSize = 13;
		averageFactory = SimpleMovingAverage.new;
		average = Simple;
		showAverage = DataAndAverage;
		withHaxe3 = true;
		withHaxe4 = true;
		withHaxeNightly = true;
		timesSelection = Runtime;
		startDate = Date.now().getTime() - 20 * 24 * 60 * 60 * 1000;
		targets = Target.allTargets;
		defaultSettings = buildSettingsText();

		new JQuery("#onlyAverage").change(changeOnlyAverage);
		new JQuery("#average").change(changeAverage);
		new JQuery("#averageWindow").change(changeAverageWindow);
		new JQuery("#withHaxe3").change(changeWithHaxe3);
		new JQuery("#withHaxe4").change(changeWithHaxe4);
		new JQuery("#withHaxeNightly").change(changeWithHaxeNightly);
		new JQuery("#allTargets").change(changeAllTargets);
		new JQuery("#noTargets").change(changeNoTargets);
		new JQuery(".targetCheckbox").change(changeTargets);
		new JQuery(".timesSelect").change(changeTimeselection);

		untyped new JQuery("#startDate").change(changeRange).datepicker({dateFormat: "yy-mm-dd"});
		untyped new JQuery("#endDate").change(changeRange).datepicker({dateFormat: "yy-mm-dd"});
		loadSettings();
		new JQuery(Browser.window).on("hashchange", loadSettings);
	}

	public function hasTarget(target:Target):Bool {
		return (targets.indexOf(target) >= 0);
	}

	function updateGraphs(userChange:Bool) {
		if (userChange) {
			saveSettings();
		}
		updateGraphsCB();
	}

	function loadSettings() {
		var hash:String = Browser.window.location.hash;
		if ((hash == null) || (hash.trim().length <= 0)) {
			hash = Browser.window.localStorage.getItem(BENCHMARK_COOKIE);
		}
		if ((hash == null) || (hash.trim().length <= 0)) {
			hash = defaultSettings;
		}
		if (hash.startsWith("#")) {
			hash = hash.substr(1);
		}
		var settings:Array<String> = hash.split(";");
		windowSize = Std.parseInt(settings.shift());
		withHaxe3 = settings.shift() == "true";
		withHaxe4 = settings.shift() == "true";
		withHaxeNightly = settings.shift() == "true";
		showAverage = cast settings.shift();
		average = cast settings.shift();
		switch (average) {
			case None:
				averageFactory = SimpleMovingAverage.new;
			case Simple:
				averageFactory = SimpleMovingAverage.new;
			case Exponential:
				averageFactory = ExponentialMovingAverage.new;
			case _:
				averageFactory = SimpleMovingAverage.new;
		}
		startDate = readDateVal(settings.shift());
		endDate = readDateVal(settings.shift());
		var targetList:Null<String> = settings.shift();
		if ((targetList == null) || (targetList == "all")) {
			targets = Target.allTargets;
		} else {
			targets = targetList.split(",").map(t -> cast t.urlDecode()).filter(t -> switch ((t : Target)) {
				case Cpp | CppGCGen | Cppia | Csharp | Hashlink | HashlinkC | HashlinkImmix | HashlinkCImmix | Java | Jvm | Neko | NodeJs | NodeJsEs6 | Php |
					Python | Eval | Lua | Luajit: true;
				default: false;
			});
		}
		timesSelection = cast settings.shift();
		updateSettings();
	}

	function buildSettingsText():String {
		var settings:Array<String> = [];
		settings.push('$windowSize');
		settings.push('$withHaxe3');
		settings.push('$withHaxe4');
		settings.push('$withHaxeNightly');
		settings.push('$showAverage');
		settings.push(new JQuery("#average").val());
		if (startDate == null) {
			settings.push("");
		} else {
			settings.push('${Date.fromTime(startDate).format("%Y-%m-%d")}');
		}
		if (endDate == null) {
			settings.push("");
		} else {
			settings.push('${Date.fromTime(endDate).format("%Y-%m-%d")}');
		}
		if (targets.length == Target.allTargets.length) {
			settings.push("all");
		} else {
			settings.push(targets.map(t -> t.urlEncode()).join(","));
		}
		settings.push('$timesSelection');
		return settings.join(";");
	}

	function saveSettings() {
		var settingsText:String = buildSettingsText();

		if (defaultSettings == settingsText) {
			settingsText = "";
		}
		Browser.window.localStorage.setItem(BENCHMARK_COOKIE, settingsText);
		Browser.window.location.hash = settingsText;
	}

	function updateSettings() {
		switch (showAverage) {
			case JustData:
				new JQuery("#onlyAverage").prop("checked", false);
			case OnlyAverage:
				new JQuery("#onlyAverage").prop("checked", true);
			case DataAndAverage:
				new JQuery("#onlyAverage").prop("checked", false);
		}

		new JQuery("#average").val(cast average);
		new JQuery("#averageWindow").val('$windowSize');
		new JQuery("#withHaxe3").prop("checked", withHaxe3);
		new JQuery("#withHaxe4").prop("checked", withHaxe4);
		new JQuery("#withHaxeNightly").prop("checked", withHaxeNightly);

		new JQuery("#allTargets").prop("checked", targets.length == Target.allTargets.length);
		new JQuery("#noTargets").prop("checked", targets.length == 0);

		new JQuery(".targetCheckbox").each(function(index:Int, element:Element) {
			var elem:JQuery = new JQuery(element);
			elem.prop("checked", hasTarget(elem.data("target")));
		});
		switch (timesSelection) {
			case Compiletime:
				new JQuery("#timesCompiletime").prop("checked", true);
			case _:
				new JQuery("#timesRuntime").prop("checked", true);
		}

		updateDateVal("#startDate", startDate);
		updateDateVal("#endDate", endDate);
		updateGraphs(false);
	}

	function updateDateVal(selector:String, date:Null<Float>) {
		var dateField:JQuery = new JQuery(selector);
		if (date == null) {
			dateField.val("");
			return;
		}
		dateField.val(Date.fromTime(date).format("%Y-%m-%d"));
	}

	function changeOnlyAverage(event:Event) {
		var show:Bool = new JQuery("#onlyAverage").is(":checked");
		if (show) {
			switch (showAverage) {
				case JustData:
					showAverage = OnlyAverage;
				case OnlyAverage:
				case DataAndAverage:
					showAverage = OnlyAverage;
			}
		} else {
			switch (showAverage) {
				case JustData:
				case OnlyAverage:
					showAverage = DataAndAverage;
				case DataAndAverage:
			}
		}
		updateGraphs(true);
	}

	function changeWithHaxe3(event:Event) {
		withHaxe3 = new JQuery("#withHaxe3").is(":checked");
		updateGraphs(true);
	}

	function changeWithHaxe4(event:Event) {
		withHaxe4 = new JQuery("#withHaxe4").is(":checked");
		updateGraphs(true);
	}

	function changeWithHaxeNightly(event:Event) {
		withHaxeNightly = new JQuery("#withHaxeNightly").is(":checked");
		updateGraphs(true);
	}

	function changeRange(event:Event) {
		startDate = readDateVal(new JQuery("#startDate").val());
		endDate = readDateVal(new JQuery("#endDate").val());
		updateGraphs(true);
	}

	function readDateVal(dateVal:String):Null<Float> {
		if ((dateVal == null) || (dateVal.trim().length <= 0)) {
			return null;
		} else {
			return Date.fromString(dateVal).getTime();
		}
	}

	function changeAverage(event:Event) {
		switch (new JQuery("#average").val()) {
			case "SMA":
				switch (showAverage) {
					case JustData:
						showAverage = DataAndAverage;
					case OnlyAverage:
					case DataAndAverage:
				}
				averageFactory = SimpleMovingAverage.new;
			case "EMA":
				switch (showAverage) {
					case JustData:
						showAverage = DataAndAverage;
					case OnlyAverage:
					case DataAndAverage:
				}
				averageFactory = ExponentialMovingAverage.new;
			default:
				switch (showAverage) {
					case JustData:
					case OnlyAverage:
						showAverage = JustData;
					case DataAndAverage:
						showAverage = JustData;
				}
				new JQuery("#onlyAverage").prop("checked", false);
				averageFactory = SimpleMovingAverage.new;
		}
		updateGraphs(true);
	}

	function changeAverageWindow(event:Event) {
		windowSize = Std.parseInt(new JQuery("#averageWindow").val());
		changeAverage(event);
	}

	function changeAllTargets(event:Event) {
		if (new JQuery("#allTargets").is(":checked")) {
			targets = Target.allTargets;
		}
		updateGraphs(true);
	}

	function changeNoTargets(event:Event) {
		if (new JQuery("#noTargets").is(":checked")) {
			targets = [];
		}
		updateGraphs(true);
	}

	function changeTargets(event:Event) {
		var newTargets:Array<Target> = [];
		new JQuery(".targetCheckbox").each(function(index:Int, element:Element) {
			var elem:JQuery = new JQuery(element);
			if (elem.is(":checked")) {
				newTargets.push(elem.data("target"));
			}
		});

		targets = Target.allTargets.filter(t -> newTargets.contains(t));

		if (targets.length == Target.allTargets.length) {
			new JQuery("#allTargets").prop("checked", true);
			new JQuery("#noTargets").prop("checked", false);
		} else {
			if (targets.length == 0) {
				new JQuery("#noTargets").prop("checked", true);
			} else {
				new JQuery("#noTargets").prop("checked", false);
			}
			new JQuery("#allTargets").prop("checked", false);
		}
		updateGraphs(true);
	}

	function changedTarget(selector:String, newTargets:Array<Target>, target:Target) {
		if (new JQuery(selector).is(":checked")) {
			newTargets.push(target);
		}
	}

	function changeTimeselection(event:Event) {
		timesSelection = cast new JQuery(event.target).val();
		updateGraphs(true);
	}
}

enum abstract ShowAverage(String) {
	var JustData;
	var OnlyAverage;
	var DataAndAverage;
}

enum abstract AverageFunction(String) {
	var None = "none";
	var Simple = "SMA";
	var Exponential = "EMA";
}

typedef UpdateGraphs = () -> Void;

enum abstract TimesSelection(String) {
	var Runtime = "runtime";
	var Compiletime = "compiletime";
}
