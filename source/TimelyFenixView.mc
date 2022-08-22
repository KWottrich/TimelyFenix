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
	var calendarDays;
	var dayOfWeek as Integer;
	var initialDraw as Boolean;
	var weatherFont as FontResource;
	var weatherChar as String;
	var weatherColor as Integer;
	
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
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    	is24h = System.getDeviceSettings().is24Hour;
    	foregroundColor = getApp().getProperty("ForegroundColor");
    	weatherUpdatePeriod = getApp().getProperty("WeatherUpdatePeriod");
    	updateCalendarValues();
    	initialDraw = true;
    }
    
    function viewUpdateTime(clockTime as ClockTime) as Void {
        var hours = clockTime.hour;
        var timeString as String;
        if (!is24h) {
	        var amPmView = View.findDrawableById("AmPmLabel") as Text;
            if (hours > 12) {
                hours -= 12;
                amPmView.setText("PM");
            } else {
            	if (hours == 0) {
            		hours = 12;
            	}
            	amPmView.setText("AM");
            }
        }
        
        timeString = hours + ":" + clockTime.min.format("%02d");

        // Update the view
        var view = View.findDrawableById("TimeLabel") as Text;
        view.setText(timeString);
    }
    
    function updateAmPm(clockTime as ClockTime) as Void {
    	View.findDrawableById("AmPmLabel").setText(
    		clockTime.hour > 12 ? "PM" : "AM");
    }
    
    function celsiusToFahrenheit(weather as CurrentConditions) as Number {
        return weather.temperature * 9 / 5 + 32;
    }
    
    function viewUpdateWeather() as Void {
    	var weather = Weather.getCurrentConditions();
    	
    	var tempView = View.findDrawableById("TempLabel") as Text;
    	if (weather == null || weather.temperature == null) {
    		tempView.setText("--" + degreesSymbol + "F");
    	} else {
    		// Weather data always comes as Celsius
    		var temperature = celsiusToFahrenheit(weather);
        	tempView.setText(temperature + degreesSymbol + "F");
    	}
    	
    	var precipView = View.findDrawableById("PrecipLabel") as Text;
    	if (weather == null || weather.precipitationChance == null) {
    	    precipView.setText("--%");
    	} else {
        	precipView.setText(weather.precipitationChance + "%");
    	}
    	
    	if (weather == null || weather.condition == null) {
    		// Missing Weather icon
    	    weatherChar = "A";
    	    weatherColor = Graphics.COLOR_LT_GRAY;
    	} else {
    		mapWeatherCondToIcon(weather);
    	}
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
    
    function drawCalendar(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        var calRows = 3;
        var calCols = 7;
        var xWidth = 24;
        var xOffset = 35;
        var yHeight = 14;
        var yOffset = 163;
        
        // Horizontal grid lines
        for (var i = 0; i <= calRows; i++) {
        	dc.drawLine(xOffset, yHeight*i + yOffset, xWidth*calCols + xOffset, yHeight*i + yOffset);
        }
        // Vertical grid lines
        for (var i = 0; i <= calCols; i++) {
        	dc.drawLine(xWidth*i + xOffset, yOffset, i*xWidth + xOffset, yHeight*calRows + yOffset);
        }
        
        // Battery/Weather separators
        dc.drawLine(78, 0, 78, 75);
        dc.drawLine(0, 75, 240, 75);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle((dayOfWeek-1) * xWidth + xOffset + 1, yOffset + yHeight, xWidth, yHeight);
        
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
    	var daysOfWeek = ["Sunday","Monday","Tuesday","Wednesday",
    		"Thursday","Friday","Saturday"];
    	for (var i = 0; i < 7; i++) {
    		if (i+1 == timeInfo.day_of_week) {
    			View.findDrawableById(daysOfWeek[i]).setColor(Graphics.COLOR_WHITE);
    		} else {
    			View.findDrawableById(daysOfWeek[i]).setColor(Graphics.COLOR_DK_GRAY);
    		}
    	}
    	
    	// Arrange days on calendar view
    	var firstDateShown = timeInfo.day - timeInfo.day_of_week - 6 as Integer;
    	var currentMonthDays = daysPerMonth(timeInfo.month, timeInfo.year) as Integer;
    	var prevMonthDays = daysPerMonth(timeInfo.month-1, timeInfo.year) as Integer;
    	for (var i = 0; i < 21; i++) {
    		var dayNum = firstDateShown+i;
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
    		"August","September","October","November","December"];
    	View.findDrawableById("DateString").setText(months[timeInfo.month-1] +
    		" " + timeInfo.day + ", " + timeInfo.year);
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Get the current time
        var clockTime = System.getClockTime();
        // Update primary time values
        viewUpdateTime(clockTime);
        // Update battery status
        View.findDrawableById("BatteryLabel").setText(
        	System.getSystemStats().battery.format("%0d")+"%");
        
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
	    	
	    	initialDraw = false;
        } else {
	        if (clockTime.min % weatherUpdatePeriod == 0) {
	            viewUpdateWeather();
	            reDrawWeather(dc);
	        }
        	drawTime(dc);
        }
    }
    
    function drawTime(dc as Dc) as Void {
    	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    	dc.fillRectangle(15, 80, 177, 65);
    	View.findDrawableById("TimeLabel").draw(dc);
    }
    
    function drawWeatherIcon(dc as Dc) as Void {
    	dc.setColor(weatherColor, Graphics.COLOR_TRANSPARENT);
    	dc.drawText(113, 6, weatherFont, weatherChar, Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    function drawWeatherValues(dc as Dc) as Void {
        View.findDrawableById("TempLabel").draw(dc);
        View.findDrawableById("PrecipLabel").draw(dc);
    }
    
    function reDrawWeather(dc as Dc) as Void {
    	// Clear weather widget area
    	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    	dc.fillRectangle(80, 0, 160, 73);
    	drawWeatherIcon(dc);
    	drawWeatherValues(dc);
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

}
