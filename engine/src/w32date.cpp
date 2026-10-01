/* Copyright (C) 2003-2015 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

#include "prefix.h"
#include "w32dsk-legacy.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"

#include "param.h"
#include "mcerror.h"

#include "util.h"
#include "date.h"
#include "osspec.h"

#include "globals.h"

#include "foundation-locale.h"

#if !defined(LOCALE_SSHORTTIME)
#define LOCALE_SSHORTTIME             0x00000079   // Returns the preferred short time format (ie: no seconds, just h:mm)
#endif

////////////////////////////////////////////////////////////////////////////////

static void tm_to_datetime(bool p_local, const struct tm& p_tm, MCDateTime& r_datetime)
{
	r_datetime . year = 1900 + p_tm . tm_year;
	r_datetime . month = p_tm . tm_mon + 1;
	r_datetime . day = p_tm . tm_mday;
	r_datetime . hour = p_tm . tm_hour;
	r_datetime . minute = p_tm . tm_min;
	r_datetime . second = p_tm . tm_sec;
	if (p_local)
	{
		r_datetime . bias = -_timezone / 60;
		if (p_tm . tm_isdst)
			r_datetime . bias -= _dstbias / 60;
	}
	else
		r_datetime . bias = 0;
}

static void datetime_to_tm(bool p_local, const MCDateTime& p_datetime, struct tm& r_tm)
{
	r_tm . tm_year = p_datetime . year - 1900;
	r_tm . tm_mon = p_datetime . month - 1;
	r_tm . tm_mday = p_datetime . day;
	r_tm . tm_hour = p_datetime . hour;
	r_tm . tm_min = p_datetime . minute;
	r_tm . tm_sec = p_datetime . second;
	if (p_local)
		r_tm . tm_isdst = -1;
	else
		r_tm . tm_isdst = 0;
}

void MCS_getlocaldatetime(MCDateTime& r_datetime)
{
	__time64_t t_time;
	_time64(&t_time);

	struct tm t_tm;
	_localtime64_s(&t_tm, &t_time);

	tm_to_datetime(true, t_tm, r_datetime);
}

////////////////////////////////////////////////////////////////////////////////

// The C runtime's _mkgmtime64, _mktime64, _gmtime64_s and _localtime64_s only
// handle the years 1970 to 3000, so every date before 1970 failed to convert
// on Windows (convert "1/1/1960" to dateItems left it as it was) while the
// same script worked on Linux and macOS. The runtime is still used for the
// years it handles, so their results do not change; the other years are
// converted below: universal time with the proleptic Gregorian calendar, as
// timegm and gmtime do on other platforms, and local time with the rules of
// the time zone that Windows applies to the year (SystemTimeToTzSpecific-
// LocalTime), or before 1601, which SYSTEMTIME cannot hold, the zone's
// standard time.

static int64_t floor_div(int64_t p_numerator, int64_t p_denominator)
{
	int64_t t_quotient = p_numerator / p_denominator;
	if ((p_numerator % p_denominator != 0) && ((p_numerator < 0) != (p_denominator < 0)))
		t_quotient -= 1;
	return t_quotient;
}

// The days from 1970-01-01 to the given date (Howard Hinnant's
// days_from_civil); month is 1 to 12, day may be out of range.
static int64_t days_from_civil(int64_t p_year, int64_t p_month, int64_t p_day)
{
	p_year -= p_month <= 2 ? 1 : 0;
	int64_t t_era = floor_div(p_year, 400);
	int64_t t_year_of_era = p_year - t_era * 400;
	int64_t t_day_of_year = (153 * (p_month + (p_month > 2 ? -3 : 9)) + 2) / 5 + p_day - 1;
	int64_t t_day_of_era = t_year_of_era * 365 + t_year_of_era / 4 - t_year_of_era / 100 + t_day_of_year;
	return t_era * 146097 + t_day_of_era - 719468;
}

// The date that is the given number of days from 1970-01-01 (Howard
// Hinnant's civil_from_days).
static void civil_from_days(int64_t p_days, int64_t& r_year, int64_t& r_month, int64_t& r_day)
{
	p_days += 719468;
	int64_t t_era = floor_div(p_days, 146097);
	int64_t t_day_of_era = p_days - t_era * 146097;
	int64_t t_year_of_era = (t_day_of_era - t_day_of_era / 1460 + t_day_of_era / 36524 - t_day_of_era / 146096) / 365;
	int64_t t_day_of_year = t_day_of_era - (365 * t_year_of_era + t_year_of_era / 4 - t_year_of_era / 100);
	int64_t t_month_index = (5 * t_day_of_year + 2) / 153;
	r_day = t_day_of_year - (153 * t_month_index + 2) / 5 + 1;
	r_month = t_month_index + (t_month_index < 10 ? 3 : -9);
	r_year = t_year_of_era + t_era * 400 + (r_month <= 2 ? 1 : 0);
}

// The seconds from 1970-01-01 00:00:00 to the date and time, with fields out
// of range carried over as timegm does (month 13 is January of the next year).
static int64_t datetime_to_epoch_seconds(const MCDateTime& p_datetime)
{
	int64_t t_months = (int64_t)p_datetime . year * 12 + (p_datetime . month - 1);
	int64_t t_year = floor_div(t_months, 12);
	int64_t t_month = t_months - t_year * 12 + 1;
	int64_t t_days = days_from_civil(t_year, t_month, 1) + (p_datetime . day - 1);
	return t_days * 86400 + (int64_t)p_datetime . hour * 3600 + (int64_t)p_datetime . minute * 60 + p_datetime . second;
}

static void epoch_seconds_to_datetime(int64_t p_seconds, MCDateTime& r_datetime)
{
	int64_t t_days = floor_div(p_seconds, 86400);
	int64_t t_second_of_day = p_seconds - t_days * 86400;
	int64_t t_year, t_month, t_day;
	civil_from_days(t_days, t_year, t_month, t_day);
	r_datetime . year = (int4)t_year;
	r_datetime . month = (int4)t_month;
	r_datetime . day = (int4)t_day;
	r_datetime . hour = (int4)(t_second_of_day / 3600);
	r_datetime . minute = (int4)((t_second_of_day / 60) % 60);
	r_datetime . second = (int4)(t_second_of_day % 60);
	r_datetime . bias = 0;
}

// A SYSTEMTIME holds the years 1601 to 30827.
static bool epoch_seconds_to_systemtime(int64_t p_seconds, SYSTEMTIME& r_time)
{
	MCDateTime t_datetime;
	epoch_seconds_to_datetime(p_seconds, t_datetime);
	if (t_datetime . year < 1601 || t_datetime . year > 30827)
		return false;
	r_time . wYear = (WORD)t_datetime . year;
	r_time . wMonth = (WORD)t_datetime . month;
	r_time . wDayOfWeek = 0;
	r_time . wDay = (WORD)t_datetime . day;
	r_time . wHour = (WORD)t_datetime . hour;
	r_time . wMinute = (WORD)t_datetime . minute;
	r_time . wSecond = (WORD)t_datetime . second;
	r_time . wMilliseconds = 0;
	return true;
}

static int64_t systemtime_to_epoch_seconds(const SYSTEMTIME& p_time)
{
	MCDateTime t_datetime;
	t_datetime . year = p_time . wYear;
	t_datetime . month = p_time . wMonth;
	t_datetime . day = p_time . wDay;
	t_datetime . hour = p_time . wHour;
	t_datetime . minute = p_time . wMinute;
	t_datetime . second = p_time . wSecond;
	t_datetime . bias = 0;
	return datetime_to_epoch_seconds(t_datetime);
}

// The offset of the time zone's standard time from universal time, in
// seconds (east is positive, as in MCDateTime's bias).
static int64_t standard_time_offset(void)
{
	TIME_ZONE_INFORMATION t_zone;
	if (GetTimeZoneInformation(&t_zone) == TIME_ZONE_ID_INVALID)
		return 0;
	return -(int64_t)(t_zone . Bias + t_zone . StandardBias) * 60;
}

static void universal_to_local_any_year(MCDateTime& x_datetime)
{
	int64_t t_universal, t_local;
	t_universal = datetime_to_epoch_seconds(x_datetime);

	SYSTEMTIME t_universal_time, t_local_time;
	if (epoch_seconds_to_systemtime(t_universal, t_universal_time) &&
		SystemTimeToTzSpecificLocalTime(NULL, &t_universal_time, &t_local_time))
		t_local = systemtime_to_epoch_seconds(t_local_time);
	else
		t_local = t_universal + standard_time_offset();

	epoch_seconds_to_datetime(t_local, x_datetime);
	x_datetime . bias = (int4)((t_local - t_universal) / 60);
}

static void local_to_universal_any_year(MCDateTime& x_datetime)
{
	int64_t t_local, t_universal;
	t_local = datetime_to_epoch_seconds(x_datetime);

	SYSTEMTIME t_local_time, t_universal_time;
	if (epoch_seconds_to_systemtime(t_local, t_local_time) &&
		TzSpecificLocalTimeToSystemTime(NULL, &t_local_time, &t_universal_time))
		t_universal = systemtime_to_epoch_seconds(t_universal_time);
	else
		t_universal = t_local - standard_time_offset();

	epoch_seconds_to_datetime(t_universal, x_datetime);
}

bool MCS_datetimetolocal(MCDateTime& x_datetime)
{
	struct tm t_universal_datetime;
	datetime_to_tm(false, x_datetime, t_universal_datetime);

	__time64_t t_time;
	t_time = _mkgmtime64(&t_universal_datetime);

	struct tm t_local_tm;
	if (t_time == -1 || _localtime64_s(&t_local_tm, &t_time) != 0)
	{
		universal_to_local_any_year(x_datetime);
		return true;
	}

	tm_to_datetime(true, t_local_tm, x_datetime);

	return true;
}

bool MCS_datetimetouniversal(MCDateTime& x_datetime)
{
	struct tm t_local_datetime;
	datetime_to_tm(true, x_datetime, t_local_datetime);

	__time64_t t_universal_time;
	t_universal_time = _mktime64(&t_local_datetime);

	struct tm t_universal_tm;
	if (t_universal_time == -1 || _gmtime64_s(&t_universal_tm, &t_universal_time) != 0)
	{
		local_to_universal_any_year(x_datetime);
		return true;
	}

	tm_to_datetime(false, t_universal_tm, x_datetime);

	return true;
}

bool MCS_datetimetoseconds(const MCDateTime& p_datetime, double& r_seconds)
{
	struct tm t_universal_tm;
	datetime_to_tm(false, p_datetime, t_universal_tm);

	__time64_t t_universal_time;
	t_universal_time = _mkgmtime64(&t_universal_tm);
	if (t_universal_time == -1)
		t_universal_time = datetime_to_epoch_seconds(p_datetime);

	r_seconds = (double)t_universal_time;

	return true;
}

bool MCS_secondstodatetime(double p_seconds, MCDateTime& r_datetime)
{
	// About 31 million years either way: further than any calendar date, and
	// within what the conversions below can hold.
	if (!(fabs(p_seconds) < 1e15))
		return false;

	__time64_t t_universal_time;
	t_universal_time = (__time64_t)floor(p_seconds + 0.5);

	struct tm t_universal_tm;
	if (_gmtime64_s(&t_universal_tm, &t_universal_time) != 0)
	{
		epoch_seconds_to_datetime(t_universal_time, r_datetime);
		return true;
	}

	tm_to_datetime(false, t_universal_tm, r_datetime);

	return true;
}

////////////////////////////////////////////////////////////////////////////////

static MCDateTimeLocale *s_datetime_locale = NULL;

static MCStringRef string_prepend(MCStringRef p_string, unichar_t p_prefix)
{
	MCStringRef t_new;
	MCStringFormat(t_new, "%lc%@", p_prefix, p_string);
	return t_new;
}

static MCStringRef windows_query_locale(uint4 t_index)
{
	// Allocate a buffer for the locale information
	int t_buf_size;
	t_buf_size = GetLocaleInfoW(LOCALE_USER_DEFAULT, t_index, NULL, 0);
	wchar_t* t_buffer = new (nothrow) wchar_t[t_buf_size];
	
	// Get the locale information and create a StringRef from it
	if (GetLocaleInfoW(LOCALE_USER_DEFAULT, t_index, t_buffer, t_buf_size) == 0)
		return MCValueRetain(kMCEmptyString);
	MCStringRef t_string;
	MCStringCreateWithChars(t_buffer, MCU_max(0, t_buf_size - 1), t_string);
	delete[] t_buffer;
	
	return t_string;
}

static MCStringRef windows_convert_date_format(MCStringRef p_format)
{
	MCStringRef t_output;
	MCStringCreateMutable(0, t_output);
	uindex_t t_offset = 0;
	
	while (t_offset < MCStringGetLength(p_format))
	{
		unichar_t t_char;
		t_char = MCStringGetCharAtIndex(p_format, t_offset++);
		
		if (t_char == '\'')
		{
			// Copy quoted strings to the output with no conversion
			while ((t_char = MCStringGetCharAtIndex(p_format, t_offset++)) != '\'')
				   MCStringAppendChar(t_output, t_char);
		}
		else
		{
			// Is this a day/month/year specifier?
			if (t_char == 'd' || t_char == 'M' || t_char == 'y')
			{
				// Count the number of consecutive identical characters
				unichar_t t_want = t_char;
				int t_count = 1;
				while (MCStringGetCharAtIndex(p_format, t_offset) == t_want)
                {
					t_count++;
                    t_offset++;
                }
				
				// Append the correct formatting instruction
				switch (t_char)
				{
				case 'd':
					if (t_count == 1)
						MCStringAppendFormat(t_output, "%%#d");
					else if (t_count == 2)
						MCStringAppendFormat(t_output, "%%d");
					else if (t_count == 3)
						MCStringAppendFormat(t_output, "%%a");
					else if (t_count == 4)
						MCStringAppendFormat(t_output, "%%A");
					break;
						
				case 'M':
					if (t_count == 1)
						MCStringAppendFormat(t_output, "%%#m");
					else if (t_count == 2)
						MCStringAppendFormat(t_output, "%%m");
					else if (t_count == 3)
						MCStringAppendFormat(t_output, "%%b");
					else if (t_count == 4)
						MCStringAppendFormat(t_output, "%%B");
					break;
						
				case 'y':
					if (t_count == 1)
						MCStringAppendFormat(t_output, "%%#y");
					else if (t_count == 2)
						MCStringAppendFormat(t_output, "%%y");
					else if (t_count == 4)
						MCStringAppendFormat(t_output, "%%Y");
					break;
				}
			}
			else
			{
				// Unknown character, copy it to the output
				MCStringAppendChar(t_output, t_char);
			}
		}
	}
	
	MCValueRelease(p_format);
	return t_output;
}

static MCStringRef windows_convert_time_format(MCStringRef p_format)
{
	MCStringRef t_output;
	MCStringCreateMutable(0, t_output);
	uindex_t t_offset = 0;
	
	while (t_offset < MCStringGetLength(p_format))
	{
		unichar_t t_char;
		t_char = MCStringGetCharAtIndex(p_format, t_offset++);
		
		if (t_char == '\'')
		{
			// Copy quoted strings to the output with no conversion
			while ((t_char = MCStringGetCharAtIndex(p_format, t_offset++)) != '\'')
				MCStringAppendChar(t_output, t_char);
		}
		else
		{
			// Is this a day/month/year specifier?
			if (t_char == 'h' || t_char == 'H' || t_char == 'm' || t_char == 's' || t_char == 't')
			{
				// Count the number of consecutive identical characters
				unichar_t t_want = t_char;
				int t_count = 1;
				while ((t_char = MCStringGetCharAtIndex(p_format, t_offset)) == t_want)
                {
                    t_count++;
                    t_offset++;
                }
				
				// Append the correct formatting instruction
				switch (t_want)
				{
					case 'h':
						if (t_count == 1)
							MCStringAppendFormat(t_output, "%%#I");
						else if (t_count == 2)
							MCStringAppendFormat(t_output, "%%I");
						break;
						
					case 'H':
						if (t_count == 1)
							MCStringAppendFormat(t_output, "%%#H");
						else if (t_count == 2)
							MCStringAppendFormat(t_output, "%%H");
						break;
						
					case 'm':
						if (t_count == 1)
							MCStringAppendFormat(t_output, "%%#M");
						else if (t_count == 2)
							MCStringAppendFormat(t_output, "%%M");
						break;
						
					case 's':
						if (t_count == 1)
							MCStringAppendFormat(t_output, "%%#S");
						else if (t_count == 2)
							MCStringAppendFormat(t_output, "%%S");
						break;
						
					case 't':
						MCStringAppendFormat(t_output, "%%p");
				}
			}
			else
			{
				// Unknown character, copy it to the output
				MCStringAppendChar(t_output, t_char);
			}
		}
	}
	
	MCValueRelease(p_format);
	return t_output;
}

static MCStringRef windows_abbreviate_format(MCStringRef p_format)
{
	MCStringRef t_new;
	/* UNCHECKED */ MCStringMutableCopyAndRelease(p_format, t_new);
	/* UNCHECKED */ MCStringFindAndReplaceChar(t_new, 'A', 'a', kMCStringOptionCompareExact);
	/* UNCHECKED */ MCStringFindAndReplaceChar(t_new, 'B', 'b', kMCStringOptionCompareExact);
	return t_new;
}

