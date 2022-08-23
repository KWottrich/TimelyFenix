import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Weather;
import Toybox.Time;
import Toybox.Time.Gregorian;

class TimelyFenixView extends WatchUi.WatchFace {
	var degreesSymbol as String;
	var calendarDays as Array<Texts>;
	var dayOfWeek as Integer;
	var initialDraw as Boolean;
	var weatherFont as FontResource;
	var weatherChar as String;
	var weatherColor as Integer;
	var batteryPercent as Integer;
	var charging as Boolean;
	
	// Cached label references
	var timeLabel as Text;
	var amPmLabel as Text;
	var tempLabel as Text;
	var precipLabel as Text;
	var dateStringLabel as Text;
	var batteryLabel as Text;
	var daysOfWeekLabels as Array<Views>;
	
	// Cached settings
	var is24h as Boolean;
	var foregroundColor as Number;
	var weatherUpdatePeriod as Number;

    function initialize() {
        WatchFace.initialize();
        createCalendarDaysArray();
    }
    
    function createCalendarDaysArray() {
    	calendarDays = new [21];
    	for (var i = 0; i < 21; i++) {
    		calendarDays[i] = new WatchUi.Text({
	            :font => Graphics.FONT_XTINY,
	            :locX => (i % 7) * 24 + 48,
	            :locY => (i / 7) * 14 + 160,
	            :justification => Graphics.TEXT_JUSTIFY_CENTER
    		});
    	}
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        degreesSymbol = WatchUi.loadResource(Rez.Strings.DegreesSymbol);
        weatherFont = WatchUi.loadResource(Rez.Fonts.WeatherIcons);
        setLayout(Rez.Layouts.WatchFace(dc));
        timeLabel = View.findDrawableById("TimeLabel");
        amPmLabel = View.findDrawableById("AmPmLabel");
        tempLabel = View.findDrawableById("TempLabel");
        precipLabel = View.findDrawableById("PrecipLabel");
        dateStringLabel = View.findDrawableById("DateString");
        batteryLabel = View.findDrawableById("BatteryLabel");
        daysOfWeekLabels = [
        	View.findDrawableById("Sunday"),
        	View.findDrawableById("Monday"),
        	View.findDrawableById("Tuesday"),
        	View.findDrawableById("Wednesday"),
        	View.findDrawableById("Thursday"),
        	View.findDrawableById("Friday"),
        	View.findDrawableById("Saturday")
        ];
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    	is24h = System.getDeviceSettings().is24Hour;
    	var stats = System.getSystemStats() as Stats;
    	charging = stats.charging as Boolean;
    	batteryPercent = stats.battery.toNumber() as Integer;
    	foregroundColor = getApp().getProperty("ForegroundColor");
    	weatherUpdatePeriod = getApp().getProperty("WeatherUpdatePeriod");
    	updateCalendarValues();
    	initialDraw = true;
    }
    
    function viewUpdateTime(clockTime as ClockTime) as Void {
        var hours = clockTime.hour;
        if (!is24h) {
            if (hours > 12) {
                hours -= 12;
                amPmLabel.setText("PM");
            } else {
            	if (hours == 0) {
            		hours = 12;
            	}
            	amPmLabel.setText("AM");
            }
        }
        
        timeLabel.setText(hours + ":" + clockTime.min.format("%02d"));
    }
    
    function updateAmPm(clockTime as ClockTime) as Void {
    	amPmLabel.setText(clockTime.hour > 12 ? "PM" : "AM");
    }
    
    function celsiusToFahrenheit(weather as CurrentConditions) as Number {
        return weather.temperature * 9 / 5 + 32;
    }
    
    function viewUpdateWeather() as Void {
    	var weather = Weather.getCurrentConditions();
    	
    	if (weather == null || weather.temperature == null) {
    		tempLabel.setText("--" + degreesSymbol + "F");
    	} else {
    		// Weather data always comes as Celsius
    		var temperature = celsiusToFahrenheit(weather);
        	tempLabel.setText(temperature + degreesSymbol + "F");
    	}
    	
    	if (weather == null || weather.precipitationChance == null) {
    	    precipLabel.setText("--%");
    	} else {
        	precipLabel.setText(weather.precipitationChance + "%");
    	}
    	
    	if (weather == null || weather.condition == null) {
    		// Missing Weather icon
    	    weatherChar = "A";
    	    weatherColor = Graphics.COLOR_LT_GRAY;
    	} else {
    		mapWeatherCondToIcon(weather);
    	}
    }
    
    function drawCalendar(dc as Dc) as Void {
        // Battery/Weather separators
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawLine(78, 0, 78, 75);
        dc.drawLine(0, 75, 240, 75);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle((dayOfWeek-1) * 24 + 37, 177, 23, 14);
        
        for (var i = 0; i < 21; i++) {
        	calendarDays[i].draw(dc);
        }
    }
    
