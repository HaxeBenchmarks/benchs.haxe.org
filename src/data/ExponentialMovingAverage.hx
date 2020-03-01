package data;

import data.TestRun.TimeValue;

class ExponentialMovingAverage implements IMovingAverage {
	var values:Array<Float>;
	var windowSize:Int;
	var prevEMA:Null<Float>;
	var currEMA:Null<Float>;
	var alpha:Float;

	public function new(windowSize:Int) {
		values = [];
		prevEMA = null;
		currEMA = null;
		alpha = 2 / (windowSize + 1);
		this.windowSize = windowSize;
	}

	public function addValue(value:Null<Float>) {
		if (value == null) {
			return;
		}
		if (prevEMA == null) {
			values.push(value);
			if (values.length == windowSize) {
				var total:Float = 0;
				for (value in values) {
					total += value;
				}
				prevEMA = total / windowSize;
				currEMA = prevEMA;
			}
			return;
		}
		currEMA = value * alpha + prevEMA * (1 - alpha);
	}

	public function getAverage():Null<TimeValue> {
		return currEMA;
	}
}
