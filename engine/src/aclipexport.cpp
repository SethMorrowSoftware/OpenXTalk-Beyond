/* Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond, a fork of LiveCode Community.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

#include "aclipexport.h"

#include <stdlib.h>
#include <string.h>

int16_t MCAudioMulawToLinear(uint8_t p_byte)
{
	// G.711: the engine's ulaw_table (aclip.cpp) is this, entry by entry
	uint8_t t_byte = ~p_byte;
	int t_magnitude = (((t_byte & 0x0F) << 3) + 0x84) << ((t_byte & 0x70) >> 4);
	return (int16_t)((t_byte & 0x80) ? (0x84 - t_magnitude) : (t_magnitude - 0x84));
}

static bool ends_with_caseless(const char *p_name, size_t p_length, const char *p_suffix)
{
	size_t t_suffix = strlen(p_suffix);
	if (p_length < t_suffix)
		return false;
	const char *t_at = p_name + p_length - t_suffix;
	for (size_t i = 0; i < t_suffix; i++)
	{
		char t_char = t_at[i];
		if (t_char >= 'A' && t_char <= 'Z')
			t_char += 'a' - 'A';
		if (t_char != p_suffix[i])
			return false;
	}
	return true;
}

MCAudioFileContainer MCAudioFileContainerForName(const char *p_name)
{
	if (p_name == NULL)
		return kMCAudioFileWave;
	size_t t_length = strlen(p_name);
	if (ends_with_caseless(p_name, t_length, ".aif") ||
		ends_with_caseless(p_name, t_length, ".aiff") ||
		ends_with_caseless(p_name, t_length, ".aifc"))
		return kMCAudioFileAiff;
	if (ends_with_caseless(p_name, t_length, ".au") ||
		ends_with_caseless(p_name, t_length, ".snd"))
		return kMCAudioFileAu;
	return kMCAudioFileWave;
}

// One stored sample, of p_width bytes at p_at, as a signed value of
// p_width * 8 bits
static int32_t read_sample(const uint8_t *p_at, int p_format, uint32_t p_width)
{
	if (p_format == kMCAudioSampleUnsignedLinear)
	{
		// A WAV file's: 8-bit unsigned, wider signed little-endian
		if (p_width == 1)
			return (int32_t)p_at[0] - 128;
		if (p_width == 2)
			return (int16_t)(p_at[0] | (p_at[1] << 8));
		int32_t t_value = p_at[0] | (p_at[1] << 8) | (p_at[2] << 16);
		return (t_value ^ 0x800000) - 0x800000;
	}
	// signed linear: 8-bit, wider big-endian
	if (p_width == 1)
		return (int8_t)p_at[0];
	if (p_width == 2)
		return (int16_t)((p_at[0] << 8) | p_at[1]);
	int32_t t_value = (p_at[0] << 16) | (p_at[1] << 8) | p_at[2];
	return (t_value ^ 0x800000) - 0x800000;
}

static void put_be32(uint8_t *p_at, uint32_t p_value)
{
	p_at[0] = (uint8_t)(p_value >> 24);
	p_at[1] = (uint8_t)(p_value >> 16);
	p_at[2] = (uint8_t)(p_value >> 8);
	p_at[3] = (uint8_t)p_value;
}

static void put_be16(uint8_t *p_at, uint32_t p_value)
{
	p_at[0] = (uint8_t)(p_value >> 8);
	p_at[1] = (uint8_t)p_value;
}

static void put_le32(uint8_t *p_at, uint32_t p_value)
{
	p_at[0] = (uint8_t)p_value;
	p_at[1] = (uint8_t)(p_value >> 8);
	p_at[2] = (uint8_t)(p_value >> 16);
	p_at[3] = (uint8_t)(p_value >> 24);
}

static void put_le16(uint8_t *p_at, uint32_t p_value)
{
	p_at[0] = (uint8_t)p_value;
	p_at[1] = (uint8_t)(p_value >> 8);
}

// A whole number of samples a second as the 80-bit IEEE extended number
// AIFF's COMM chunk keeps its rate in
static void put_extended(uint8_t *p_at, uint32_t p_value)
{
	memset(p_at, 0, 10);
	if (p_value == 0)
		return;
	int t_top = 31;
	while ((p_value & (1u << t_top)) == 0)
		t_top--;
	uint32_t t_exponent = 16383 + t_top;
	// the mantissa's top 32 bits, the value with its top bit at bit 31
	uint32_t t_mantissa = p_value << (31 - t_top);
	put_be16(p_at, t_exponent);
	put_be32(p_at + 2, t_mantissa);
}

bool MCAudioEncodeFile(MCAudioFileContainer p_container,
                       const uint8_t *p_samples, uint32_t p_size,
                       int p_format, uint32_t p_channels, uint32_t p_width,
                       uint32_t p_rate,
                       uint8_t *&r_file, size_t &r_file_size)
{
	if (p_channels == 0 || p_channels > 0xFFFF || p_rate == 0)
		return false;
	if (p_format != kMCAudioSampleSignedLinear &&
		p_format != kMCAudioSampleMulaw &&
		p_format != kMCAudioSampleUnsignedLinear)
		return false;
	// A mu-law sample is one byte, whatever width the clip says
	uint32_t t_in_width = p_format == kMCAudioSampleMulaw ? 1 : p_width;
	if (t_in_width < 1 || t_in_width > 3)
		return false;
	if (p_samples == NULL)
		p_size = 0;

	uint32_t t_frames = p_size / (t_in_width * p_channels);
	uint32_t t_count = t_frames * p_channels;

	// Mu-law stays mu-law only in AU; elsewhere it becomes 16-bit
	bool t_keep_mulaw = p_format == kMCAudioSampleMulaw && p_container == kMCAudioFileAu;
	uint32_t t_out_width = p_format == kMCAudioSampleMulaw ? (t_keep_mulaw ? 1 : 2) : t_in_width;

	uint64_t t_data_size = (uint64_t)t_count * t_out_width;
	size_t t_header_size;
	size_t t_pad = 0;
	switch (p_container)
	{
	case kMCAudioFileWave:
		t_header_size = 44;
		t_pad = t_data_size & 1;
		break;
	case kMCAudioFileAiff:
		t_header_size = 54;
		t_pad = t_data_size & 1;
		break;
	case kMCAudioFileAu:
		t_header_size = 24;
		break;
	default:
		return false;
	}
	if (t_data_size + t_header_size + t_pad > 0xFFFFFFF0u)
		return false;

	size_t t_file_size = t_header_size + (size_t)t_data_size + t_pad;
	uint8_t *t_file = (uint8_t *)malloc(t_file_size);
	if (t_file == NULL)
		return false;
	memset(t_file, 0, t_file_size);

	uint32_t t_bits = t_out_width * 8;
	uint32_t t_block = t_out_width * p_channels;
	uint8_t *t_header = t_file;
	switch (p_container)
	{
	case kMCAudioFileWave:
		memcpy(t_header, "RIFF", 4);
		put_le32(t_header + 4, (uint32_t)(t_file_size - 8));
		memcpy(t_header + 8, "WAVEfmt ", 8);
		put_le32(t_header + 16, 16);
		put_le16(t_header + 20, 1); // PCM
		put_le16(t_header + 22, p_channels);
		put_le32(t_header + 24, p_rate);
		put_le32(t_header + 28, p_rate * t_block);
		put_le16(t_header + 32, t_block);
		put_le16(t_header + 34, t_bits);
		memcpy(t_header + 36, "data", 4);
		put_le32(t_header + 40, (uint32_t)t_data_size);
		break;
	case kMCAudioFileAiff:
		memcpy(t_header, "FORM", 4);
		put_be32(t_header + 4, (uint32_t)(t_file_size - 8));
		memcpy(t_header + 8, "AIFFCOMM", 8);
		put_be32(t_header + 16, 18);
		put_be16(t_header + 20, p_channels);
		put_be32(t_header + 22, t_frames);
		put_be16(t_header + 26, t_bits);
		put_extended(t_header + 28, p_rate);
		memcpy(t_header + 38, "SSND", 4);
		put_be32(t_header + 42, (uint32_t)(t_data_size + 8));
		put_be32(t_header + 46, 0); // offset
		put_be32(t_header + 50, 0); // block size
		break;
	case kMCAudioFileAu:
		memcpy(t_header, ".snd", 4);
		put_be32(t_header + 4, 24);
		put_be32(t_header + 8, (uint32_t)t_data_size);
		// 1 mu-law, 2 3 4 linear 8, 16 and 24-bit
		put_be32(t_header + 12, t_keep_mulaw ? 1 : t_out_width + 1);
		put_be32(t_header + 16, p_rate);
		put_be32(t_header + 20, p_channels);
		break;
	}

	uint8_t *t_out = t_file + t_header_size;
	for (uint32_t i = 0; i < t_count; i++)
	{
		const uint8_t *t_in = p_samples + (size_t)i * t_in_width;
		if (t_keep_mulaw)
		{
			*t_out++ = t_in[0];
			continue;
		}
		int32_t t_value;
		if (p_format == kMCAudioSampleMulaw)
			t_value = MCAudioMulawToLinear(t_in[0]);
		else
			t_value = read_sample(t_in, p_format, t_in_width);

		if (p_container == kMCAudioFileWave)
		{
			// WAV: 8-bit unsigned, wider signed little-endian
			if (t_out_width == 1)
				*t_out++ = (uint8_t)(t_value + 128);
			else
				for (uint32_t b = 0; b < t_out_width; b++)
					*t_out++ = (uint8_t)(t_value >> (8 * b));
		}
		else
		{
			// AIFF and AU: signed big-endian
			for (uint32_t b = t_out_width; b > 0; b--)
				*t_out++ = (uint8_t)(t_value >> (8 * (b - 1)));
		}
	}

	r_file = t_file;
	r_file_size = t_file_size;
	return true;
}
