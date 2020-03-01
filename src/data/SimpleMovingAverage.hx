package data;

import data.TestRun.TimeValue;

class SimpleMovingAverage implements IMovingAverage {
	var values:Array<Float>;
	var windowSize:Int;
	var total:Float;

	public function new(windowSize:Int) {
		values = [];
		total = 0;
		this.windowSize = windowSize;
	}

	public function addValue(value:Null<Float>) {
		if (value == null) {
			return;
		}
		values.push(value);
		total += value;
		if (values.length > windowSize) {
			total -= values.shift();
		}
	}

	public function getAverage():Null<TimeValue> {
		if (values.length < windowSize) {
			return null;
		}
		return total / values.length;
	}
}
