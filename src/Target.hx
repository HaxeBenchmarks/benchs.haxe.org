enum abstract Target(String) to String {
	var Cpp = "C++";
	var CppGCGen = "C++ (GC Gen)";
	var Cppia = "Cppia";
	var Csharp = "C#";
	var Hashlink = "HashLink";
	var HashlinkC = "HashLink/C";
	var HashlinkImmix = "HashLink Immix";
	var HashlinkCImmix = "HashLink/C Immix";
	var Java = "Java";
	var Jvm = "JVM";
	var Neko = "Neko";
	var NodeJs = "NodeJS";
	var NodeJsEs6 = "NodeJS (ES6)";
	var Php = "PHP";
	var Python = "Python";
	var Eval = "Eval";
	var Lua = "Lua";
}

final allTargets:Array<Target> = [
	Cpp, CppGCGen, Cppia, Csharp, Hashlink, HashlinkC, HashlinkImmix, HashlinkCImmix, Java, Jvm, Eval, Neko, NodeJs, NodeJsEs6, Php, Python, Lua
];

abstract TargetId(Target) {
	function new(target:Target) {
		this = target;
	}

	@:from
	public static function fromTarget(target:Target):TargetId {
		return new TargetId(target);
	};

	@:to
	public function toString():String {
		var id:String = this.replace("+", "p");

		var r:EReg = ~/[^_a-zA-Z0-9]/g;
		id = r.replace(id, "_");
		r = ~/^[^_a-zA-Z]/;
		return r.replace(id, "_");
	}
}
