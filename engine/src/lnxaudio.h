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

/* Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
   (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
   Seth Morrow (2026); its Git history and CHANGELOG.md say what changed. */

/*
	X11Audio : Provides an abstraction between the aclip object and a Linux based audio system.
	This uses EsounD (which comes installed as part of GNOME). However, this interface will be
    simple enough to allow us to plug in any sound engine (OSS, ALSA).

	OXT-Beyond: current distributions ship no EsounD, so a clip plays through PulseAudio
	(or PipeWire's Pulse server) as a stream when libpulse-simple can be loaded and a server
	answers; the EsounD path is used, as before, only when there is no stream.
*/

#ifndef X11AUDIO_H
#define X11AUDIO_H



class X11Audio
{
public:
	X11Audio(void);
	~X11Audio(void);
	bool init(char * p_hostname, uint2 p_channels, uint2 p_width );
	int play(int1 * p_sample, uint4 p_samplesize, uint p_rate); 
	void close(void) ;
	int getloudness(void) { return 0; } ;
	void setloudness(int t_loudness) {} ;
	bool geterror(void) { return m_error ; } ; 
	int getfd (void) { return m_esd_connection; } ;

	// The PulseAudio stream. openstream answers false when there is no
	// libpulse-simple or no server, and then, until closestream, without
	// trying again. p_width is 1 (unsigned 8-bit) or 2 (signed 16-bit, in
	// the byte order p_little_endian says).
	bool openstream(uint4 p_rate, uint2 p_channels, uint2 p_width, bool p_little_endian);
	bool isstreaming(void) { return m_pulse != NULL; } ;
	// Writes p_size bytes (whole frames); false when the stream has failed
	bool writestream(const void *p_data, uint4 p_size);
	// The seconds of sound written and not yet heard, or -1 on failure
	double streamlatency(void);
	// Drops what has not been heard yet and closes the stream
	void closestream(void);
	
private:
	void *m_pulse ;
	bool m_pulse_failed ;
	bool m_playing ;
	uint4 m_flags ;
	int	 m_esd_connection ;
	char * m_host ;
	bool m_error ;
	bool isinit(void) { return ( m_esd_connection > -1 ) ; } ;
} ;




#endif 
