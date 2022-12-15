import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Weather;
import Toybox.Time;
import Toybox.Time.Gregorian;

class TimelyFenixView extends WatchUi.WatchFace {
	const MASK_DATE = 0x7FFFF800 as Integer;
	const MASK_AM_PM = 0x400 as Integer;
	const MASK_CHARGING = 0x80 as Integer;

	var _timestamp = 0 as Integer;
	var _batteryState = 0 as Integer;
	var _weatherState = 0 as Integer;
	var _degreesSymbol = 0 as String;
	var _weatherUpdatePeriod = 0 as Integer;
	var _screenBuffer = 0 as BufferedBitmap;
	var _bufferDc = 0 as Dc;
	
	var _weatherFont = 0 as FontResource;

	// Cached settings
	var _foregroundColor = 0 as Number;

	function initialize() {
		WatchFace.initialize();
	}

	function generateTimestamp(timeInfo as Gregorian.Info) as Integer {
		return (timeInfo.min) // 6 bits
			| (timeInfo.hour << 6) // 4 bits
			| (timeInfo.hour >= 12 ? MASK_AM_PM : 0) // 1 bit
			| (timeInfo.day << 11) // 5 bits
			| (timeInfo.month << 16) // 4 bits
			| ((timeInfo.year-2000) << 20); // 12 bits
	}

	// Load your resources here
	function onLayout(dc as Dc) as Void {
		_degreesSymbol = WatchUi.loadResource(Rez.Strings.DegreesSymbol);
		_weatherFont = WatchUi.loadResource(Rez.Fonts.WeatherIcons);
		_weatherUpdatePeriod = Properties.getValue("WeatherUpdatePeriod");
		_foregroundColor = Properties.getValue("ForegroundColor");

		_screenBuffer = new Graphics.BufferedBitmap({
			:width  => 226,
			:height => 218
		});
		_bufferDc = _screenBuffer.getDc();

		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
		dc.clear();
	}

	// Called when this View is brought to the foreground. Restore
	// the state of this View and prepare it to be shown. This includes
	// loading resources into memory.
	function onShow() as Void {
		_timestamp = 0;
		_batteryState = 0;
	}

	function celsiusToFahrenheit(weather as CurrentConditions) as Number {
		return weather.temperature * 9 / 5 + 32;
	}

	function daysPerMonth(month as Integer, year as Integer) as Integer {
		// Special case for rollover going back from January to December
		if (month == 0) {
			return 31;
		}

		var boundMonth = (month - 1) % 12 + 1 as Integer;
		var days = (boundMonth / 8 + boundMonth) % 2 + 30 as Integer;
		if (month == 2) {
			days -= 2;
			if (year % 4 == 0) {
				days++;
			}
		}
		return days;
	}

	// Update the view
	function onUpdate(dc as Dc) as Void {
		var timeInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT) as Gregorian.Info;
		var timestampNow = generateTimestamp(timeInfo) as Integer;
		var bufferDc = _bufferDc as Dc;
		var fullDraw = false as Boolean;

		// Daily Updates
		if (timestampNow & MASK_DATE != _timestamp & MASK_DATE) {
			// clear whole buffer
			fullDraw = true;
			bufferDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
			bufferDc.clear();

			// draw all grid lines to buffer
			drawGridLines();

			// draw calendar values to buffer
			drawCalendar(timeInfo);
		}
		// AM/PM Updates
		if ((timestampNow & MASK_AM_PM != _timestamp & MASK_AM_PM) || fullDraw) {
			// draw AM/PM text to buffer
			drawAmPm(timeInfo, fullDraw);
		}
		// Update weather on user-configured interval
		if ((timeInfo.min % _weatherUpdatePeriod == 0 && timestampNow != _timestamp) || _weatherState == 0 || fullDraw) {
			// draw weather icon/values to buffer
			drawWeather(fullDraw);
		}
		if (timestampNow != _timestamp || fullDraw) {
			// draw time text to buffer
			drawTime(timeInfo, fullDraw);
			_timestamp = timestampNow;
		}