    function daysPerMonth(month as Integer, year as Integer) as Integer {
    	// Special case for rollover going back from January to December
    	if (month == 0) {
    		return 31;
    	}
    	
    	var boundMonth = (month - 1) % 12 + 1;
    	var days = (boundMonth / 8 + boundMonth) % 2 + 30;
    	if (month == 2) {
    		days -= 2;
    		if (year % 4 == 0) {
    			days++;
    		}
    	}
    	return days;
    }
    
    function updateCalendarValues() as Void {
    	var now = Time.today();
    	var timeInfo = Gregorian.info(now, Time.FORMAT_SHORT);
    	dayOfWeek = timeInfo.day_of_week;
    	for (var i = 0; i < 7; i++) {
    		if (i+1 == timeInfo.day_of_week) {
    			daysOfWeekLabels[i].setColor(Graphics.COLOR_WHITE);
    		} else {
    			daysOfWeekLabels[i].setColor(Graphics.COLOR_DK_GRAY);
    		}
    	}
    	
    	// Arrange days on calendar view
    	var firstDateShown = timeInfo.day - timeInfo.day_of_week - 6 as Integer;
    	var currentMonthDays = daysPerMonth(timeInfo.month, timeInfo.year) as Integer;
    	var prevMonthDays = daysPerMonth(timeInfo.month-1, timeInfo.year) as Integer;
    	for (var i = 0 as Integer; i < 21; i++) {
    		var dayNum = firstDateShown+i as Integer;
    		if (dayNum < 1) {
    			dayNum = prevMonthDays + dayNum;
    			calendarDays[i].setColor(Graphics.COLOR_DK_GRAY);
    		} else if (dayNum > currentMonthDays) {
    			dayNum = dayNum - currentMonthDays;
    			calendarDays[i].setColor(Graphics.COLOR_DK_GRAY);
    		} else if (dayNum == timeInfo.day) {
    			calendarDays[i].setColor(Graphics.COLOR_BLACK);
    		} else {
    			calendarDays[i].setColor(Graphics.COLOR_LT_GRAY);
    		}
    		calendarDays[i].setText(dayNum.format("%d"));
    	}
    	
    	var months = ["January","February","March","April","May","June","July",
    		"August","September","October","November","December"] as Array<Strings>;
    	dateStringLabel.setText(months[timeInfo.month-1] +
    		" " + timeInfo.day + ", " + timeInfo.year);
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Get the current time
        var clockTime = System.getClockTime() as ClockTime;
        // Update primary time values
        viewUpdateTime(clockTime);
        
        // Infrequent Updates
        if (clockTime.hour == 0 && clockTime.min == 0) {
        	updateCalendarValues();
        }

        // Only redraw whole layout on the hour, as it is computationally expensive
        if (clockTime.min == 0 || initialDraw) {
        	// Check for AM/PM update
        	updateAmPm(clockTime);
        	// Update Weather
        	viewUpdateWeather();
        	// Clear screen, redraw base layout
        	View.onUpdate(dc);
        	// Weather icon placeholder
	        drawWeatherIcon(dc);
	        // Calendar
	        drawCalendar(dc);
	        
	    	batteryPercent = -1;
	    	initialDraw = false;
        } else {
	        if (clockTime.min % weatherUpdatePeriod == 0) {
	            viewUpdateWeather();
	            reDrawWeather(dc);
	        }
        	drawTime(dc);
        }
        
        // Update battery status
        updateBattery(dc);
    }
    
    function updateBattery(dc as Dc) as Void {
    	var stats = System.getSystemStats() as Stats;
    	var chargingNow = stats.charging as Boolean;
    	var batteryPercentNow = stats.battery.toNumber() as Integer;
    	if (batteryPercentNow != batteryPercent || charging != chargingNow) {
	    	batteryLabel.setText(System.getSystemStats().battery.format("%0d")+"%");
	        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
	        dc.fillRectangle(17, 50, 45, 19);
        	dc.fillRectangle(45, 34, 20, 7);
        	
	        var batteryFill = (batteryPercentNow + 4) / 5;
	        if (chargingNow) {
	        	dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        		dc.fillPolygon([[21,52],[18,61],[20,59],[19,67],[24,59],[21,61],[25,52]]);
	        	batteryLabel.setColor(Graphics.COLOR_BLUE);
	        	batteryLabel.draw(dc);
	        	// Drawing label implicitly sets foreground color to label color on dc
	        } else {
	        	batteryLabel.setColor(Graphics.COLOR_LT_GRAY);
	        	batteryLabel.draw(dc);
		        if (batteryPercentNow > 25) {
		        	dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
		        } else if (batteryPercentNow > 10) {
		        	dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
		        } else {
		        	dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
		        }
	        }
	        
        	dc.fillRectangle(45, 34, batteryFill, 7);
        	
    		batteryPercent = batteryPercentNow;
        	charging = chargingNow;
        }
    }
    
    function drawTime(dc as Dc) as Void {
    	dc.setClip(15, 80, 177, 65);
    	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    	dc.clear();
    	timeLabel.draw(dc);
    	dc.clearClip();
    }
    
