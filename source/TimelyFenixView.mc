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
	var whiteBlock;
	var initialDraw as Boolean;
	
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
        whiteBlock = WatchUi.loadResource(Rez.Drawables.WhiteBlock);
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
    	var precipView = View.findDrawableById("PrecipLabel") as Text;
    	if (weather == null) {
    	    tempView.setText("--" + degreesSymbol + "F");
    	    precipView.setText("--%");
    	    return;
    	}
    	
    	if (weather.temperature == null) {
    		System.println("no temperature data");
    		tempView.setText("--" + degreesSymbol + "F");
    	} else {
    		// Weather data always comes as Celsius
    		var temperature = celsiusToFahrenheit(weather);
        	tempView.setText(temperature + degreesSymbol + "F");
    	}
    	
    	if (weather.precipitationChance == null) {
    		System.println("no precipitation data");
    	    precipView.setText("--%");
    	} else {
        	precipView.setText(weather.precipitationChance + "%");
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
	        //if (clockTime.min % weatherUpdatePeriod == 0) {
	            viewUpdateWeather();
	            reDrawWeather(dc);
	        //}
        	drawTime(dc);
        }
    }
    
    function drawTime(dc as Dc) as Void {
    	dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
    	dc.fillRectangle(110, 80, 82, 65);
    	View.findDrawableById("TimeLabel").draw(dc);
    }
    
    function drawWeatherIcon(dc as Dc) as Void {
    	// Weather icon placeholder
        dc.drawBitmap(85, 5, whiteBlock);
    }
    
    function drawWeatherValues(dc as Dc) as Void {
        View.findDrawableById("TempLabel").draw(dc);
        View.findDrawableById("PrecipLabel").draw(dc);
    }
    
    function reDrawWeather(dc as Dc) as Void {
    	// Clear weather widget area
    	dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
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
