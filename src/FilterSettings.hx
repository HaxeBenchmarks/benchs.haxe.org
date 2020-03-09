import js.Browser;
import js.jquery.Event;
import js.jquery.JQuery;
import BenchmarkJS.Target;
import data.ExponentialMovingAverage;
import data.IMovingAverage;
import data.SimpleMovingAverage;

class FilterSettings {
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

	var updateGraphsCB:UpdateGraphs;

	public function new(updateGraphsCB:UpdateGraphs) {
		this.updateGraphsCB = updateGraphsCB;
		windowSize = 6;
		averageFactory = SimpleMovingAverage.new;
		average = Simple;
		showAverage = DataAndAverage;
		withHaxe3 = true;
		withHaxe4 = true;
		withHaxeNightly = true;
		startDate = Date.now().getTime() - 20 * 24 * 60 * 60 * 1000;
		targets = allTargets();

		new JQuery("#onlyAverage").change(changeOnlyAverage);
		new JQuery("#average").change(changeAverage);
		new JQuery("#averageWindow").change(changeAverageWindow);
		new JQuery("#withHaxe3").change(changeWithHaxe3);
		new JQuery("#withHaxe4").change(changeWithHaxe4);
		new JQuery("#withHaxeNightly").change(changeWithHaxeNightly);
		new JQuery("#allTargets").change(changeAllTargets);
		new JQuery("#targetCpp").change(changeTargets);
		new JQuery("#targetCSharp").change(changeTargets);
		new JQuery("#targetEval").change(changeTargets);
		new JQuery("#targetHashlink").change(changeTargets);
		new JQuery("#targetHashlinkC").change(changeTargets);
		new JQuery("#targetJava").change(changeTargets);
		new JQuery("#targetJvm").change(changeTargets);
		new JQuery("#targetNeko").change(changeTargets);
		new JQuery("#targetNodeJs").change(changeTargets);
		new JQuery("#targetNodeJsES6").change(changeTargets);
		new JQuery("#targetPHP").change(changeTargets);
		new JQuery("#targetPython").change(changeTargets);

		untyped new JQuery("#startDate").change(changeRange).datepicker({dateFormat: "yy-mm-dd"});
		untyped new JQuery("#endDate").change(changeRange).datepicker({dateFormat: "yy-mm-dd"});
		loadSettings();
		new JQuery(Browser.window).on("hashchange", loadSettings);
	}

	public function hasTarget(target:Target):Bool {
		return (targets.indexOf(target) >= 0);
	}

	inline function allTargets():Array<Target> {
		return [
			Cpp, Csharp, Eval, Hashlink, HashlinkC, Java, Jvm, Neko, NodeJs, NodeJsEs6, Php, Python
		];
	}

	function updateGraphs() {
		saveSettings();
		updateGraphsCB();
	}

	function loadSettings() {
		var hash:String = Browser.window.location.hash;
		if ((hash != null) && (hash.trim().length > 0)) {
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
				targets = allTargets();
			} else {
				targets = targetList.split(",").map(t -> cast t.urlDecode()).filter(t -> switch (t) {
					case Cpp | Csharp | Hashlink | HashlinkC | Java | Jvm | Neko | NodeJs | NodeJsEs6 | Php | Python | Eval: true;
					default: false;
				});
				trace(targets);
			}
		}
		updateSettings();
	}

	function saveSettings() {
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
		if (targets.length == allTargets().length) {
			settings.push("all");
		} else {
			settings.push(targets.map(t -> t.urlEncode()).join(","));
		}
		Browser.window.location.hash = settings.join(";");
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

		new JQuery("#allTargets").prop("checked", targets.length == allTargets().length);
		new JQuery("#targetCpp").prop("checked", hasTarget(Cpp));
		new JQuery("#targetCSharp").prop("checked", hasTarget(Csharp));
		new JQuery("#targetEval").prop("checked", hasTarget(Eval));
		new JQuery("#targetHashlink").prop("checked", hasTarget(Hashlink));
		new JQuery("#targetHashlinkC").prop("checked", hasTarget(HashlinkC));
		new JQuery("#targetJava").prop("checked", hasTarget(Java));
		new JQuery("#targetJvm").prop("checked", hasTarget(Jvm));
		new JQuery("#targetNeko").prop("checked", hasTarget(Neko));
		new JQuery("#targetNodeJs").prop("checked", hasTarget(NodeJs));
		new JQuery("#targetNodeJsES6").prop("checked", hasTarget(NodeJsEs6));
		new JQuery("#targetPHP").prop("checked", hasTarget(Php));
		new JQuery("#targetPython").prop("checked", hasTarget(Python));

		updateDateVal("#startDate", startDate);
		updateDateVal("#endDate", endDate);
		updateGraphs();
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
		updateGraphs();
	}

	function changeWithHaxe3(event:Event) {
		withHaxe3 = new JQuery("#withHaxe3").is(":checked");
		updateGraphs();
	}

	function changeWithHaxe4(event:Event) {
		withHaxe4 = new JQuery("#withHaxe4").is(":checked");
		updateGraphs();
	}

	function changeWithHaxeNightly(event:Event) {
		withHaxeNightly = new JQuery("#withHaxeNightly").is(":checked");
		updateGraphs();
	}

	function changeRange(event:Event) {
		startDate = readDateVal(new JQuery("#startDate").val());
		endDate = readDateVal(new JQuery("#endDate").val());
		updateGraphs();
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
		updateGraphs();
	}

	function changeAverageWindow(event:Event) {
		windowSize = Std.parseInt(new JQuery("#averageWindow").val());
		changeAverage(event);
	}

	function changeAllTargets(event:Event) {
		if (new JQuery("#allTargets").is(":checked")) {
			targets = allTargets();
		}
		updateGraphs();
	}

	function changeTargets(event:Event) {
		var newTargets:Array<Target> = [];
		changedTarget("#targetCpp", newTargets, Cpp);
		changedTarget("#targetCSharp", newTargets, Csharp);
		changedTarget("#targetEval", newTargets, Eval);
		changedTarget("#targetHashlink", newTargets, Hashlink);
		changedTarget("#targetHashlinkC", newTargets, HashlinkC);
		changedTarget("#targetJava", newTargets, Java);
		changedTarget("#targetJvm", newTargets, Jvm);
		changedTarget("#targetNeko", newTargets, Neko);
		changedTarget("#targetNodeJs", newTargets, NodeJs);
		changedTarget("#targetNodeJsES6", newTargets, NodeJsEs6);
		changedTarget("#targetPHP", newTargets, Php);
		changedTarget("#targetPython", newTargets, Python);
		if (newTargets.length == allTargets().length) {
			targets = allTargets();
			new JQuery("#allTargets").prop("checked", true);
		} else {
			targets = newTargets;
			new JQuery("#allTargets").prop("checked", false);
		}
		updateGraphs();
	}

	function changedTarget(selector:String, newTargets:Array<Target>, target:Target) {
		if (new JQuery(selector).is(":checked")) {
			newTargets.push(target);
		}
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
