package data;

import benchmark.data.TestRun.TimeValue;

interface IMovingAverage {
	public function addValue(value:Null<Float>):Void;
	public function getAverage():Null<TimeValue>;
}