		var sysStats = System.getSystemStats() as Stats;
		var batteryStateNow = sysStats.battery.toNumber() as Integer;
		if (sysStats.charging) {
			batteryStateNow |= MASK_CHARGING;
		}
		if (batteryStateNow != _batteryState || fullDraw) {
			// draw battery icon/values to buffer
			drawBattery(sysStats, fullDraw);
			_batteryState = batteryStateNow;
		}

		// always draw buffer to screen
		dc.drawBitmap(9, 7, _screenBuffer);
	}

	function drawWeather(fullDraw as Boolean) as Void {
		var bufferDc = _bufferDc as Dc;
		bufferDc.setClip(71, 0, 135, 66);
		bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
		if (!fullDraw) {
			bufferDc.clear();
		}

		var weather = Weather.getCurrentConditions() as CurrentConditions;
		if (weather == null || weather.temperature == null) {
			bufferDc.drawText(190, 38, Graphics.FONT_TINY, "--" + _degreesSymbol + "F", Graphics.TEXT_JUSTIFY_RIGHT);
			_weatherState = 0;
		} else {
			// Weather data always comes as Celsius
			var temperature = celsiusToFahrenheit(weather) as Integer;
			bufferDc.drawText(190, 38, Graphics.FONT_TINY, temperature + _degreesSymbol + "F", Graphics.TEXT_JUSTIFY_RIGHT);
			_weatherState = 1;
		}

		if (weather == null || weather.precipitationChance == null) {
			bufferDc.drawText(187, 17, Graphics.FONT_TINY, "--%", Graphics.TEXT_JUSTIFY_RIGHT);
		} else {
			bufferDc.drawText(187, 17, Graphics.FONT_TINY, weather.precipitationChance + "%", Graphics.TEXT_JUSTIFY_RIGHT);
		}

		var weatherChar = "A" as String;
		if (weather == null || weather.condition == null) {
			// Missing Weather icon
			bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
		} else {
			weatherChar = getWeatherIcon(weather);
		}
		bufferDc.drawText(104, 0, _weatherFont, weatherChar, Graphics.TEXT_JUSTIFY_CENTER);

		bufferDc.clearClip();
	}

	function drawBattery(sysStats as Stats, fullDraw as Boolean) as Void {
		var bufferDc = _bufferDc as Dc;
		var chargingNow = sysStats.charging as Boolean;
		var batteryPercentNow = sysStats.battery.toNumber() as Integer;

		bufferDc.setClip(8, 21, 58, 41);
		bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
		if (!fullDraw) {
			bufferDc.clear();
		}
		bufferDc.setPenWidth(2);
		bufferDc.drawRoundedRectangle(33, 24, 27, 14, 2);
		bufferDc.drawRectangle(60, 27, 2, 7);
		bufferDc.setPenWidth(1);

		var batteryFill = (batteryPercentNow + 4) / 5;
		if (chargingNow) {
			bufferDc.setColor(0xFFFF00, Graphics.COLOR_TRANSPARENT);
			bufferDc.fillPolygon([[12,45],[9,54],[11,52],[10,60],[15,52],[12,54],[16,45]]);
			bufferDc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
			bufferDc.drawText(65, 38, Graphics.FONT_TINY, batteryPercentNow + "%", Graphics.TEXT_JUSTIFY_RIGHT);
		} else {
			bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
			bufferDc.drawText(65, 38, Graphics.FONT_TINY, batteryPercentNow + "%", Graphics.TEXT_JUSTIFY_RIGHT);
			if (batteryPercentNow > 25) {
				bufferDc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
			} else if (batteryPercentNow > 10) {
				bufferDc.setColor(0xFFFF00, Graphics.COLOR_TRANSPARENT);
			} else {
				bufferDc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
			}
		}

		bufferDc.fillRectangle(36, 27, batteryFill, 7);
		bufferDc.clearClip();
	}

	function drawGridLines() as Void {
		var bufferDc = _bufferDc as Dc;
		// Battery/Weather separators
		bufferDc.drawLine(69, 0, 69, 68);
		bufferDc.drawLine(0, 68, 240, 68);

		// Calendar grid
		bufferDc.drawRectangle(27, 155, 168, 44); // Outer rectangle
		bufferDc.drawRectangle(27, 170, 168, 15); // Inner row rectangle
		bufferDc.drawRectangle(51, 155, 25, 44); // 2nd col rectangle
		bufferDc.drawRectangle(99, 155, 25, 44); // 4th col rectangle
		bufferDc.drawRectangle(147, 155, 25, 44); // 6th col rectangle
	}

	function drawTime(timeInfo as Gregorian.Info, fullDraw as Boolean) as Void {
		var bufferDc = _bufferDc as Dc;
		bufferDc.setClip(6, 77, 177, 60);
		bufferDc.setColor(_foregroundColor, Graphics.COLOR_BLACK);
		// clear time clip in buffer
		if (!fullDraw) {
			bufferDc.clear();
		}
		// draw time to buffer
		var hours = timeInfo.hour as Integer;
		if (hours > 12) {
			hours -= 12;
		} else if (hours == 0) {
			hours = 12;
		}
		bufferDc.drawText(183, 57, Graphics.FONT_NUMBER_THAI_HOT,
			hours + ":" + timeInfo.min.format("%02d"), Graphics.TEXT_JUSTIFY_RIGHT);
		bufferDc.clearClip();
	}

	function drawAmPm(timeInfo as Gregorian.Info, fullDraw as Boolean) as Void {
		var bufferDc = _bufferDc as Dc;
		bufferDc.setClip(183, 108, 43, 27);
		bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
		// clear time clip in buffer
		if (!fullDraw) {
			bufferDc.clear();
		}
		// draw time to buffer
		if (timeInfo.hour >= 12) {
			bufferDc.drawText(225, 103, Graphics.FONT_LARGE, "PM", Graphics.TEXT_JUSTIFY_RIGHT);
		} else {
			bufferDc.drawText(225, 103, Graphics.FONT_LARGE, "AM", Graphics.TEXT_JUSTIFY_RIGHT);
		}
		bufferDc.clearClip();
	}

	function drawCalendar(timeInfo as Gregorian.Info) as Void {
		var bufferDc = _bufferDc as Dc;
		// Days of week, with current day highlighted
		var daysOfWeek = ["Su","Mo","Tu","We","Th","Fr","Sa"] as Array<String>;
		for (var i = 0 as Integer; i < 7; i++) {
			if (i+1 == timeInfo.day_of_week) {
				bufferDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			} else {
				bufferDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
			}
			bufferDc.drawText(24*i+39, 138, Graphics.FONT_XTINY, daysOfWeek[i], Graphics.TEXT_JUSTIFY_CENTER);
		}

		// Previous, current, and next week, with current day inverted
		// Arrange days on calendar view
		var firstDateShown = timeInfo.day - timeInfo.day_of_week - 6 as Integer;
		var currentMonthDays = daysPerMonth(timeInfo.month, timeInfo.year) as Integer;
		var prevMonthDays = daysPerMonth(timeInfo.month-1, timeInfo.year) as Integer;
		for (var i = 0 as Integer; i < 21; i++) {
			var dayNum = firstDateShown+i as Integer;
			if (dayNum < 1) {
				dayNum += prevMonthDays;
				bufferDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
			} else if (dayNum > currentMonthDays) {
				dayNum -= currentMonthDays;
				bufferDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
			} else if (dayNum == timeInfo.day) {
				bufferDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
				bufferDc.fillRectangle((i - 7) * 24 + 28, 170, 23, 14);
				bufferDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			} else {
				bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
			}
			bufferDc.drawText((i % 7) * 24 + 39, (i / 7) * 14 + 153, Graphics.FONT_XTINY,
				dayNum.toString(), Graphics.TEXT_JUSTIFY_CENTER);
		}

		var months = ["January","February","March","April","May","June","July",
			"August","September","October","November","December"] as Array<String>;
		bufferDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
		bufferDc.drawText(110, 198, Graphics.FONT_XTINY, months[timeInfo.month-1] +
			" " + timeInfo.day + ", " + timeInfo.year, Graphics.TEXT_JUSTIFY_CENTER);
	}

	// Called when this View is removed from the screen. Save the
	// state of this View here. This includes freeing resources from
	// memory.
	function onHide() as Void {
	}

	// The user has just looked at their watch. Timers and animations may be started here.
	function onExitSleep() as Void {
	}

	// Terminate any active timers and prepare for slow updates.
	function onEnterSleep() as Void {
	}

	function getWeatherIcon(weather as CurrentConditions) as String {
		var clockTime;
		switch (weather.condition) {
			case Weather.CONDITION_HAIL:
				_bufferDc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
				return "B";
			case Weather.CONDITION_CHANCE_OF_SHOWERS:
			case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN:
			case Weather.CONDITION_DRIZZLE:
			case Weather.CONDITION_HEAVY_RAIN:
			case Weather.CONDITION_HEAVY_SHOWERS:
			case Weather.CONDITION_LIGHT_RAIN:
			case Weather.CONDITION_LIGHT_SHOWERS:
			case Weather.CONDITION_RAIN:
			case Weather.CONDITION_SCATTERED_SHOWERS:
			case Weather.CONDITION_SHOWERS:
				_bufferDc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
				return "C";
			case Weather.CONDITION_FOG:
			case Weather.CONDITION_HAZE:
			case Weather.CONDITION_HAZY:
			case Weather.CONDITION_MIST:
			case Weather.CONDITION_SAND:
			case Weather.CONDITION_SMOKE:
			case Weather.CONDITION_VOLCANIC_ASH:
				_bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
				return "D";
			case Weather.CONDITION_CHANCE_OF_THUNDERSTORMS:
			case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
			case Weather.CONDITION_THUNDERSTORMS:
				_bufferDc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
				return "E";
			case Weather.CONDITION_CLOUDY:
			case Weather.CONDITION_MOSTLY_CLOUDY:
			case Weather.CONDITION_UNKNOWN_PRECIPITATION:
				_bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
				return "F";
			case Weather.CONDITION_FAIR:
			case Weather.CONDITION_THIN_CLOUDS:
			case Weather.CONDITION_MOSTLY_CLEAR:
			case Weather.CONDITION_PARTLY_CLEAR:
			case Weather.CONDITION_PARTLY_CLOUDY:
				_bufferDc.setColor(0xAAAA55, Graphics.COLOR_TRANSPARENT);
				clockTime = System.getClockTime() as ClockTime;
				if (clockTime.hour >= 7 && clockTime.hour <= 20) {
					// Daytime
					return "G";
				} else {
					// Nighttime
					return "H";
				}
			case Weather.CONDITION_CHANCE_OF_RAIN_SNOW:
			case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW:
			case Weather.CONDITION_FREEZING_RAIN:
			case Weather.CONDITION_HEAVY_RAIN_SNOW:
			case Weather.CONDITION_LIGHT_RAIN_SNOW:
			case Weather.CONDITION_SLEET:
			case Weather.CONDITION_WINTRY_MIX:
				_bufferDc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
				return "I";
			case Weather.CONDITION_ICE:
				_bufferDc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
				return "J";
			case Weather.CONDITION_CLEAR:
				_bufferDc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
				clockTime = System.getClockTime() as ClockTime;
				if (clockTime.hour >= 7 && clockTime.hour <= 20) {
					// Daytime
					return "K";
				} else {
					// Nighttime
					return "O";
				}
			case Weather.CONDITION_HURRICANE:
			case Weather.CONDITION_TORNADO:
			case Weather.CONDITION_TROPICAL_STORM:
				_bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
				return "L";
			case Weather.CONDITION_DUST:
			case Weather.CONDITION_SANDSTORM:
			case Weather.CONDITION_SQUALL:
			case Weather.CONDITION_WINDY:
				_bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
				return "M";
			case Weather.CONDITION_CHANCE_OF_SNOW:
			case Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW:
			case Weather.CONDITION_FLURRIES:
			case Weather.CONDITION_HEAVY_SNOW:
			case Weather.CONDITION_ICE_SNOW:
			case Weather.CONDITION_LIGHT_SNOW:
			case Weather.CONDITION_RAIN_SNOW:
			case Weather.CONDITION_SNOW:
				_bufferDc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
				return "N";
			case Weather.CONDITION_UNKNOWN:
			default:
				break;
		}
		_bufferDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
		return "A";
	}
}