    function drawWeatherIcon(dc as Dc) as Void {
    	dc.setColor(weatherColor, Graphics.COLOR_TRANSPARENT);
    	dc.drawText(113, 6, weatherFont, weatherChar, Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    function drawWeatherValues(dc as Dc) as Void {
        tempLabel.draw(dc);
        precipLabel.draw(dc);
    }
    
    function reDrawWeather(dc as Dc) as Void {
    	// Clear weather widget area
    	dc.setClip(80, 0, 160, 73);
    	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
    	dc.clear();
    	drawWeatherIcon(dc);
    	drawWeatherValues(dc);
    	dc.clearClip();
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
    
    function mapWeatherCondToIcon(weather as CurrentConditions) as Void {
    	var clockTime as ClockTime;
    	switch (weather.condition) {
    		case Weather.CONDITION_UNKNOWN:
    		default:
    			weatherChar = "A";
    			weatherColor = Graphics.COLOR_LT_GRAY;
    			return;
    		case Weather.CONDITION_HAIL:
    			weatherChar = "B";
    			weatherColor = Graphics.COLOR_BLUE;
    			return;
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
    			weatherChar = "C";
    			weatherColor = Graphics.COLOR_BLUE;
    			return;
			case Weather.CONDITION_FOG:
    		case Weather.CONDITION_HAZE:
    		case Weather.CONDITION_HAZY:
    		case Weather.CONDITION_MIST:
    		case Weather.CONDITION_SAND:
    		case Weather.CONDITION_SMOKE:
    		case Weather.CONDITION_VOLCANIC_ASH:
    			weatherChar = "D";
    			weatherColor = Graphics.COLOR_LT_GRAY;
				return;
			case Weather.CONDITION_CHANCE_OF_THUNDERSTORMS:
    		case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
    		case Weather.CONDITION_THUNDERSTORMS:
    			weatherChar = "E";
    			weatherColor = Graphics.COLOR_BLUE;
    			return;
    		case Weather.CONDITION_CLOUDY:
    		case Weather.CONDITION_MOSTLY_CLOUDY:
    		case Weather.CONDITION_THIN_CLOUDS:
    		case Weather.CONDITION_UNKNOWN_PRECIPITATION:
    			weatherChar = "F";
    			weatherColor = Graphics.COLOR_LT_GRAY;
    			return;
    		case Weather.CONDITION_FAIR:
    		case Weather.CONDITION_MOSTLY_CLEAR:
    		case Weather.CONDITION_PARTLY_CLEAR:
    		case Weather.CONDITION_PARTLY_CLOUDY:
    			clockTime = System.getClockTime() as ClockTime;
    			if (clockTime.hour >= 7 && clockTime.hour <= 20) {
    				// Daytime
    				weatherChar = "G";
    			} else {
    				// Nighttime
    				weatherChar = "H";
    			}
    			weatherColor = Graphics.COLOR_LT_GRAY;
    			return;
			case Weather.CONDITION_CHANCE_OF_RAIN_SNOW:
    		case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW:
    		case Weather.CONDITION_FREEZING_RAIN:
    		case Weather.CONDITION_HEAVY_RAIN_SNOW:
    		case Weather.CONDITION_LIGHT_RAIN_SNOW:
    		case Weather.CONDITION_SLEET:
    		case Weather.CONDITION_WINTRY_MIX:
    			weatherChar = "I";
    			weatherColor = Graphics.COLOR_BLUE;
    			return;
			case Weather.CONDITION_ICE:
    			weatherColor = Graphics.COLOR_BLUE;
				weatherChar = "J";
				return;
    		case Weather.CONDITION_CLEAR:
    			clockTime = System.getClockTime() as ClockTime;
    			if (clockTime.hour >= 7 && clockTime.hour <= 20) {
    				// Daytime
    				weatherChar = "K";
    			} else {
    				// Nighttime
    				weatherChar = "O";
    			}
    			weatherColor = Graphics.COLOR_YELLOW;
    			return;
			case Weather.CONDITION_HURRICANE:
    		case Weather.CONDITION_TORNADO:
    		case Weather.CONDITION_TROPICAL_STORM:
    			weatherChar = "L";
    			weatherColor = Graphics.COLOR_LT_GRAY;
    			return;
			case Weather.CONDITION_DUST:
    		case Weather.CONDITION_SANDSTORM:
    		case Weather.CONDITION_SQUALL:
    		case Weather.CONDITION_WINDY:
    			weatherChar = "M";
    			weatherColor = Graphics.COLOR_LT_GRAY;
    			return;
			case Weather.CONDITION_CHANCE_OF_SNOW:
    		case Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW:
    		case Weather.CONDITION_FLURRIES:
    		case Weather.CONDITION_HEAVY_SNOW:
    		case Weather.CONDITION_ICE_SNOW:
    		case Weather.CONDITION_LIGHT_SNOW:
    		case Weather.CONDITION_RAIN_SNOW:
    		case Weather.CONDITION_SNOW:
    			weatherChar = "N";
    			weatherColor = Graphics.COLOR_BLUE;
    			return;
    	}
    }

}
