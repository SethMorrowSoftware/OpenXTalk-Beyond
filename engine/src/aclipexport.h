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

// An audioClip's samples written back out as a sound file, WAV, AIFF or
// AU (Sun/NeXT), with its header: `export audioClip "x" to file "x.wav"`.
// An audioClip keeps only the samples of the file it was imported from
// (or of the HyperCard sound it was made from), so until this the engine
// could play a clip but never give it back. Like hcnotes.h it depends on
// nothing in the engine, so that it can be tested alone.

#ifndef __ACLIPEXPORT_H
#define __ACLIPEXPORT_H

#include <stddef.h>
#include <stdint.h>

// How a clip keeps its samples, as aclip.h's AF_ values: signed linear
// (8-bit, or big-endian 16 and 24-bit, as AIFF, AU and HyperCard keep
// them), mu-law (one byte a sample), or "unsigned" linear, which is how a
// WAV file's samples are kept as imported: 8-bit unsigned, and 16 and
// 24-bit signed little-endian.
enum MCAudioSampleFormat
{
	kMCAudioSampleSignedLinear = 0,
	kMCAudioSampleMulaw = 1,
	kMCAudioSampleUnsignedLinear = 2,
};

enum MCAudioFileContainer
{
	kMCAudioFileWave,
	kMCAudioFileAiff,
	kMCAudioFileAu,
};

// The container a file name asks for by its extension: ".aif", ".aiff"
// and ".aifc" are AIFF, ".au" and ".snd" AU, and any other (or none) WAV.
// p_name is UTF-8 or native; only its last few ASCII characters matter.
MCAudioFileContainer MCAudioFileContainerForName(const char *p_name);

// Writes the sound file of p_size bytes of samples into r_file (allocated
// with malloc, freed by the caller), r_file_size bytes long. A trailing
// part frame is left out. Mu-law samples stay mu-law in an AU file and
// become 16-bit linear in WAV and AIFF, which have no mu-law that every
// player reads. False, with nothing allocated, for a clip that cannot be
// written: no channels, a sample width other than 1, 2 or 3 bytes, a
// rate of 0, or no memory.
bool MCAudioEncodeFile(MCAudioFileContainer p_container,
                       const uint8_t *p_samples, uint32_t p_size,
                       int p_format, uint32_t p_channels, uint32_t p_width,
                       uint32_t p_rate,
                       uint8_t *&r_file, size_t &r_file_size);

// One mu-law byte as a 16-bit linear sample (G.711, as the engine's table)
int16_t MCAudioMulawToLinear(uint8_t p_byte);

#endif