static MCStringRef windows_query_date_format(uint4 p_index, bool p_abbreviate)
{
	MCStringRef t_win_format = windows_query_locale(p_index);
	MCStringRef t_format = windows_convert_date_format(t_win_format);
	
	if (p_abbreviate)
		return windows_abbreviate_format(t_format);
	
	return t_format;
}

static MCStringRef windows_query_time_format(uint4 p_index)
{
	MCStringRef t_win_format = windows_query_locale(p_index);
	return windows_convert_time_format(t_win_format);
}

static void windows_cache_locale(void)
{
	if (s_datetime_locale != NULL)
		return;

	s_datetime_locale = new (nothrow) MCDateTimeLocale;

	// OK-2007-05-23: Fix for bug 5035. Adjusted to ensure that first element of weekday names is always Sunday.
	s_datetime_locale -> weekday_names[0] = windows_query_locale(LOCALE_SDAYNAME7);
	s_datetime_locale -> abbrev_weekday_names[0] = windows_query_locale(LOCALE_SABBREVDAYNAME7);

	for (uint4 t_index = 0; t_index < 6; ++t_index)
	{
		s_datetime_locale -> weekday_names[t_index + 1] = windows_query_locale(LOCALE_SDAYNAME1 + t_index);
		s_datetime_locale -> abbrev_weekday_names[t_index + 1] = windows_query_locale(LOCALE_SABBREVDAYNAME1 + t_index);
	}

	for(uint4 t_index = 0; t_index < 12; ++t_index)
	{
		s_datetime_locale -> month_names[t_index] = windows_query_locale(LOCALE_SMONTHNAME1 + t_index);
		s_datetime_locale -> abbrev_month_names[t_index] = windows_query_locale(LOCALE_SABBREVMONTHNAME1 + t_index);
	}

	s_datetime_locale -> date_formats[0] = string_prepend(windows_query_date_format(LOCALE_SSHORTDATE, false), '^');
	s_datetime_locale -> date_formats[1] = windows_query_date_format(LOCALE_SLONGDATE, true);
	s_datetime_locale -> date_formats[2] = windows_query_date_format(LOCALE_SLONGDATE, false);

	// AL-2013-02-08: [[ Bug 9942 ]] Allow appropriate versions of Windows to retrieve the short time format.
	if (MCmajorosversion >= MCOSVersionMake(6,1,0))
		s_datetime_locale -> time_formats[0] = string_prepend(windows_query_time_format(LOCALE_SSHORTTIME), '!');
	else
		s_datetime_locale -> time_formats[0] = string_prepend(windows_query_time_format(LOCALE_STIMEFORMAT), '!');

	s_datetime_locale -> time_formats[1] = string_prepend(windows_query_time_format(LOCALE_STIMEFORMAT), '!');

	s_datetime_locale -> time24_formats[0] = string_prepend(windows_query_time_format(LOCALE_STIMEFORMAT), '!');
	s_datetime_locale -> time24_formats[1] = string_prepend(windows_query_time_format(LOCALE_STIMEFORMAT), '!');
	
	// AL-2013-02-08: [[ Bug 9945 ]] Retrieve locale-specific AM & PM designators.
	s_datetime_locale -> time_morning_suffix = windows_query_locale(LOCALE_S1159);
	s_datetime_locale -> time_evening_suffix = windows_query_locale(LOCALE_S2359);
}

const MCDateTimeLocale *MCS_getdatetimelocale(void)
{
	windows_cache_locale();
	return s_datetime_locale;
}

MCLocaleRef MCS_getsystemlocale()
{
	// Get the identifier for the system locale
	LCID t_system_lcid;
	t_system_lcid = GetUserDefaultLCID();

	// Create a locale object
	MCLocaleRef t_locale;
	/* UNCHECKED */ MCLocaleCreateWithLCID(t_system_lcid, t_locale);
	return t_locale;
}

////////////////////////////////////////////////////////////////////////////////
